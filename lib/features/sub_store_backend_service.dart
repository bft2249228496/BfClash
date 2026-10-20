import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/channel_config.dart';
import 'package:bfclash/plugins/sub_store.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class DesktopSubStoreManager {
  static DesktopSubStoreManager? _instance;

  DesktopSubStoreManager._internal()
    : _endpoint =
          'http://127.0.0.1:${system.isWindows && WindowsChannelConfig.isBeta ? 3002 : 3001}',
      _launch = null,
      _checkHealth = null,
      _pollInterval = const Duration(milliseconds: 200);

  @visibleForTesting
  DesktopSubStoreManager.testing({
    required Future<Process> Function() launch,
    required Future<bool> Function() checkHealth,
    Duration pollInterval = Duration.zero,
    String endpoint = 'http://127.0.0.1:0',
  }) : _endpoint = endpoint,
       _launch = launch,
       _checkHealth = checkHealth,
       _pollInterval = pollInterval;

  final Future<Process> Function()? _launch;
  final Future<bool> Function()? _checkHealth;
  final Duration _pollInterval;
  Future<void> _pending = Future<void>.value();

  Future<SubStoreBackendStatus> _serialize(
    Future<SubStoreBackendStatus> Function() action,
  ) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  factory DesktopSubStoreManager() {
    _instance ??= DesktopSubStoreManager._internal();
    return _instance!;
  }

  Process? _process;
  SubStoreBackendPhase _phase = SubStoreBackendPhase.stopped;
  final String _endpoint;
  String? _error;
  static const String _version = '2.39.8';

  SubStoreBackendStatus get status => SubStoreBackendStatus(
    phase: _phase,
    endpoint: _endpoint,
    backendVersion: _version,
    error: _error,
  );

  Future<SubStoreBackendStatus> getStatus() async {
    if (system.isAndroid) {
      return subStoreService.status();
    }
    await _probe();
    return status;
  }

  Future<void> _probe() async {
    final process = _process;
    if (process == null) {
      if (_phase != SubStoreBackendPhase.starting &&
          _phase != SubStoreBackendPhase.failed) {
        _phase = SubStoreBackendPhase.stopped;
      }
      return;
    }
    final healthy = await (_checkHealth ?? _probeEndpoint)();
    if (!identical(_process, process)) return;
    if (healthy) {
      _phase = SubStoreBackendPhase.running;
      _error = null;
    } else if (_phase != SubStoreBackendPhase.starting) {
      _phase = SubStoreBackendPhase.failed;
      _error = currentAppLocalizations.subStoreFailed;
    }
  }

  Future<bool> _probeEndpoint() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 500);
    try {
      final request = await client.getUrl(
        Uri.parse('$_endpoint/api/utils/env'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 1),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 1));
      final payload = jsonDecode(body);
      return response.statusCode == 200 &&
          payload is Map &&
          payload['status'] == 'success';
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<Process> _launchBackend() async {
    final runtimeDir = appPath.executableDirPath;
    final nodeExecutable = system.isWindows
        ? p.join(runtimeDir, 'node.exe')
        : 'node';
    final scriptPath = system.isWindows
        ? p.join(
            runtimeDir,
            'data',
            'substore',
            _version,
            'sub-store.bundle.js',
          )
        : p.join(
            runtimeDir,
            'data',
            'flutter_assets',
            'assets',
            'substore',
            'backend',
            _version,
            'sub-store-0.min.js',
          );
    final dataDir = Directory(p.join(await appPath.homeDirPath, 'substore'));
    await dataDir.create(recursive: true);
    if (system.isWindows && !await File(nodeExecutable).exists()) {
      throw MessageException(currentAppLocalizations.subStoreRuntimeMissing);
    }
    if (!await File(scriptPath).exists()) {
      throw MessageException(currentAppLocalizations.subStoreScriptMissing);
    }
    return Process.start(
      nodeExecutable,
      [scriptPath],
      environment: {
        'SUB_STORE_BACKEND_API_PORT': Uri.parse(_endpoint).port.toString(),
        'SUB_STORE_BACKEND_API_HOST': '127.0.0.1',
        'SUB_STORE_DATA_BASE_PATH': dataDir.path,
      },
      workingDirectory: dataDir.path,
      mode: ProcessStartMode.normal,
    );
  }

  Future<SubStoreBackendStatus> start() {
    if (system.isAndroid) return subStoreService.start();
    return _serialize(_start);
  }

  Future<SubStoreBackendStatus> _start() async {
    if (_phase == SubStoreBackendPhase.running) {
      return status;
    }

    _phase = SubStoreBackendPhase.starting;
    _error = null;

    try {
      if (_process != null) {
        await _stop();
        if (_process != null) return status;
        _phase = SubStoreBackendPhase.starting;
      }
      try {
        final reservation = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          Uri.parse(_endpoint).port,
          shared: false,
        );
        await reservation.close();
      } on SocketException {
        throw MessageException(currentAppLocalizations.subStorePortInUse);
      }
      _process = await (_launch ?? _launchBackend)();

      _process?.stdout.transform(utf8.decoder).listen((data) {
        commonPrint.log('SubStore stdout: $data');
      });

      _process?.stderr.transform(utf8.decoder).listen((data) {
        commonPrint.log('SubStore stderr: $data');
      });

      final startedProcess = _process;
      unawaited(
        startedProcess?.exitCode.then((exitCode) {
          if (!identical(_process, startedProcess)) return;
          _phase = SubStoreBackendPhase.stopped;
          _process = null;
        }),
      );

      for (var i = 0; i < 15; i++) {
        await Future<void>.delayed(_pollInterval);
        await _probe();
        if (_phase == SubStoreBackendPhase.running) break;
      }

      if (_phase != SubStoreBackendPhase.running) {
        await _stop();
        _phase = SubStoreBackendPhase.failed;
        _error = currentAppLocalizations.subStoreStartFailed;
      }

      return status;
    } catch (e) {
      _phase = SubStoreBackendPhase.failed;
      _error = e.toString();
      return status;
    }
  }

  Future<SubStoreBackendStatus> stop() {
    if (system.isAndroid) return subStoreService.stop();
    return _serialize(_stop);
  }

  Future<SubStoreBackendStatus> _stop() async {
    final process = _process;
    if (process != null) {
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        _phase = SubStoreBackendPhase.failed;
        _error = currentAppLocalizations.subStoreFailed;
        return status;
      }
    }
    if (identical(_process, process)) _process = null;
    _phase = SubStoreBackendPhase.stopped;
    _error = null;
    return status;
  }
}

final desktopSubStoreManager = DesktopSubStoreManager();
