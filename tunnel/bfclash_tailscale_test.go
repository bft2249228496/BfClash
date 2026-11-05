package tunnel

import (
	"net/netip"
	"testing"

	C "github.com/metacubex/mihomo/constant"
)

func TestBfClashTailnetDestination(t *testing.T) {
	cases := []struct {
		name     string
		metadata *C.Metadata
		want     bool
	}{
		{"nil", nil, false},
		{"tailnet-v4", &C.Metadata{DstIP: netip.MustParseAddr("100.64.1.2")}, true},
		{"tailnet-v6", &C.Metadata{DstIP: netip.MustParseAddr("fd7a:115c:a1e0::123")}, true},
		{"magic-dns", &C.Metadata{Host: "NAS.Example.TS.NET."}, true},
		{"similar-domain", &C.Metadata{Host: "evilts.net"}, false},
		{"normal-v4", &C.Metadata{DstIP: netip.MustParseAddr("192.168.1.1")}, false},
		{"normal-v6", &C.Metadata{DstIP: netip.MustParseAddr("2001:db8::1")}, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := bfclashTailnetDestination(tc.metadata); got != tc.want {
				t.Fatalf("got %v, want %v", got, tc.want)
			}
		})
	}
}
