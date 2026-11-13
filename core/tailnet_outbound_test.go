//go:build with_gvisor && !no_tailscale

package main

import (
	"context"
	"errors"
	"net"
	"testing"

	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/tunnel"
)

func TestAppTailnetConfigurationLifecycle(t *testing.T) {
	const name = "BfClash-Tailscale"
	t.Cleanup(func() {
		if installedAppTailnet != nil {
			_ = installedAppTailnet.Close()
			installedAppTailnet = nil
		}
	})
	var first *appTailnetOutbound
	for i := 0; i < 2; i++ {
		cfg, err := executor.ParseWithBytes([]byte("proxies: [{name: BfClash-Tailscale, type: tailscale, state-dir: bfclash-tailscale, udp: true}]"))
		if err != nil {
			t.Fatal(err)
		}
		retire := installAppTailnet(cfg)
		executor.ApplyConfig(cfg, false)
		retire()
		got, err := tailscaleUnderlying(name)
		if err != nil {
			t.Fatal(err)
		}
		app, ok := got.(*appTailnetOutbound)
		if !ok {
			t.Fatalf("unexpected outbound %T", got)
		}
		if i == 0 {
			first = app
		} else if app != first {
			t.Fatal("configuration reload replaced the Tailscale instance")
		}
	}
	cfg, err := executor.ParseWithBytes(nil)
	if err != nil {
		t.Fatal(err)
	}
	retire := installAppTailnet(cfg)
	executor.ApplyConfig(cfg, false)
	retire()
	if tunnel.Proxies()[name] != nil || installedAppTailnet != nil {
		t.Fatal("disabled outbound remains registered")
	}
	if _, err := first.LocalClient(context.Background()); !errors.Is(err, net.ErrClosed) {
		t.Fatalf("retired instance returned %v", err)
	}
}

func TestAppTailnetModeFallback(t *testing.T) {
	cfg, err := executor.ParseWithBytes([]byte("proxies: [{name: BfClash-Tailscale, type: tailscale}]\nrules: ['MATCH,REJECT']"))
	if err != nil {
		t.Fatal(err)
	}
	installAppTailnet(cfg)
	t.Cleanup(func() { _ = installedAppTailnet.Close(); installedAppTailnet = nil })
	for _, tc := range []struct {
		mode     tunnel.TunnelMode
		fallback string
	}{
		{tunnel.Rule, "REJECT"}, {tunnel.Global, "GLOBAL"}, {tunnel.Direct, "DIRECT"},
	} {
		cfg.General.Mode = tc.mode
		mode, rules := appTailnetRouting(cfg)
		if mode != tunnel.Rule || len(rules) != 4 || rules[3].Adapter() != tc.fallback {
			t.Fatalf("unexpected routing for %v: effective mode %v, rules %v", tc.mode, mode, rules)
		}
	}
}
