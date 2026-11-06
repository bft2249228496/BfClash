//go:build with_gvisor && !no_tailscale

package outbound

import (
	"context"
	"errors"
	"io"
	"net"
	"net/netip"
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
