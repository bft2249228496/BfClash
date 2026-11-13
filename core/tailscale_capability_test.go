//go:build with_gvisor && !no_tailscale

package main

import (
	"testing"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/config"
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

func TestTailscaleGeneratedProfileParses(t *testing.T) {
	cfg, err := config.Parse([]byte(`
dns:
  enable: true
  nameserver: [1.1.1.1]
  nameserver-policy:
    '+.ts.net': ['ts://BfClash-Tailscale']
proxies:
  - name: BfClash-Tailscale
    type: tailscale
    state-dir: bfclash-tailscale-test
    udp: true
    bfclash-auto-route: true
rules: ['MATCH,DIRECT']
`))
	if err != nil {
		t.Fatalf("parse generated profile: %v", err)
	}
	proxy := cfg.Proxies["BfClash-Tailscale"]
	if proxy == nil {
		t.Fatal("Tailscale outbound missing")
	}
	t.Cleanup(func() { _ = proxy.Close() })
	installAppTailnet(cfg)
	t.Cleanup(func() {
		_ = installedAppTailnet.Close()
		installedAppTailnet = nil
	})
	_, rules := appTailnetRouting(cfg)
	if len(rules) < 4 || rules[0].Adapter() != "BfClash-Tailscale" {
		t.Fatal("application did not install Tailscale routing rules")
	}
	if len(cfg.DNS.NameServerPolicy) != 1 || len(cfg.DNS.NameServerPolicy[0].NameServers) != 1 {
		t.Fatalf("unexpected DNS policy: %+v", cfg.DNS.NameServerPolicy)
	}
	ns := cfg.DNS.NameServerPolicy[0].NameServers[0]
	if ns.Net != "tailscale" || ns.Addr != "BfClash-Tailscale" {
		t.Fatalf("unexpected Tailscale DNS server: %+v", ns)
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
