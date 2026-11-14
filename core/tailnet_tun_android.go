//go:build android && cgo

package main

func getTunDiagnosticState() (tunReady bool, hookActive bool, protectOk bool) {
	return tunHandler != nil, activeTunHandler.Load() != nil, !protectFailing.Load()
}
