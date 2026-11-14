package main

import (
	"context"
	"fmt"

	"github.com/metacubex/mihomo/dns"
	"github.com/metacubex/tailscale/client/local"
	D "github.com/miekg/dns"
)

type appTailnetDNS struct {
	name   string
	client func(context.Context) (*local.Client, error)
}

func (d appTailnetDNS) Address() string  { return "tailscale://" + d.name }
func (d appTailnetDNS) ResetConnection() {}

func (d appTailnetDNS) ExchangeContext(ctx context.Context, query *D.Msg) (*D.Msg, error) {
	if len(query.Question) != 1 {
		return nil, fmt.Errorf("Tailscale DNS requires one question")
	}
	q := query.Question[0]
	kind, ok := D.TypeToString[q.Qtype]
	if !ok {
		return nil, fmt.Errorf("unsupported Tailscale DNS question type %d", q.Qtype)
	}
	client, err := d.client(ctx)
	if err != nil {
		return nil, err
	}
	wire, _, err := client.QueryDNS(ctx, q.Name, kind)
	if err != nil {
		return nil, err
	}
	var reply D.Msg
	if err := reply.Unpack(wire); err != nil {
		return nil, err
	}
	reply.Id = query.Id
	return &reply, nil
}

func registerAppTailnetDNS(name string, client func(context.Context) (*local.Client, error)) func() {
	return dns.RegisterTailscaleDnsClient(name, appTailnetDNS{name: name, client: client})
}
