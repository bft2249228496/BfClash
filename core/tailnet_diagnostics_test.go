//go:build with_gvisor && !no_tailscale

package main

import (
	"os"
	"strings"
	"testing"

	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
)

func TestTailnetDiagnosticsBasic(t *testing.T) {
	// 1. 无 Tailscale 安装时的诊断
	diag := runTailnetDiagnostics("test_initial")
	if diag == nil {
		t.Fatal("expected non-nil diagnostics")
	}
	if diag.Trigger != "test_initial" {
		t.Fatalf("expected trigger test_initial, got %s", diag.Trigger)
	}
	if diag.OutboundOK {
		t.Fatal("expected OutboundOK to be false when not installed")
	}

	// 2. 安装 Tailscale 后的诊断
	cfg, err := executor.ParseWithBytes([]byte("proxies: [{name: BfClash-Tailscale, type: tailscale, state-dir: bfclash-tailscale, udp: true}]\nrules: ['MATCH,BfClash-Tailscale']"))
	if err != nil {
		t.Fatal(err)
	}
	retire := installAppTailnet(cfg)
	executor.ApplyConfig(cfg, false)
	applyAppTailnetMode(cfg)
	defer func() {
		retire()
		if installedAppTailnet.Load() != nil {
			_ = installedAppTailnet.Load().Close()
			installedAppTailnet.Store(nil)
		}
	}()

	diagWithTailscale := runTailnetDiagnostics("test_installed")
	if !diagWithTailscale.OutboundOK {
		t.Fatal("expected OutboundOK to be true after install")
	}
	if !diagWithTailscale.RulesOK {
		t.Fatal("expected RulesOK to be true when rules contain BfClash-Tailscale")
	}

	// 3. 验证本地诊断日志文件已写入，且不泄露敏感密钥
	logPath := C.Path.Resolve("tailnet-diagnostics.log")
	data, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatalf("failed to read diagnostic log: %v", err)
	}
	content := string(data)
	if !strings.Contains(content, "test_installed") {
		t.Fatalf("log does not contain expected trigger: %s", content)
	}
	if strings.Contains(content, "authKey") || strings.Contains(content, "tskey-") {
		t.Fatal("log contains sensitive auth tokens")
	}
}
