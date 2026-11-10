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

class TailscaleAdbSession with ChangeNotifier {
  static final TailscaleAdbSession instance = TailscaleAdbSession._();
  TailscaleAdbSession._();

  static const sessionDuration = Duration(minutes: 60);

  final _discovery = const MethodChannel('$packageName/adb-discovery');
  Future<void> _queue = Future.value();
  String? _peer;
  String? _peerName;
  final Set<int> _ports = {};
  DateTime? _expiresAt;
  bool _closeUnconfirmed = false;
  int _generation = 0;
  Timer? _expiryTimer;
  Timer? _countdownTimer;
  Future<void>? _closing;
  CoreController? _core;

  String? get peer => _peer;
  String? get peerName => _peerName;
  Set<int> get ports => Set.unmodifiable(_ports);
  DateTime? get expiresAt => _expiresAt;
  bool get closeUnconfirmed => _closeUnconfirmed;
  bool get isActive => _peer != null;

  void bindCore(CoreController core) {
    _core = core;
  }

  Future<void> start({
    required CoreController core,
    required String peer,
    required String hostname,
    void Function(String error)? onError,
  }) async {
    _core = core;
    await end();
    final generation = ++_generation;
    _peer = peer;
    _peerName = hostname;
    _closeUnconfirmed = false;
    _queue = Future.value();
    _discovery.setMethodCallHandler((call) async {
      if (generation != _generation) return;
      if (call.method == 'expired' || call.method == 'error') {
        await end();
        if (call.method == 'error') {
          onError?.call('error');
        }
        notifyListeners();
        return;
      }
      final port = call.arguments;
      if (port is! int || port < 1 || port > 65535) return;
      _queue = _queue
          .then((_) async {
            if (generation != _generation) return;
            if (call.method == 'found') {
              if (!await core.startTailscaleADB(
                bfclashTailscaleOutboundName,
                peer,
                port,
              )) {
                throw StateError('ADB forward failed');
              }
              if (generation == _generation) {
                _ports.add(port);
                notifyListeners();
              }
            } else if (call.method == 'lost') {
              if (!await core.stopTailscaleADBPort(
                bfclashTailscaleOutboundName,
                port,
              )) {
                throw StateError('ADB forward stop failed');
              }
              if (generation == _generation) {
                _ports.remove(port);
                notifyListeners();
              }
            }
          })
          .catchError((_) {
            onError?.call('failed');
            if (generation == _generation) {
              scheduleMicrotask(() => unawaited(end().catchError((_) {})));
            }
          });
    });

    if (await _discovery.invokeMethod<bool>('start') != true) {
      throw StateError('ADB discovery failed');
    }
    if (generation != _generation) {
      await end();
      return;
    }
    _expiresAt = DateTime.now().add(sessionDuration);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    _expiryTimer = Timer(sessionDuration, () {
      unawaited(end().then((_) => notifyListeners()).catchError((_) {}));
    });
    notifyListeners();
  }

  Future<void> end() {
    return _closing ??= _close().whenComplete(() => _closing = null);
  }

  Future<void> _close() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _generation++;
    if (_peer == null && !_closeUnconfirmed) return;
    _peer = null;
    _peerName = null;
    _expiresAt = null;
    _ports.clear();
    _closeUnconfirmed = true;
    notifyListeners();
    try {
      try {
        await _discovery.invokeMethod<bool>('stop');
      } finally {
        await _queue;
        try {
          final core = _core;
          if (core != null &&
              !await core.stopTailscaleADB(bfclashTailscaleOutboundName)) {
            throw StateError('ADB forwarding stop failed');
          }
          _closeUnconfirmed = false;
        } finally {
          _discovery.setMethodCallHandler(null);
        }
      }
    } finally {
      notifyListeners();
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _generation++;
    _peer = null;
    _peerName = null;
    _expiresAt = null;
    _ports.clear();
    _closeUnconfirmed = false;
    _closing = null;
    _queue = Future.value();
    _core = null;
    _discovery.setMethodCallHandler(null);
  }
}

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
  bool get _isAndroid => widget.androidForTesting ?? system.isAndroid;
  late final CoreController _core;
  final _adbSession = TailscaleAdbSession.instance;

  @override
  void initState() {
    super.initState();
    _core = ref.read(coreHandlerProvider);
    _adbSession.bindCore(_core);
    _adbSession.addListener(_onAdbChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(appSettingProvider).tailscaleEnabled) {
        unawaited(_refresh());
      }
    });
  }

  void _onAdbChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _adbSession.removeListener(_onAdbChanged);
    super.dispose();
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_busy) return;
    if (!enabled && (_adbSession.isActive || _adbSession.closeUnconfirmed)) {
      try {
        await _adbSession.end();
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
      final core = _core;
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
    if (_adbSession.isActive || _adbSession.closeUnconfirmed) {
      try {
        await _adbSession.end();
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
      await _adbSession.start(
        core: _core,
        peer: peer,
        hostname: hostname,
        onError: (err) {
          if (mounted) {
            setState(() {
              _notice = null;
              if (err == 'error') _error = labels.tailnetRequestFailed;
            });
          }
        },
      );
      if (mounted) setState(() => _notice = labels.tailnetAdbSuccess);
    } catch (_) {
      await _adbSession.end();
      if (mounted) setState(() => _error = labels.tailnetRequestFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
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
      await _adbSession.end();
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
                if (_isAndroid &&
                    (_adbSession.isActive || _adbSession.closeUnconfirmed))
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
                  _adbSession.closeUnconfirmed
                      ? labels.tailnetAdbCloseUnknown
                      : !_adbSession.isActive
                      ? labels.tailnetAdbInactive
                      : '${_adbSession.ports.isEmpty ? labels.tailnetAdbWaiting : labels.tailnetAdbReady}\n${_adbSession.peerName ?? ''} · ${_adbCountdown()}${_adbSession.ports.isEmpty ? '' : '\n${labels.tailnetAdbPorts}: ${(_adbSession.ports.toList()..sort()).join(', ')}'}\n${labels.tailnetAdbPageLifetime}',
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
    final expiresAt = _adbSession.expiresAt;
    if (expiresAt == null) return '60:00';
    final seconds = expiresAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 3600);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
