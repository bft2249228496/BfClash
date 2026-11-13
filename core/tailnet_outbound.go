//go:build with_gvisor && !no_tailscale

package main

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/netip"
	"sync"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/dns"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/rules/common"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/tailscale/client/local"
	"github.com/metacubex/tailscale/tsnet"
)

type appTailnetOutbound struct {
	adbForwards map[uint16]adbForwardState
	*outbound.Base
	server          *tsnet.Server
	resolver        *dns.Resolver
	mu              sync.Mutex
	started, closed bool
	unregister      func()
}

func newAppTailnetOutbound(name string, server *tsnet.Server) *appTailnetOutbound {
	t := &appTailnetOutbound{
		Base:   outbound.NewBase(outbound.BaseOption{Name: name, Type: C.Tailscale, UDP: true}),
		server: server,
	}
	transport := appTailnetDNS{name: name, client: t.LocalClient}
	t.resolver = dns.NewResolverFromClient(transport)
	return t
}

func (t *appTailnetOutbound) start(ctx context.Context) error {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.closed {
		return net.ErrClosed
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	if !t.started {
		if err := t.server.Start(); err != nil {
			return err
		}
		t.started = true
	}
	return nil
}

func (t *appTailnetOutbound) LocalClient(ctx context.Context) (*local.Client, error) {
	if err := t.start(ctx); err != nil {
		return nil, err
	}
	return t.server.LocalClient()
}

func (t *appTailnetOutbound) ResolveUDP(ctx context.Context, m *C.Metadata) error {
	if m.Host == "" || m.DstIP.IsValid() {
		return nil
	}
	ips, err := t.resolver.LookupIP(ctx, m.Host)
	if err != nil {
		return err
	}
	if len(ips) == 0 {
		return errors.New("Tailscale DNS returned no addresses")
	}
	m.DstIP = ips[0]
	return nil
}

func (t *appTailnetOutbound) DialContext(ctx context.Context, m *C.Metadata) (C.Conn, error) {
	if err := t.start(ctx); err != nil {
		return nil, t.transferError("TCP", "startup", err)
	}
	destination := *m
	if err := t.ResolveUDP(ctx, &destination); err != nil {
		return nil, t.transferError("TCP", "DNS", err)
	}
	conn, err := t.server.Dial(ctx, "tcp", netip.AddrPortFrom(destination.DstIP, destination.DstPort).String())
	if err != nil {
		return nil, t.transferError("TCP", "dial", err)
	}
	return outbound.NewConn(conn, t), nil
}

func (t *appTailnetOutbound) ListenPacketContext(ctx context.Context, m *C.Metadata) (C.PacketConn, error) {
	if err := t.start(ctx); err != nil {
		return nil, t.transferError("UDP", "startup", err)
	}
	if err := t.ResolveUDP(ctx, m); err != nil {
		return nil, t.transferError("UDP", "DNS", err)
	}
	v4, v6 := t.server.TailscaleIPs()
	source := v4
	if m.DstIP.Is6() {
		source = v6
	}
	if !source.IsValid() {
		return nil, errors.New("Tailscale has no address for this address family")
	}
	conn, err := t.server.ListenPacket("udp", netip.AddrPortFrom(source, 0).String())
	if err != nil {
		return nil, t.transferError("UDP", "bind", err)
	}
	return outbound.NewPacketConn(conn, t), nil
}

func (t *appTailnetOutbound) transferError(protocol, stage string, err error) error {
	log.Warnln("[Tailscale] %s %s failed (%T, timeout=%t, canceled=%t)", protocol, stage, err,
		errors.Is(err, context.DeadlineExceeded), errors.Is(err, context.Canceled))
	return fmt.Errorf("Tailscale %s %s: %w", protocol, stage, err)
}

func (t *appTailnetOutbound) Close() error {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.closed {
		return nil
	}
	t.closed = true
	t.stopADBForwardsLocked()
	if t.unregister != nil {
		t.unregister()
	}
	if t.started {
		return t.server.Close()
	}
	return nil
}

var _ C.ProxyAdapter = (*appTailnetOutbound)(nil)

func (t *appTailnetOutbound) BfClashAutoRoute() bool { return true }

func installAppTailnet(cfg *config.Config) func() {
	previous := installedAppTailnet
	const name = "BfClash-Tailscale"
	if candidate := cfg.Proxies[name]; candidate != nil && candidate.Type() == C.Tailscale {
		if previous == nil {
			transport := dialer.NewDialer()
			previous = newAppTailnetOutbound(name, &tsnet.Server{
				Dir:          C.Path.Resolve("bfclash-tailscale"),
				SystemDialer: transport.DialContext,
				SystemPacketListener: func(ctx context.Context, network, address string) (net.PacketConn, error) {
					return transport.ListenPacket(ctx, network, address, netip.AddrPort{})
				},
				Logf:     func(string, ...any) {},
				UserLogf: func(string, ...any) {},
			})
		}
		_ = candidate.Close()
		if previous.unregister != nil {
			previous.unregister()
		}
		previous.unregister = registerAppTailnetDNS(name, previous.LocalClient)
		cfg.Proxies[name] = adapter.NewProxy(previous)

		log.Infoln("[Tailscale] outbound installed for TCP, UDP and DNS")
		installedAppTailnet = previous
		return func() {}
	}
	installedAppTailnet = nil
	return func() {
		if previous != nil {
			_ = previous.Close()
		}
	}
}

var installedAppTailnet *appTailnetOutbound

func appTailnetRules(name string) []C.Rule {
	ipv4, _ := common.NewIPCIDR("100.64.0.0/10", name, common.WithIPCIDRNoResolve(true))
	ipv6, _ := common.NewIPCIDR("fd7a:115c:a1e0::/48", name, common.WithIPCIDRNoResolve(true))
	return []C.Rule{common.NewDomainSuffix("ts.net", name), ipv4, ipv6}
}

func appTailnetRouting(cfg *config.Config) (tunnel.TunnelMode, []C.Rule) {
	mode := cfg.General.Mode
	if installedAppTailnet == nil {
		return mode, cfg.Rules
	}
	rules := appTailnetRules(installedAppTailnet.Name())
	switch mode {
	case tunnel.Direct:
		return tunnel.Rule, append(rules, common.NewMatch("DIRECT"))
	case tunnel.Global:
		return tunnel.Rule, append(rules, common.NewMatch("GLOBAL"))
	default:
		return mode, append(rules, cfg.Rules...)
	}
}

func applyAppTailnetMode(cfg *config.Config) {
	mode, rules := appTailnetRouting(cfg)
	tunnel.UpdateRules(rules, cfg.SubRules, cfg.RuleProviders)
	tunnel.SetMode(mode)
}
