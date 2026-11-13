package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/metacubex/mihomo/log"
	"net/netip"
	"runtime"
	"sync/atomic"
	"time"
	"unsafe"

	"github.com/metacubex/mihomo/tunnel"
)

type MethodCall struct {
	ID        string          `json:"id,omitempty"`
	Method    CoreMethod      `json:"method"`
	Arguments json.RawMessage `json:"arguments"`
}

func (call MethodCall) decodeArguments(target any) error {
	if len(call.Arguments) == 0 || string(call.Arguments) == "null" {
		return fmt.Errorf("missing arguments")
	}
	return json.Unmarshal(call.Arguments, target)
}

func decodeMethodArguments(call *MethodCall, response MethodResponse, target any) bool {
	if err := call.decodeArguments(target); err != nil {
		response.failure(
			"invalid_arguments",
			fmt.Sprintf("invalid arguments for %s: %v", call.Method, err),
			nil,
		)
		return false
	}
	return true
}

type MethodError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
	Details any    `json:"details"`
}

type MethodResponse struct {
	ID       string       `json:"id,omitempty"`
	Result   any          `json:"result"`
	Error    *MethodError `json:"error,omitempty"`
	callback unsafe.Pointer
	sent     *atomic.Bool
}

func newMethodResponse(id string, callback unsafe.Pointer) MethodResponse {
	return MethodResponse{
		ID:       id,
		callback: callback,
		sent:     &atomic.Bool{},
	}
}

func (response MethodResponse) JSON() ([]byte, error) {
	return json.Marshal(response)
}

func (response MethodResponse) claim() bool {
	if response.sent == nil {
		return true
	}
	return response.sent.CompareAndSwap(false, true)
}

func (response MethodResponse) success(result any) {
	if !response.claim() {
		return
	}
	response.Result = result
	response.Error = nil
	response.send()
}

func (response MethodResponse) failure(code, message string, details any) {
	if !response.claim() {
		return
	}
	response.Result = nil
	response.Error = &MethodError{
		Code:    code,
		Message: message,
		Details: details,
	}
	response.send()
}

func (response MethodResponse) notImplemented(method CoreMethod) {
	response.failure(
		"not_implemented",
		fmt.Sprintf("unknown method: %s", method),
		nil,
	)
}

func stackTrace() []byte {
	buf := make([]byte, 4096)
	return buf[:runtime.Stack(buf, false)]
}

func safeGo(response MethodResponse, run func()) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				logError("panic in async handler: %v\n%s", r, stackTrace())
				response.failure("internal_error", fmt.Sprintf("internal panic: %v", r), nil)
			}
		}()
		run()
	}()
}

func safeGoDetached(name string, run func()) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				logError("panic in %s: %v\n%s", name, r, stackTrace())
			}
		}()
		run()
	}()
}

type methodHandler func(call *MethodCall, response MethodResponse)

func withArguments[T any](handle func(params *T, response MethodResponse)) methodHandler {
	return func(call *MethodCall, response MethodResponse) {
		var params T
		if !decodeMethodArguments(call, response, &params) {
			return
		}
		handle(&params, response)
	}
}

func withDefaults[T any](
	defaults func() *T,
	handle func(params *T, response MethodResponse),
) methodHandler {
	return func(call *MethodCall, response MethodResponse) {
		params := defaults()
		if !decodeMethodArguments(call, response, params) {
			return
		}
		handle(params, response)
	}
}

func withoutArguments(handle func(response MethodResponse)) methodHandler {
	return func(_ *MethodCall, response MethodResponse) {
		handle(response)
	}
}

