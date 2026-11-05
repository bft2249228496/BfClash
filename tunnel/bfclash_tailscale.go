package tunnel

import (
	"net/netip"
	"strings"

	C "github.com/metacubex/mihomo/constant"
)

var (
	bfclashTailnetIPv4 = netip.MustParsePrefix("100.64.0.0/10")
	bfclashTailnetIPv6 = netip.MustParsePrefix("fd7a:115c:a1e0::/48")
)

func bfclashTailnetDestination(metadata *C.Metadata) bool {
	if metadata == nil {
		return false
	}
	if metadata.DstIP.IsValid() && (bfclashTailnetIPv4.Contains(metadata.DstIP.Unmap()) || bfclashTailnetIPv6.Contains(metadata.DstIP)) {
		return true
	}
	host := strings.TrimSuffix(strings.ToLower(metadata.Host), ".")
	return host == "ts.net" || strings.HasSuffix(host, ".ts.net")
}
