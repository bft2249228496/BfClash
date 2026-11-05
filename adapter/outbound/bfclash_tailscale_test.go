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
	original := &Tailscale{cancel: func() {}, option: TailscaleOption{BfClashAutoRoute: true}}
	wrapped := NewAutoCloseProxyAdapter(original)
	accessor, ok := wrapped.(interface{ Underlying() ProxyAdapter })
	if !ok || accessor.Underlying() != original {
		t.Fatal("wrapped Tailscale instance is not accessible")
	}
	router, ok := wrapped.(interface{ BfClashAutoRoute() bool })
	if !ok || !router.BfClashAutoRoute() {
		t.Fatal("wrapped Tailscale lost the auto-route opt-in")
	}
}
