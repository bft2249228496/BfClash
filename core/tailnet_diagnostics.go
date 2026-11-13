//go:build with_gvisor && !no_tailscale

package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

type TailnetProbeResult struct {
	Path       string `json:"path"`   // "direct_tailscale" (对照A) 或 "vpn_route" (对照B)
	Type       string `json:"type"`   // "tcp", "dns", "udp"
	Target     string `json:"target"` // 探测目标
	Success    bool   `json:"success"`
	DurationMs int64  `json:"durationMs"`
	HTTPCode   int    `json:"httpCode,omitempty"`
	Detail     string `json:"detail,omitempty"`
	Error      string `json:"error,omitempty"`
}

type TailnetDiagnostics struct {
	Timestamp    string               `json:"timestamp"`
	Trigger      string               `json:"trigger"` // "vpn_start", "config_reload", "manual"
	TunReady     bool                 `json:"tunReady"`
	HookActive   bool                 `json:"hookActive"`
	ProtectOK    bool                 `json:"protectOk"`
	OutboundOK   bool                 `json:"outboundOk"`
	RulesOK      bool                 `json:"rulesOk"`
	RuleMatches  string               `json:"ruleMatches,omitempty"`
	BackendState string               `json:"backendState"`
	AssignedIPs  []string             `json:"assignedIps"`
	PeerCount    int                  `json:"peerCount"`
	Probes       []TailnetProbeResult `json:"probes"`
	Summary      string               `json:"summary"`
}

var (
	latestDiagnostics atomic.Pointer[TailnetDiagnostics]
	diagTimerMu       sync.Mutex
	diagTimer         *time.Timer
	diagRunning       atomic.Bool
)

// triggerTailnetDiagnostics 安排在触发后异步执行自动诊断（带防抖）。
func triggerTailnetDiagnostics(trigger string) {
	diagTimerMu.Lock()
	defer diagTimerMu.Unlock()
	if diagTimer != nil {
		diagTimer.Stop()
	}
	diagTimer = time.AfterFunc(1500*time.Millisecond, func() {
		safeGoDetached("tailnet_diagnostics", func() {
			runTailnetDiagnostics(trigger)
		})
	})
}