var methodHandlers = map[CoreMethod]methodHandler{
	initClashMethod: withArguments(func(params *InitParams, response MethodResponse) {
		response.success(handleInitClash(params))
	}),
	getIsInitMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleGetIsInit())
	}),
	forceGcMethod: withoutArguments(func(response MethodResponse) {
		handleForceGC()
		response.success(true)
	}),
	shutdownMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleShutdown())
	}),
	validateConfigMethod: withArguments(func(path *string, response MethodResponse) {
		response.success(handleValidateConfig(*path))
	}),
	updateConfigMethod: withArguments(func(params *UpdateParams, response MethodResponse) {
		response.success(handleUpdateConfig(params))
	}),
	setupConfigMethod: withDefaults(defaultSetupParams, func(params *SetupParams, response MethodResponse) {
		response.success(handleSetupConfig(params))
	}),
	getConfigMethod: withArguments(func(path *string, response MethodResponse) {
		rawConfig, err := handleGetConfig(*path)
		if err != nil {
			response.failure("core_error", err.Error(), nil)
			return
		}
		response.success(rawConfig)
	}),
	getProxiesMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleGetProxies())
	}),
	getTailscaleOutboundsMethod: withoutArguments(func(response MethodResponse) {
		response.success(tailscaleOutboundNames(tunnel.AllProxies()))
	}),
	getTailscaleStatusMethod: withArguments(func(name *string, response MethodResponse) {
		safeGo(response, func() {
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()
			client, err := tailscaleClient(ctx, *name)
			if err != nil {
				response.failure("tailscale_unavailable", "Tailscale is unavailable", nil)
				return
			}
			status, err := client.Status(ctx)
			if err != nil {
				response.failure("tailscale_status_failed", "Unable to read Tailscale status", nil)
				return
			}
			log.Debugln("[Tailscale] backend=%s, assigned addresses=%d", status.BackendState, len(status.TailscaleIPs))
			response.success(tailscaleStatusView(status))
		})
	}),
	startTailscaleLoginMethod: withArguments(func(name *string, response MethodResponse) {
		safeGo(response, func() {
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()
			client, err := tailscaleClient(ctx, *name)
			if err == nil {
				err = client.StartLoginInteractive(ctx)
			}
			if err != nil {
				response.failure("tailscale_login_failed", "Unable to start Tailscale login", nil)
				return
			}
			response.success(true)
		})
	}),
	logoutTailscaleMethod: withArguments(func(name *string, response MethodResponse) {
		safeGo(response, func() {
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()
			client, err := tailscaleClient(ctx, *name)
			if err == nil {
				err = client.Logout(ctx)
			}
			if err != nil {
				response.failure("tailscale_logout_failed", "Unable to log out of Tailscale", nil)
				return
			}
			response.success(true)
		})
	}),
	startTailscaleADBMethod: withArguments(func(params *TailscaleADBParams, response MethodResponse) {
		safeGo(response, func() {
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()
			peer, err := netip.ParseAddr(params.Peer)
			controller, controllerErr := tailscaleADB(params.Name)
			if err == nil && controllerErr == nil {
				err = controller.StartADBForward(ctx, peer, params.Port)
			} else if controllerErr != nil {
				err = controllerErr
			}
			if err != nil {
				response.failure("tailscale_adb_failed", "Unable to start temporary ADB forwarding", nil)
				return
			}
			response.success(true)
		})
	}),
	stopTailscaleADBMethod: withArguments(func(name *string, response MethodResponse) {
		controller, err := tailscaleADB(*name)
		if err != nil {
			response.failure("tailscale_adb_failed", "Unable to stop ADB forwarding", nil)
			return
		}
		controller.StopADBForwards()
		response.success(true)
	}),
	stopTailscaleADBPortMethod: withArguments(func(params *TailscaleADBParams, response MethodResponse) {
		controller, err := tailscaleADB(params.Name)
		if err != nil {
			response.failure("tailscale_adb_failed", "Unable to stop ADB forwarding", nil)
			return
		}
		controller.StopADBForward(params.Port)
		response.success(true)
	}),
	changeProxyMethod: withArguments(func(params *ChangeProxyParams, response MethodResponse) {
		safeGo(response, func() {
			response.success(handleChangeProxy(params))
		})
	}),
	getTrafficMethod: withArguments(func(onlyStatisticsProxy *bool, response MethodResponse) {
		response.success(handleGetTraffic(*onlyStatisticsProxy))
	}),
	getTotalTrafficMethod: withArguments(func(onlyStatisticsProxy *bool, response MethodResponse) {
		response.success(handleGetTotalTraffic(*onlyStatisticsProxy))
	}),
	resetTrafficMethod: withoutArguments(func(response MethodResponse) {
		handleResetTraffic()
		response.success(true)
	}),
	asyncTestDelayMethod: withArguments(func(params *TestDelayParams, response MethodResponse) {
		safeGo(response, func() {
			response.success(handleTestDelay(params))
		})
	}),
	getConnectionsMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleGetConnections())
	}),
	closeConnectionsMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleCloseConnections())
	}),
	resetConnectionsMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleResetConnections())
	}),
	closeConnectionMethod: withArguments(func(id *string, response MethodResponse) {
		response.success(handleCloseConnection(*id))
	}),
	getExternalProvidersMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleGetExternalProviders())
	}),
	getExternalProviderMethod: withArguments(func(name *string, response MethodResponse) {
		response.success(handleGetExternalProvider(*name))
	}),
	updateExternalProviderMethod: withArguments(func(name *string, response MethodResponse) {
		safeGo(response, func() {
			if err := handleUpdateExternalProvider(*name); err != nil {
				response.failure(err.Code, err.Message, err.Details)
				return
			}
			response.success("")
		})
	}),
	sideLoadExternalProviderMethod: withArguments(func(params *SideLoadParams, response MethodResponse) {
		safeGo(response, func() {
			if err := handleSideLoadExternalProvider(params.ProviderName, []byte(params.Data)); err != nil {
				response.failure(err.Code, err.Message, err.Details)
				return
			}
			response.success("")
		})
	}),
	updateGeoDataMethod: withArguments(func(geoType *string, response MethodResponse) {
		response.success(handleUpdateGeoData(*geoType))
	}),
	startLogMethod: withoutArguments(func(response MethodResponse) {
		handleStartLog()
		response.success(true)
	}),
	stopLogMethod: withoutArguments(func(response MethodResponse) {
		handleStopLog()
		response.success(true)
	}),
	startListenerMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleStartListener())
	}),
	stopListenerMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleStopListener())
	}),
	getMemoryMethod: withoutArguments(func(response MethodResponse) {
		safeGo(response, func() {
			response.success(handleGetMemory())
		})
	}),
	clearEffectMethod: withArguments(func(profileId *int64, response MethodResponse) {
		safeGo(response, func() {
			response.success(handleClearEffect(*profileId))
		})
	}),
}

func registerMethod(method CoreMethod, handler methodHandler) {
	if _, exists := methodHandlers[method]; exists {
		panic(fmt.Sprintf("duplicate handler for method %s", method))
	}
	methodHandlers[method] = handler
}

func handleMethodCall(call *MethodCall, response MethodResponse) {
	// The crash method is a developer-only fatal-path test. It must bypass the
	// recovery below so the core process terminates; on Android this also
	// terminates the in-process application.
	if call.Method == crashMethod {
		handleCrash()
		return
	}
	defer func() {
		if r := recover(); r != nil {
			logError("panic in handleMethodCall(%s): %v\n%s", call.Method, r, stackTrace())
			response.failure("internal_error", fmt.Sprintf("internal panic: %v", r), nil)
		}
	}()

	handler, exists := methodHandlers[call.Method]
	if !exists {
		response.notImplemented(call.Method)
		return
	}
	handler(call, response)
}
