//go:build !android || !cgo

package main

func getTunDiagnosticState() (tunReady bool, hookActive bool, protectOk bool) {
	return true, true, true
}
