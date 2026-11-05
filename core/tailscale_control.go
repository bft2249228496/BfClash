package main

import (
	"context"
	"errors"
	"sort"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/tailscale/client/local"
	"github.com/metacubex/tailscale/ipn/ipnstate"
)

var errTailscaleOutboundUnavailable = errors.New("Tailscale outbound is unavailable")

type tailscalePeer struct {
	ID       string   `json:"id"`
	Hostname string   `json:"hostname"`
	DNSName  string   `json:"dnsName"`
	OS       string   `json:"os"`
	IPs      []string `json:"ips"`
	Online   bool     `json:"online"`
	ExitNode bool     `json:"exitNode"`
	CanExit  bool     `json:"canExit"`
}

type tailscaleStatus struct {
	State   string          `json:"state"`
	AuthURL string          `json:"authUrl,omitempty"`
	IPs     []string        `json:"ips"`
	Peers   []tailscalePeer `json:"peers"`
}

func tailscaleStatusView(status *ipnstate.Status) tailscaleStatus {
	result := tailscaleStatus{IPs: []string{}, Peers: []tailscalePeer{}}
	if status == nil {
		return result
	}
	result.State, result.AuthURL = status.BackendState, status.AuthURL
	for _, ip := range status.TailscaleIPs {
		result.IPs = append(result.IPs, ip.String())
	}
	for _, peer := range status.Peer {
		if peer == nil {
			continue
		}
		item := tailscalePeer{
			ID: string(peer.ID), Hostname: peer.HostName, DNSName: peer.DNSName,
			OS: peer.OS, IPs: []string{}, Online: peer.Online,
			ExitNode: peer.ExitNode, CanExit: peer.ExitNodeOption,
		}
		for _, ip := range peer.TailscaleIPs {
			item.IPs = append(item.IPs, ip.String())
		}
		result.Peers = append(result.Peers, item)
	}
	sort.Slice(result.Peers, func(i, j int) bool {
		if result.Peers[i].Hostname == result.Peers[j].Hostname {
			return result.Peers[i].ID < result.Peers[j].ID
		}
		return result.Peers[i].Hostname < result.Peers[j].Hostname
	})
	return result
}

func tailscaleClient(ctx context.Context, name string) (*local.Client, error) {
	proxy := lookupProxy(name)
	if proxy == nil {
		return nil, errTailscaleOutboundUnavailable
	}
	wrapped, ok := proxy.Adapter().(interface{ Underlying() outbound.ProxyAdapter })
	if !ok {
		return nil, errTailscaleOutboundUnavailable
	}
	controller, ok := wrapped.Underlying().(interface {
		LocalClient(context.Context) (*local.Client, error)
	})
	if !ok {
		return nil, errTailscaleOutboundUnavailable
	}
	return controller.LocalClient(ctx)
}
