//go:build !with_gvisor || no_tailscale

package main

import (
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/tunnel"
)

func installAppTailnet(*config.Config) func() { return func() {} }

func applyAppTailnetMode(cfg *config.Config) { tunnel.SetMode(cfg.General.Mode) }
