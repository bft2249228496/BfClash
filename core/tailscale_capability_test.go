//go:build with_gvisor && !no_tailscale

package main

import (
	"testing"

	"github.com/metacubex/mihomo/adapter"
	C "github.com/metacubex/mihomo/constant"
)

func TestTailscaleOutboundAvailableWithoutStartingNode(t *testing.T) {
	proxy, err := adapter.ParseProxy(map[string]any{
		"name":      "bfclash-tailscale-test",
		"type":      "tailscale",
		"state-dir": "tailscale-test",
		"udp":       true,
	})
	if err != nil {
		t.Fatalf("parse Tailscale outbound: %v", err)
	}
	t.Cleanup(func() {
		if err := proxy.Close(); err != nil {
			t.Errorf("close Tailscale outbound: %v", err)
		}
	})
	if proxy.Type() != C.Tailscale || !proxy.SupportUDP() {
		t.Fatalf("unexpected outbound: type=%s UDP=%v", proxy.Type(), proxy.SupportUDP())
	}
	got := tailscaleOutboundNames(map[string]C.Proxy{"tailnet": proxy, "missing": nil})
	if len(got) != 1 || got[0] != "tailnet" {
		t.Fatalf("Tailscale outbound names = %v, want [tailnet]", got)
	}
}

func TestTailscaleOutboundRejectsUnsafeStateDirectory(t *testing.T) {
	_, err := adapter.ParseProxy(map[string]any{
		"name":      "bfclash-tailscale-invalid-test",
		"type":      "tailscale",
		"state-dir": "../bfclash-tailscale-outside",
	})
	if err == nil {
		t.Fatal("accepted a Tailscale state directory outside the core home")
	}
}
