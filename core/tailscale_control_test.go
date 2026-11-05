package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/netip"
	"strings"
	"testing"

	"github.com/metacubex/tailscale/ipn/ipnstate"
	"github.com/metacubex/tailscale/types/key"
)

func TestTailscaleClientRejectsMissingOutbound(t *testing.T) {
	client, err := tailscaleClient(context.Background(), "bfclash-missing-tailnet")
	if client != nil || !errors.Is(err, errTailscaleOutboundUnavailable) {
		t.Fatalf("client = %v, error = %v; want unavailable", client, err)
	}
}

func TestTailscaleStatusViewSelectsAndSortsPeerFields(t *testing.T) {
	status := &ipnstate.Status{
		BackendState: "Running",
		TailscaleIPs: []netip.Addr{netip.MustParseAddr("100.64.0.1")},
		Peer: map[key.NodePublic]*ipnstate.PeerStatus{
			key.NewNode().Public(): {HostName: "z-server", Online: true, Addrs: []string{"private-endpoint"}},
			key.NewNode().Public(): {HostName: "a-server", ExitNodeOption: true},
		},
	}
	got := tailscaleStatusView(status)
	if got.State != "Running" || len(got.IPs) != 1 || len(got.Peers) != 2 || got.Peers[0].Hostname != "a-server" || !got.Peers[0].CanExit || !got.Peers[1].Online {
		t.Fatalf("unexpected status projection: %+v", got)
	}
	encoded, err := json.Marshal(got)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(encoded), "private-endpoint") {
		t.Fatal("peer transport endpoints must not be exposed to the UI")
	}
}

func TestTailscaleStatusViewHandlesEmptyStatus(t *testing.T) {
	got := tailscaleStatusView(nil)
	if got.State != "" || got.IPs == nil || got.Peers == nil {
		t.Fatalf("unexpected empty status: %+v", got)
	}
}
