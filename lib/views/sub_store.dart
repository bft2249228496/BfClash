import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/plugins/sub_store.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class SubStoreView extends ConsumerStatefulWidget {
  const SubStoreView({super.key});

  @override
  ConsumerState<SubStoreView> createState() => _SubStoreViewState();
}

class _SubStoreViewState extends ConsumerState<SubStoreView> {
  final TextEditingController _remoteUrlController = TextEditingController();
  SubStoreBackendStatus? _status;
  bool _localMode = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final remoteUrl = await preferences.getSubStoreRemoteUrl();
    SubStoreBackendStatus? status;
    if (system.isAndroid) {
      try {
        status = await subStoreService.status();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _remoteUrlController.text = remoteUrl;
      _status = status;
      _localMode = system.isAndroid;
    });
  }

  @override
  void dispose() {
    _remoteUrlController.dispose();
    super.dispose();
  }

  String get _activeEndpoint {
    if (_localMode) return _status?.endpoint ?? 'http://127.0.0.1:3001';
    return _remoteUrlController.text.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  Uri? get _activeEndpointUri {
    final uri = Uri.tryParse(_activeEndpoint);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme)) {
      return null;
    }
    return uri;
  }

  Future<void> _toggleLocalBackend() async {
    if (_busy || !system.isAndroid) return;
    setState(() => _busy = true);
    try {
      var status = _status;
      if (status?.isRunning == true) {
        status = await subStoreService.stop();
      } else {
        status = await subStoreService.start();
        for (
          var attempt = 0;
          attempt < 20 && status?.isBusy == true;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          status = await subStoreService.status();
        }
      }
      if (!mounted) return;
      setState(() => _status = status);
      final message = status?.isRunning == true
          ? context.appLocalizations.subStoreStarted
          : status?.phase == SubStoreBackendPhase.failed
          ? context.appLocalizations.subStoreStartFailed
          : context.appLocalizations.subStoreStopped;
      context.showNotifier(message);
    } catch (error) {
      if (mounted) {
        context.showNotifier(
          '${context.appLocalizations.subStoreStartFailed}: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editRemoteEndpoint() async {
    var value = _remoteUrlController.text;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.appLocalizations.subStoreRemoteEndpoint),
        content: TextFormField(
          initialValue: value,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'https://sub-store.example.com',
            helperText: context.appLocalizations.subStoreRemoteEndpointHint,
          ),
          onChanged: (text) => value = text.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.appLocalizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, value),
            child: Text(context.appLocalizations.save),
          ),
        ],
      ),
    );
    if (result == null) return;
    final uri = Uri.tryParse(result.replaceFirst(RegExp(r'/+$'), ''));
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme)) {
      if (mounted) {
        context.showNotifier(context.appLocalizations.subStoreInvalidEndpoint);
      }
      return;
    }
    _remoteUrlController.text = uri.toString();
    await preferences.saveSubStoreRemoteUrl(uri.toString());
    if (mounted) setState(() {});
  }

  void _openConsole() {
    final endpoint = _activeEndpointUri;
    if (endpoint == null) {
      context.showNotifier(context.appLocalizations.subStoreInvalidEndpoint);
      return;
    }
    if (_localMode && _status?.isRunning != true) {
      context.showNotifier(context.appLocalizations.subStoreStartFirst);
      return;
    }
    final uri = Uri.parse(
      'https://sub-store.vercel.app',
    ).replace(queryParameters: {'api': endpoint.toString()});
    dialogs.openUrl(uri.toString());
  }

  String _statusLabel() {
    if (!system.isAndroid) return context.appLocalizations.subStoreAndroidOnly;
    if (_busy || _status?.phase == SubStoreBackendPhase.starting) {
      return context.appLocalizations.subStoreStarting;
    }
    return switch (_status?.phase) {
      SubStoreBackendPhase.running => context.appLocalizations.subStoreRunning,
      SubStoreBackendPhase.failed => context.appLocalizations.subStoreFailed,
      _ => context.appLocalizations.subStoreStopped,
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final items = [
      ...generateSection(
        title: context.appLocalizations.subStoreMode,
        items: [
          ListItem(
            leading: Icon(_localMode ? Icons.smartphone : Icons.cloud_outlined),
            title: Text(
              _localMode
                  ? context.appLocalizations.subStoreLocalMode
                  : context.appLocalizations.subStoreRemoteMode,
            ),
            subtitle: Text(
              _localMode
                  ? context.appLocalizations.subStoreLocalModeDesc
                  : context.appLocalizations.subStoreRemoteModeDesc,
            ),
            trailing: Switch(
              value: _localMode,
              onChanged: system.isAndroid
                  ? (value) => setState(() => _localMode = value)
                  : null,
            ),
          ),
        ],
      ),
      if (_localMode)
        ...generateSection(
          title: context.appLocalizations.subStoreLocalBackend,
          items: [
            ListItem(
              leading: _busy
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      status?.isRunning == true
                          ? Icons.stop_circle
                          : Icons.play_circle,
                    ),
              title: Text(_statusLabel()),
              subtitle: Text(
                status?.error ??
                    '$_activeEndpoint · Sub-Store ${status?.backendVersion ?? '2.39.8'}',
              ),
              onTap: _busy ? null : _toggleLocalBackend,
            ),
          ],
        )
      else
        ...generateSection(
          title: context.appLocalizations.subStoreRemoteBackend,
          items: [
            ListItem(
              leading: const Icon(Icons.dns_outlined),
              title: Text(context.appLocalizations.subStoreRemoteEndpoint),
              subtitle: Text(
                _remoteUrlController.text.isEmpty
                    ? context.appLocalizations.subStoreNotConfigured
                    : _remoteUrlController.text,
              ),
              trailing: const Icon(Icons.edit),
              onTap: _editRemoteEndpoint,
            ),
          ],
        ),
      ...generateSection(
        title: context.appLocalizations.subStoreConsole,
        items: [
          ListItem(
            leading: const Icon(Icons.open_in_browser),
            title: Text(context.appLocalizations.subStoreOpenConsole),
            subtitle: Text(_activeEndpoint),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openConsole,
          ),
        ],
      ),
    ];
    return CommonScaffold(
      title: context.appLocalizations.subStoreTitle,
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, index) => items[index],
      ),
    );
  }
}