// runTailnetDiagnostics 执行完整的两组对照探测与状态检查。
func runTailnetDiagnostics(trigger string) *TailnetDiagnostics {
	if !diagRunning.CompareAndSwap(false, true) {
		log.Debugln("[Tailscale-Diag] previous diagnostics still running, skipping trigger: %s", trigger)
		return latestDiagnostics.Load()
	}
	defer diagRunning.Store(false)

	outbound := installedAppTailnet.Load()
	tunReady, hookActive, protectOk := getTunDiagnosticState()
	diag := &TailnetDiagnostics{
		Timestamp:   time.Now().UTC().Format(time.RFC3339),
		Trigger:     trigger,
		TunReady:    tunReady,
		HookActive:  hookActive,
		ProtectOK:   protectOk,
		OutboundOK:  outbound != nil,
		AssignedIPs: []string{},
		Probes:      []TailnetProbeResult{},
	}

	// 1. 检查规则挂载
	rules := tunnel.Rules()
	hasTailnetRule := false
	for _, r := range rules {
		if r != nil && r.Adapter() == "BfClash-Tailscale" {
			hasTailnetRule = true
			break
		}
	}
	diag.RulesOK = hasTailnetRule

	// 2. 检查 Tailscale 后端状态
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var magicDNSTarget string
	if outbound != nil {
		client, err := outbound.LocalClient(ctx)
		if err == nil && client != nil {
			status, err := client.Status(ctx)
			if err == nil && status != nil {
				diag.BackendState = status.BackendState
				for _, ip := range status.TailscaleIPs {
					diag.AssignedIPs = append(diag.AssignedIPs, ip.String())
				}
				diag.PeerCount = len(status.Peer)
				for _, peer := range status.Peer {
					if peer != nil && peer.DNSName != "" {
						magicDNSTarget = strings.TrimSuffix(peer.DNSName, ".")
						break
					}
				}
			} else if err != nil {
				diag.BackendState = "status_error"
			} else {
				diag.BackendState = "status_missing"
			}
		} else if err != nil {
			diag.BackendState = "client_error"
		}
	} else {
		diag.BackendState = "outbound_not_installed"
	}

	if diag.BackendState != "Running" {
		diag.Summary = fmt.Sprintf("Tailscale probes deferred: backend=%q, assigned addresses=%d", diag.BackendState, len(diag.AssignedIPs))
		return saveTailnetDiagnostics(diag)
	}

	// 3. 确定探测测试地址
	// Only probe an explicitly configured test endpoint.
	probeTarget := os.Getenv("BFCLASH_TAILNET_PROBE_TARGET")
	if probeTarget == "" {
		diag.Summary = "Tailscale backend is running. No traffic probe target configured."
		return saveTailnetDiagnostics(diag)
	}

	host, portStr, splitErr := net.SplitHostPort(probeTarget)
	var port uint16 = 80
	if splitErr == nil {
		if p, err := strconv.ParseUint(portStr, 10, 16); err == nil {
			port = uint16(p)
		}
	} else {
		host = probeTarget
	}
	var targetIP netip.Addr
	if addr, err := netip.ParseAddr(host); err == nil {
		targetIP = addr
	}

	// 4. 对照组 A：直接走应用内 Tailscale 出站
	var directTCPCode int
	var directTCPOK bool
	if outbound != nil {
		// A.1 TCP 探测
		tcpStart := time.Now()
		probeA := TailnetProbeResult{
			Path:   "direct_tailscale",
			Type:   "tcp",
			Target: probeTarget,
		}
		tcpCtx, tcpCancel := context.WithTimeout(context.Background(), 6*time.Second)
		metadata := &C.Metadata{
			Host:    host,
			DstIP:   targetIP,
			DstPort: port,
		}
		conn, err := outbound.DialContext(tcpCtx, metadata)
		probeA.DurationMs = time.Since(tcpStart).Milliseconds()
		if err != nil {
			probeA.Success = false
			probeA.Error = err.Error()
		} else {
			probeA.Success = true
			directTCPOK = true
			_ = conn.SetDeadline(time.Now().Add(4 * time.Second))
			req := fmt.Sprintf("GET /bfclash-check HTTP/1.1\r\nHost: %s\r\nConnection: close\r\nUser-Agent: BfClash-Diag\r\n\r\n", host)
			_, _ = conn.Write([]byte(req))
			reader := bufio.NewReader(conn)
			statusLine, readErr := reader.ReadString('\n')
			_ = conn.Close()
			if readErr == nil && strings.HasPrefix(statusLine, "HTTP/") {
				parts := strings.Fields(statusLine)
				if len(parts) >= 2 {
					if code, parseErr := strconv.Atoi(parts[1]); parseErr == nil {
						probeA.HTTPCode = code
						directTCPCode = code
					}
				}
				probeA.Detail = strings.TrimSpace(statusLine)
			}
		}
		tcpCancel()
		diag.Probes = append(diag.Probes, probeA)

		// A.2 DNS 探测
		dnsTarget := magicDNSTarget
		if dnsTarget == "" {
			dnsTarget = "test.ts.net"
		}
		dnsStart := time.Now()
		probeADNS := TailnetProbeResult{
			Path:   "direct_tailscale",
			Type:   "dns",
			Target: dnsTarget,
		}
		dnsCtx, dnsCancel := context.WithTimeout(context.Background(), 4*time.Second)
		dnsIPs, dnsErr := outbound.resolver.LookupIP(dnsCtx, dnsTarget)
		dnsCancel()
		probeADNS.DurationMs = time.Since(dnsStart).Milliseconds()
		if dnsErr != nil {
			probeADNS.Success = false
			probeADNS.Error = dnsErr.Error()
		} else {
			probeADNS.Success = true
			probeADNS.Detail = fmt.Sprintf("resolved %d addresses", len(dnsIPs))
		}
		diag.Probes = append(diag.Probes, probeADNS)

		// A.3 UDP 探测
		udpStart := time.Now()
		probeAUDP := TailnetProbeResult{
			Path:   "direct_tailscale",
			Type:   "udp",
			Target: probeTarget,
		}
		udpCtx, udpCancel := context.WithTimeout(context.Background(), 4*time.Second)
		pconn, udpErr := outbound.ListenPacketContext(udpCtx, metadata)
		udpCancel()
		probeAUDP.DurationMs = time.Since(udpStart).Milliseconds()
		if udpErr != nil {
			probeAUDP.Success = false
			probeAUDP.Error = udpErr.Error()
		} else {
			probeAUDP.Success = true
			probeAUDP.Detail = "bound local packet listener"
			_ = pconn.Close()
		}
		diag.Probes = append(diag.Probes, probeAUDP)
	}

	// 5. 对照组 B：走 Android VPN / Clash 核心的规则路由与代理转发
	probeBMatch := TailnetProbeResult{
		Path:   "vpn_route",
		Type:   "rule_match",
		Target: probeTarget,
	}
	routeMeta := &C.Metadata{
		NetWork: C.TCP,
		Host:    host,
		DstIP:   targetIP,
		DstPort: port,
	}
	matchedProxy, matchErr := tunnel.ResolveRoute(routeMeta)
	if matchErr != nil {
		probeBMatch.Success = false
		probeBMatch.Error = matchErr.Error()
	} else if matchedProxy != nil {
		probeBMatch.Detail = fmt.Sprintf("matched outbound: %s", matchedProxy.Name())
		diag.RuleMatches = matchedProxy.Name()
		probeBMatch.Success = (matchedProxy.Name() == "BfClash-Tailscale")
		if !probeBMatch.Success {
			probeBMatch.Error = fmt.Sprintf("route deviated: expected BfClash-Tailscale, got %s", matchedProxy.Name())
		}
	}
	diag.Probes = append(diag.Probes, probeBMatch)

	// B.2 经由本地代理端口 (mixed-port) 实际拨测 HTTP 请求
	var vpnTCPCode int
	var vpnTCPOK bool
	var mixedPort int
	if currentConfig != nil {
		mixedPort = currentConfig.General.MixedPort
		if mixedPort == 0 {
			mixedPort = currentConfig.General.Port
		}
	}
	if mixedPort > 0 {
		probeBProxy := TailnetProbeResult{
			Path:   "vpn_route",
			Type:   "proxy_http",
			Target: fmt.Sprintf("http://%s/bfclash-check via 127.0.0.1:%d", probeTarget, mixedPort),
		}
		proxyStart := time.Now()
		proxyURL, _ := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", mixedPort))
		client := &http.Client{
			Transport: &http.Transport{
				Proxy: http.ProxyURL(proxyURL),
			},
			Timeout: 5 * time.Second,
		}
		resp, httpErr := client.Get(fmt.Sprintf("http://%s/bfclash-check", probeTarget))
		probeBProxy.DurationMs = time.Since(proxyStart).Milliseconds()
		if httpErr != nil {
			probeBProxy.Success = false
			probeBProxy.Error = httpErr.Error()
		} else {
			probeBProxy.HTTPCode = resp.StatusCode
			vpnTCPCode = resp.StatusCode
			_ = resp.Body.Close()
			probeBProxy.Success = (resp.StatusCode == http.StatusOK)
			vpnTCPOK = probeBProxy.Success
			probeBProxy.Detail = fmt.Sprintf("HTTP %d", resp.StatusCode)
			if resp.StatusCode == http.StatusBadGateway {
				probeBProxy.Error = "received HTTP 502 Bad Gateway"
			}
		}
		diag.Probes = append(diag.Probes, probeBProxy)
	}

	// 6. 综合对照分析结论
	if directTCPOK && (directTCPCode == 200 || directTCPCode > 0) {
		if vpnTCPOK {
			diag.Summary = fmt.Sprintf("VERIFIED: Tailnet dual-path OK. Direct HTTP %d, VPN route HTTP %d.", directTCPCode, vpnTCPCode)
		} else if vpnTCPCode == 502 {
			diag.Summary = "ROOT-CAUSE-ISOLATED: Direct Tailscale outbound succeeded, but VPN route returned HTTP 502 Bad Gateway! Issue is in Clash rule matching or mixed-port proxy forwarder."
		} else {
			diag.Summary = fmt.Sprintf("ISOLATED: Direct Tailscale outbound succeeded (HTTP %d), but VPN route failed (code=%d, rule=%s). Inspect VPN routing and rule hits.", directTCPCode, vpnTCPCode, diag.RuleMatches)
		}
	} else if !directTCPOK {
		if !diag.ProtectOK {
			diag.Summary = "FAILED: Android VpnService.protect is failing sockets. Deadlock loop detected in VPN."
		} else if diag.BackendState != "Running" {
			diag.Summary = fmt.Sprintf("FAILED: Tailscale backend is not running (state=%s, assigned IPs=%d).", diag.BackendState, len(diag.AssignedIPs))
		} else {
			diag.Summary = "FAILED: Both direct outbound and VPN route failed. Inspect peer reachability, DERP connection, or target service."
		}
	}

	return saveTailnetDiagnostics(diag)
}

func saveTailnetDiagnostics(diag *TailnetDiagnostics) *TailnetDiagnostics {
	latestDiagnostics.Store(diag)

	log.Infoln("[Tailscale-Diag] Summary: %s", diag.Summary)
	if data, err := json.MarshalIndent(diag, "", "  "); err == nil {
		logPath := C.Path.Resolve("tailnet-diagnostics.log")
		_ = os.WriteFile(logPath, data, 0o600)
	}

	return diag
}

func getTailscaleDiagnosticsResult() any {
	diag := latestDiagnostics.Load()
	if diag == nil {
		return runTailnetDiagnostics("manual")
	}
	return diag
}
