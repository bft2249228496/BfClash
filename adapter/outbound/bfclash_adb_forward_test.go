//go:build with_gvisor && !no_tailscale

package outbound

import (
	"context"
	"io"
	"net"
	"net/netip"
	"strconv"
	"testing"
	"time"
)

type adbTestListener struct {
	net.Listener
	peer string
}
type adbTestConn struct {
	net.Conn
	peer string
}

func (l *adbTestListener) Accept() (net.Conn, error) {
	c, err := l.Listener.Accept()
	if err != nil {
		return nil, err
	}
	return &adbTestConn{Conn: c, peer: l.peer}, nil
}
func (c *adbTestConn) RemoteAddr() net.Addr {
	return &net.TCPAddr{IP: net.ParseIP(c.peer), Port: 12345}
}

func TestADBForwardOnlyAuthorizedPeerAndClosesOnCancel(t *testing.T) {
	for _, tc := range []struct {
		name, peer string
		allowed    bool
	}{{"allowed", "100.64.0.7", true}, {"denied", "100.64.0.8", false}} {
		t.Run(tc.name, func(t *testing.T) {
			target, err := net.Listen("tcp4", "127.0.0.1:0")
			if err != nil {
				t.Fatal(err)
			}
			defer target.Close()
			go func() {
				for {
					c, e := target.Accept()
					if e != nil {
						return
					}
					go func() { defer c.Close(); _, _ = io.Copy(c, c) }()
				}
			}()
			listener, err := net.Listen("tcp4", "127.0.0.1:0")
			if err != nil {
				t.Fatal(err)
			}
			_, portText, _ := net.SplitHostPort(target.Addr().String())
			port, _ := strconv.Atoi(portText)
			f, err := newADBForward(&adbTestListener{Listener: listener, peer: tc.peer}, netip.MustParseAddr("100.64.0.7"), uint16(port))
			if err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			go f.serve(ctx)
			client, err := net.Dial("tcp4", listener.Addr().String())
			if err != nil {
				t.Fatal(err)
			}
			defer client.Close()
			_ = client.SetDeadline(time.Now().Add(2 * time.Second))
			_, _ = client.Write([]byte("hello"))
			result := make([]byte, 5)
			_, err = io.ReadFull(client, result)
			if tc.allowed && (err != nil || string(result) != "hello") {
				t.Fatalf("allowed peer failed: %q %v", result, err)
			}
			if !tc.allowed && err == nil {
				t.Fatal("unauthorized peer reached local service")
			}
			cancel()
			time.Sleep(20 * time.Millisecond)
			if tc.allowed {
				if _, err := client.Read(make([]byte, 1)); err == nil {
					t.Fatal("active connection survived shutdown")
				}
			}
		})
	}
}

func TestADBForwardRejectsInvalidConfiguration(t *testing.T) {
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	for _, p := range []netip.Addr{netip.MustParseAddr("192.168.1.1"), netip.IPv4Unspecified(), netip.IPv6Loopback()} {
		if _, err := newADBForward(listener, p, 5555); err == nil {
			t.Fatalf("accepted peer %s", p)
		}
	}
}
