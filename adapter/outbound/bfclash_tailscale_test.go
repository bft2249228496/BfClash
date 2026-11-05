//go:build with_gvisor && !no_tailscale

package outbound

import (
	"context"
	"errors"
	"testing"
)

func TestTailscaleLocalClientHonorsCanceledContext(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	client, err := (&Tailscale{}).LocalClient(ctx)
	if client != nil || !errors.Is(err, context.Canceled) {
		t.Fatalf("client = %v, error = %v; want cancellation", client, err)
	}
}

func TestAutoCloseAdapterExposesSameUnderlyingInstance(t *testing.T) {
	original := &Tailscale{cancel: func() {}}
	wrapped := NewAutoCloseProxyAdapter(original)
	accessor, ok := wrapped.(interface{ Underlying() ProxyAdapter })
	if !ok || accessor.Underlying() != original {
		t.Fatal("wrapped Tailscale instance is not accessible")
	}
}
