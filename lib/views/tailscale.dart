import 'dart:async';

import 'package:bfclash/common/common.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class TailscaleView extends ConsumerStatefulWidget {
  const TailscaleView({super.key});

  @override
  ConsumerState<TailscaleView> createState() => _TailscaleViewState();
}

class _TailscaleViewState extends ConsumerState<TailscaleView> {
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(appSettingProvider).tailscaleEnabled) {
        unawaited(_refresh());
      }
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_busy) return;
    final previous = ref.read(appSettingProvider).tailscaleEnabled;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(tailscaleEnabled: enabled));
    var appliedSuccessfully = true;
    try {
      if (ref.read(coreStatusProvider) == CoreStatus.connected) {
        final applied = await ref
            .read(setupActionProvider.notifier)
            .applyProfile(force: true);
        if (!applied) throw StateError('profile application failed');
        if (enabled) {
          final names = await ref
              .read(coreHandlerProvider)
              .getTailscaleOutbounds();
          if (!names.contains(bfclashTailscaleOutboundName)) {
            throw StateError('Tailscale outbound unavailable');
          }
        }
      }
    } catch (_) {
      appliedSuccessfully = false;
      if (!mounted) return;
      ref
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(tailscaleEnabled: previous));
      var restoreFailed = false;
      try {
        if (ref.read(coreStatusProvider) == CoreStatus.connected) {
          restoreFailed = !await ref
              .read(setupActionProvider.notifier)
              .applyProfile(force: true);
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
      final core = ref.read(coreHandlerProvider);
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
              ],
            ),
            const SizedBox(height: 16),
            ListHeader(title: labels.tailnetDevices),
            if (peers.isEmpty) ListTile(title: Text(labels.tailnetNoDevices)),
            for (final peer in peers)
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
          ],
        ],
      ),
    );
  }
}
