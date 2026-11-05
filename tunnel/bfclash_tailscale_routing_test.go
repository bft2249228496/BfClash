package tunnel

import (
	"net/netip"
	"testing"

	C "github.com/metacubex/mihomo/constant"
)

type bfclashTestAdapter struct {
	C.ProxyAdapter
	enabled bool
}

func (a *bfclashTestAdapter) BfClashAutoRoute() bool { return a.enabled }

type bfclashTestProxy struct {
	C.Proxy
	adapter C.ProxyAdapter
}

func (p *bfclashTestProxy) Adapter() C.ProxyAdapter { return p.adapter }

func TestBfClashTailnetRoutingRespectsOptInAndSpecialProxy(t *testing.T) {
	direct := &bfclashTestProxy{}
	global := &bfclashTestProxy{}
	tailnet := &bfclashTestProxy{adapter: &bfclashTestAdapter{enabled: true}}
	previousProxies, previousProviders, previousMode := proxies, providers, mode
	t.Cleanup(func() {
		UpdateProxies(previousProxies, previousProviders)
		SetMode(previousMode)
	})
	UpdateProxies(map[string]C.Proxy{
		"DIRECT": direct, "GLOBAL": global, "BfClash-Tailscale": tailnet,
	}, nil)
	for _, tc := range []struct {
		mode     TunnelMode
		metadata *C.Metadata
		want     C.Proxy
	}{
		{Direct, &C.Metadata{Type: C.HTTP, DstIP: netip.MustParseAddr("100.64.0.2")}, tailnet},
		{Global, &C.Metadata{Type: C.HTTP, Host: "nas.example.ts.net"}, tailnet},
		{Rule, &C.Metadata{Type: C.HTTP, DstIP: netip.MustParseAddr("fd7a:115c:a1e0::1")}, tailnet},
		{Global, &C.Metadata{Type: C.HTTP, DstIP: netip.MustParseAddr("8.8.8.8")}, global},
		{Direct, &C.Metadata{Type: C.INNER, DstIP: netip.MustParseAddr("100.64.0.2")}, direct},
		{Global, &C.Metadata{Type: C.HTTP, DstIP: netip.MustParseAddr("100.64.0.2"), SpecialProxy: "DIRECT"}, direct},
	} {
		SetMode(tc.mode)
		got, _, err := resolveMetadata(tc.metadata)
		if err != nil || got != tc.want {
			t.Fatalf("mode %v metadata %+v: proxy=%v error=%v", tc.mode, tc.metadata, got, err)
		}
	}
	tailnet.adapter = &bfclashTestAdapter{enabled: false}
	SetMode(Direct)
	got, _, err := resolveMetadata(&C.Metadata{Type: C.HTTP, DstIP: netip.MustParseAddr("100.64.0.2")})
	if err != nil || got != direct {
		t.Fatalf("without opt-in got proxy=%v error=%v", got, err)
	}
}
