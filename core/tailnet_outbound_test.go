//go:build with_gvisor && !no_tailscale

package main

import (
	"context"
	"errors"
	"net"
	"testing"

	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/tunnel"
)

func TestAppTailnetConfigurationLifecycle(t *testing.T) {
	const name = "BfClash-Tailscale"
	t.Cleanup(func() {
		if installedAppTailnet.Load() != nil {
			_ = installedAppTailnet.Load().Close()
			installedAppTailnet.Store(nil)
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
			if app.server.LookupHook == nil {
				t.Fatal("Tailscale control traffic must resolve through the system resolver")
			}
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
	if tunnel.Proxies()[name] != nil || installedAppTailnet.Load() != nil {
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
	t.Cleanup(func() { _ = installedAppTailnet.Load().Close(); installedAppTailnet.Store(nil) })
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

func TestAppTailnetResolveUDPLiteralIP(t *testing.T) {
	app := &appTailnetOutbound{}
	meta := &C.Metadata{Host: "100.69.122.72"}
	if err := app.ResolveUDP(context.Background(), meta); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if meta.DstIP.String() != "100.69.122.72" {
		t.Fatalf("expected 100.69.122.72, got %s", meta.DstIP)
	}
}
