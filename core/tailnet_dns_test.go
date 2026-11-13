package main

import (
	"context"
	"errors"
	"testing"

	"github.com/metacubex/mihomo/dns"
	"github.com/metacubex/tailscale/client/local"
	D "github.com/miekg/dns"
)

func TestAppTailnetDNSRegistryReplacement(t *testing.T) {
	const name = "app-tailnet-dns-test"
	oldCalls, newCalls := 0, 0
	unavailable := errors.New("no test backend")
	unregisterOld := registerAppTailnetDNS(name, func(context.Context) (*local.Client, error) {
		oldCalls++
		return nil, unavailable
	})
	defer unregisterOld()
	unregisterNew := registerAppTailnetDNS(name, func(context.Context) (*local.Client, error) {
		newCalls++
		return nil, unavailable
	})
	defer unregisterNew()
	unregisterOld()

	servers := dns.NewResolver(dns.Config{Main: []dns.NameServer{{Net: "tailscale", Addr: name}}})
	query := new(D.Msg).SetQuestion("test.example.ts.net.", D.TypeA)
	if _, err := servers.Resolver.ExchangeContext(context.Background(), query); err == nil {
		t.Fatal("expected backend error")
	}
	if oldCalls != 0 || newCalls == 0 {
		t.Fatalf("old handler called %d times, replacement called %d times", oldCalls, newCalls)
	}
}
