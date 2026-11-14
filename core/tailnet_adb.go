//go:build with_gvisor && !no_tailscale

package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/netip"
	"runtime"
	"strconv"
	"sync"
	"time"
)

// adbForward is a short-lived, explicitly authorized tailnet-to-loopback relay.
// It does not authenticate ADB: Android's wireless debugging pairing remains required.
type adbForward struct {
	listener    net.Listener
	peer        netip.Addr
	port        uint16
	mu          sync.Mutex
	closed      bool
	connections map[net.Conn]struct{}
}

func newADBForward(listener net.Listener, peer netip.Addr, port uint16) (*adbForward, error) {
	if listener == nil || !peer.IsValid() || !peer.Is4() || !netip.MustParsePrefix("100.64.0.0/10").Contains(peer) || port == 0 {
		return nil, errors.New("invalid ADB forward configuration")
	}
	return &adbForward{listener: listener, peer: peer, port: port, connections: make(map[net.Conn]struct{})}, nil
}

func (f *adbForward) track(c net.Conn) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.closed {
		return false
	}
	f.connections[c] = struct{}{}
	return true
}

func (f *adbForward) untrack(c net.Conn) {
	f.mu.Lock()
	delete(f.connections, c)
	f.mu.Unlock()
}

func (f *adbForward) close() {
	f.mu.Lock()
	if !f.closed {
		f.closed = true
		_ = f.listener.Close()
		for c := range f.connections {
			_ = c.Close()
		}
	}
	f.mu.Unlock()
}

func (f *adbForward) serve(ctx context.Context) {
	defer f.close()
	done := make(chan struct{})
	defer close(done)
	go func() {
		select {
		case <-ctx.Done():
			f.close()
		case <-done:
		}
	}()
	for {
		conn, err := f.listener.Accept()
		if err != nil {
			return
		}
		remote, err := netip.ParseAddrPort(conn.RemoteAddr().String())
		if err != nil || remote.Addr().Unmap() != f.peer || !f.track(conn) {
			_ = conn.Close()
			continue
		}
		go f.forward(ctx, conn)
	}
}

func (f *adbForward) forward(ctx context.Context, incoming net.Conn) {
	defer f.untrack(incoming)
	defer incoming.Close()
	dialer := net.Dialer{Timeout: 5 * time.Second}
	outgoing, err := dialer.DialContext(ctx, "tcp4", net.JoinHostPort("127.0.0.1", strconv.Itoa(int(f.port))))
	if err != nil {
		return
	}
	if !f.track(outgoing) {
		_ = outgoing.Close()
		return
	}
	defer f.untrack(outgoing)
	defer outgoing.Close()
	done := make(chan struct{}, 1)
	go func() { _, _ = io.Copy(outgoing, incoming); done <- struct{}{} }()
	_, _ = io.Copy(incoming, outgoing)
	_ = incoming.Close()
	_ = outgoing.Close()
	<-done
}

type adbForwardState struct {
	cancel  context.CancelFunc
	fixed   bool
	forward *adbForward
}

func (t *appTailnetOutbound) StartADBForward(ctx context.Context, peer netip.Addr, port uint16, fixed bool) error {
	if runtime.GOOS != "android" {
		return errors.New("ADB forwarding is Android only")
	}
	if !peer.Is4() || !netip.MustParsePrefix("100.64.0.0/10").Contains(peer) || port == 0 {
		return errors.New("invalid ADB forwarding target")
	}
	if err := t.start(ctx); err != nil {
		return err
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.closed {
		return errors.New("Tailscale is closed")
	}
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if t.adbForwards == nil {
		t.adbForwards = make(map[uint16]adbForwardState)
	}
	if _, exists := t.adbForwards[port]; exists {
		return errors.New("ADB port already forwarded")
	}
	listenPort := port
	if fixed {
		listenPort = 43785
		for oldPort, state := range t.adbForwards {
			if state.fixed {
				state.cancel()
				state.forward.close()
				delete(t.adbForwards, oldPort)
			}
		}
	}
	if len(t.adbForwards) >= 2 {
		return errors.New("too many ADB ports")
	}
	listener, err := t.server.Listen("tcp", fmt.Sprintf(":%d", listenPort))
	if err != nil {
		return err
	}
	forward, err := newADBForward(listener, peer, port)
	if err != nil {
		_ = listener.Close()
		return err
	}
	forwardCtx, cancel := context.WithTimeout(context.Background(), 60*time.Minute)
	t.adbForwards[port] = adbForwardState{cancel: cancel, forward: forward, fixed: fixed}
	go func() {
		forward.serve(forwardCtx)
		cancel()
		t.mu.Lock()
		if current, ok := t.adbForwards[port]; ok && current.forward == forward {
			delete(t.adbForwards, port)
		}
		t.mu.Unlock()
	}()
	return nil
}

func (t *appTailnetOutbound) StopADBForwards() {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.stopADBForwardsLocked()
}

func (t *appTailnetOutbound) stopADBForwardsLocked() {
	for port, forward := range t.adbForwards {
		forward.cancel()
		forward.forward.close()
		delete(t.adbForwards, port)
	}
}

func (t *appTailnetOutbound) StopADBForward(port uint16) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if forward, ok := t.adbForwards[port]; ok {
		forward.cancel()
		forward.forward.close()
		delete(t.adbForwards, port)
	}
}
