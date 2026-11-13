//go:build !with_gvisor || no_tailscale

package main

func triggerTailnetDiagnostics(trigger string) {}

func getTailscaleDiagnosticsResult() any {
	return map[string]any{"available": false, "reason": "tailscale not built in this binary"}
}
