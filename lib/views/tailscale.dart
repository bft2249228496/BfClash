import 'dart:async';

import 'package:bfclash/common/common.dart';
import 'package:bfclash/core/core.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class TailscaleView extends ConsumerStatefulWidget {
  const TailscaleView({super.key, this.androidForTesting});

  @visibleForTesting
  final bool? androidForTesting;

  @override
  ConsumerState<TailscaleView> createState() => _TailscaleViewState();
}

class _TailscaleViewState extends ConsumerState<TailscaleView> {
  bool _busy = false;
  String? _error;
  String? _notice;
  Map<String, dynamic>? _status;
  final _adbDiscovery = const MethodChannel('$packageName/adb-discovery');
  Future<void> _adbQueue = Future.value();
  String? _adbPeer;
  String? _adbPeerName;
  final Set<int> _adbPorts = {};
  DateTime? _adbExpiresAt;
  bool _adbCloseUnconfirmed = false;
  bool get _isAndroid => widget.androidForTesting ?? system.isAndroid;
  int _adbGeneration = 0;
  Timer? _adbTimer;
  Timer? _adbExpiryTimer;
  Future<void>? _adbClosing;
  late final CoreController _adbCore;

  @override
  void initState() {
    super.initState();
    _adbCore = ref.read(coreHandlerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(appSettingProvider).tailscaleEnabled) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void dispose() {
    _adbTimer?.cancel();
    _adbExpiryTimer?.cancel();
    _adbGeneration++;
    if (_adbPeer != null || _adbCloseUnconfirmed) {
      unawaited(
        _adbQueue
            .then((_) async {
              try {
                await _adbDiscovery.invokeMethod<bool>('stop');
              } finally {
                await _adbCore.stopTailscaleADB(bfclashTailscaleOutboundName);
                _adbDiscovery.setMethodCallHandler(null);
              }
            })
            .catchError((_) {}),
      );
    }
    super.dispose();
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_busy) return;
    if (!enabled && _adbPeer != null) {
      try {
        await _endADB();
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = context.appLocalizations.tailnetRequestFailed,
          );
        }
        return;
      }
      if (!mounted) return;
    }
    final previous = ref.read(appSettingProvider).tailscaleEnabled;
    final settings = ref.read(appSettingProvider.notifier);
    final setup = ref.read(setupActionProvider.notifier);
    final core = ref.read(coreHandlerProvider);
    final connected = ref.read(coreStatusProvider) == CoreStatus.connected;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    settings.update((state) => state.copyWith(tailscaleEnabled: enabled));
    var appliedSuccessfully = true;
    try {
      if (connected) {
        final applied = await setup.applyProfile(force: true);
        if (!applied) throw StateError('profile application failed');
        if (enabled) {
          final names = await core.getTailscaleOutbounds();
          if (!names.contains(bfclashTailscaleOutboundName)) {
            throw StateError('Tailscale outbound unavailable');
          }
        }
      }
    } catch (_) {
      appliedSuccessfully = false;
      settings.update((state) => state.copyWith(tailscaleEnabled: previous));
      var restoreFailed = false;
      try {
        if (connected) {
          restoreFailed = !await setup.applyProfile(force: true);
        }
      } catch (_) {
        restoreFailed = true;
      }
      if (mounted) {
        _error = restoreFailed
            ? context.appLocalizations.tailnetRestoreFailed
            : context.appLocalizations.tailnetApplyFailed;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted &&
        appliedSuccessfully &&
        ref.read(appSettingProvider).tailscaleEnabled) {
      await _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_busy || !ref.read(appSettingProvider).tailscaleEnabled) return;
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      setState(() => _error = context.appLocalizations.tailnetNeedProfile);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await ref
          .read(coreHandlerProvider)
          .getTailscaleStatus(bfclashTailscaleOutboundName);
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = null;
          _error = context.appLocalizations.tailnetRequestFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final core = _adbCore;
      if (!await core.startTailscaleLogin(bfclashTailscaleOutboundName)) {
        throw StateError('login request failed');
      }
      for (var attempt = 0; attempt < 10 && mounted; attempt++) {
        final status = await core.getTailscaleStatus(
          bfclashTailscaleOutboundName,
        );
        if (!mounted) return;
        setState(() => _status = status);
        if ((status['authUrl'] as String? ?? '').isNotEmpty ||
            status['state'] == 'Running') {
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (mounted) {
        setState(() => _error = context.appLocalizations.tailnetAuthPending);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.tailnetRequestFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLogin() async {
    final uri = Uri.tryParse(_status?['authUrl'] as String? ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'login.tailscale.com' ||
        uri.userInfo.isNotEmpty) {
      setState(() => _error = context.appLocalizations.tailnetRequestFailed);
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      setState(() => _error = context.appLocalizations.tailnetRequestFailed);
    }
  }

  Future<void> _logout() async {
    final labels = context.appLocalizations;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(labels.tailnetLogout),
        content: Text(labels.tailnetLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(labels.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(labels.confirm),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _busy) return;
    if (_adbPeer != null) {
      try {
        await _endADB();
      } catch (_) {
        if (mounted) setState(() => _error = labels.tailnetRequestFailed);
        return;
      }
      if (!mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await ref
          .read(coreHandlerProvider)
          .logoutTailscale(bfclashTailscaleOutboundName)) {
        throw StateError('logout failed');
      }
      if (mounted) setState(() => _status = null);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.tailnetRequestFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openADB(String peer, String hostname) async {
    final labels = context.appLocalizations;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${labels.tailnetAdb} · $hostname'),
        content: SingleChildScrollView(
          child: Text(labels.tailnetAdbDescription),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(labels.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(labels.tailnetAdbOpen),
          ),
        ],
      ),
    );
    if (!mounted || approved != true || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await _endADB();
      if (!mounted) return;
      final core = ref.read(coreHandlerProvider);
      final generation = ++_adbGeneration;
      _adbPeer = peer;
      _adbPeerName = hostname;
      _adbDiscovery.setMethodCallHandler((call) async {
        if (generation != _adbGeneration) return;
        if (call.method == 'expired' || call.method == 'error') {
          await _endADB();
          if (mounted) {
            setState(() {
              _notice = null;
              if (call.method == 'error') _error = labels.tailnetRequestFailed;
            });
          }
          return;
        }
        final port = call.arguments;
        if (port is! int || port < 1 || port > 65535) return;
        _adbQueue = _adbQueue
            .then((_) async {
              if (generation != _adbGeneration) return;
              if (call.method == 'found') {
                if (!await core.startTailscaleADB(
                  bfclashTailscaleOutboundName,
                  peer,
                  port,
                )) {
                  throw StateError('ADB forward failed');
                }
                if (mounted && generation == _adbGeneration) {
                  setState(() => _adbPorts.add(port));
                }
              } else if (call.method == 'lost') {
                if (!await core.stopTailscaleADBPort(
                  bfclashTailscaleOutboundName,
                  port,
                )) {
                  throw StateError('ADB forward stop failed');
                }
                if (mounted && generation == _adbGeneration) {
                  setState(() => _adbPorts.remove(port));
                }
              }
            })
            .catchError((_) {
              if (mounted) setState(() => _error = labels.tailnetRequestFailed);
              if (generation == _adbGeneration) {
                scheduleMicrotask(
                  () => unawaited(_endADB().catchError((_) {})),
                );
              }
            });
      });
      if (await _adbDiscovery.invokeMethod<bool>('start') != true) {
        throw StateError('ADB discovery failed');
      }
      if (!mounted || generation != _adbGeneration) {
        await _endADB();
        return;
      }
      _adbExpiresAt = DateTime.now().add(const Duration(minutes: 15));
      _adbExpiryTimer = Timer(const Duration(minutes: 15), () {
        unawaited(
          _endADB()
              .then((_) {
                if (mounted) setState(() => _notice = null);
              })
              .catchError((_) {
                if (mounted) {
                  setState(() => _error = labels.tailnetRequestFailed);
                }
              }),
        );
      });
      _adbTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      if (mounted) setState(() => _notice = labels.tailnetAdbSuccess);
    } catch (_) {
      await _endADB();
      if (mounted) setState(() => _error = labels.tailnetRequestFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endADB() {
    return _adbClosing ??= _closeADB().whenComplete(() => _adbClosing = null);
  }

  Future<void> _closeADB() async {
    _adbTimer?.cancel();
    _adbTimer = null;
    _adbExpiryTimer?.cancel();
    _adbExpiryTimer = null;
    _adbGeneration++;
    if (_adbPeer == null && !_adbCloseUnconfirmed) return;
    _adbPeer = null;
    _adbPeerName = null;
    _adbExpiresAt = null;
    _adbPorts.clear();
    _adbCloseUnconfirmed = true;
    try {
      try {
        await _adbDiscovery.invokeMethod<bool>('stop');
      } finally {
        await _adbQueue;
        try {
          if (!await _adbCore.stopTailscaleADB(bfclashTailscaleOutboundName)) {
            throw StateError('ADB forwarding stop failed');
          }
          _adbCloseUnconfirmed = false;
        } finally {
          _adbDiscovery.setMethodCallHandler(null);
        }
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _stopADB() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await _endADB();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.tailnetRequestFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.appLocalizations;
    final enabled = ref.watch(
      appSettingProvider.select((state) => state.tailscaleEnabled),
    );
    final state = _status?['state'] as String?;
    final stateLabel = switch (state) {
      'Running' => labels.tailnetStatusRunning,
      'NeedsLogin' || 'NeedsMachineAuth' => labels.tailnetStatusNeedsLogin,
      'Starting' => labels.tailnetStatusStarting,
      _ => labels.tailnetStatusOther,
    };
    final peers = (_status?['peers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .toList();
    final authUrl = _status?['authUrl'] as String? ?? '';
    return CommonScaffold(
      title: labels.tailnetTitle,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(labels.tailnetEnable),
            subtitle: Text(labels.tailnetEnableDesc),
            trailing: Switch(
              value: enabled,
              onChanged: _busy ? null : _setEnabled,
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          if (_notice != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_notice!)),
          if (!enabled) ListTile(title: Text(labels.tailnetDisabled)),
          if (enabled) ...[
            ListTile(
              title: Text(labels.tailnetStatus),
              subtitle: Text(stateLabel),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _refresh,
                  child: Text(labels.tailnetRefresh),
                ),
                if (state != 'Running')
                  OutlinedButton(
                    onPressed: _busy ? null : _login,
                    child: Text(labels.tailnetLogin),
                  ),
                if (authUrl.isNotEmpty && state != 'Running')
                  FilledButton(
                    onPressed: _busy ? null : _openLogin,
                    child: Text(labels.tailnetOpenLogin),
                  ),
                if (state == 'Running')
                  OutlinedButton(
                    onPressed: _busy ? null : _logout,
                    child: Text(labels.tailnetLogout),
                  ),
                if (_isAndroid && (_adbPeer != null || _adbCloseUnconfirmed))
                  OutlinedButton(
                    onPressed: _busy ? null : _stopADB,
                    child: Text(labels.tailnetAdbStop),
                  ),
              ],
            ),
            if (_isAndroid)
              ListTile(
                title: Text(labels.tailnetAdb),
                subtitle: Text(
                  _adbCloseUnconfirmed
                      ? labels.tailnetAdbCloseUnknown
                      : _adbPeer == null
                      ? labels.tailnetAdbInactive
                      : '${_adbPorts.isEmpty ? labels.tailnetAdbWaiting : labels.tailnetAdbReady}\n${_adbPeerName ?? ''} · ${_adbExpiresAt == null ? '15:00' : _adbCountdown()}${_adbPorts.isEmpty ? '' : '\n${labels.tailnetAdbPorts}: ${(_adbPorts.toList()..sort()).join(', ')}'}\n${labels.tailnetAdbPageLifetime}',
                ),
              ),
            const SizedBox(height: 16),
            ListHeader(title: labels.tailnetDevices),
            if (peers.isEmpty) ListTile(title: Text(labels.tailnetNoDevices)),
            for (final peer in peers) ...[
              ListTile(
                title: Text(peer['hostname'] as String? ?? ''),
                subtitle: Text(
                  (peer['ips'] as List<dynamic>? ?? const [])
                      .whereType<String>()
                      .join(', '),
                ),
                trailing: Text(
                  peer['online'] == true
                      ? labels.tailnetOnline
                      : labels.tailnetOffline,
                ),
              ),
              if (_isAndroid &&
                  state == 'Running' &&
                  peer['online'] == true &&
                  (peer['ips'] as List<dynamic>? ?? const [])
                      .whereType<String>()
                      .any((ip) => ip.contains('.')))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => _openADB(
                            (peer['ips'] as List<dynamic>)
                                .whereType<String>()
                                .firstWhere((ip) => ip.contains('.')),
                            peer['hostname'] as String? ?? '',
                          ),
                    child: Text(labels.tailnetAdb),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  String _adbCountdown() {
    final seconds = _adbExpiresAt!
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 900);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
