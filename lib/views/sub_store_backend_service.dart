import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/channel_config.dart';
import 'package:bfclash/plugins/sub_store.dart';
import 'package:path/path.dart' as p;

class DesktopSubStoreManager {
  static DesktopSubStoreManager? _instance;

  DesktopSubStoreManager._internal();

  factory DesktopSubStoreManager() {
    _instance ??= DesktopSubStoreManager._internal();
    return _instance!;
  }

  Process? _process;
  SubStoreBackendPhase _phase = SubStoreBackendPhase.stopped;
  final String _endpoint =
      'http://127.0.0.1:${system.isWindows && WindowsChannelConfig.isBeta ? 3002 : 3001}';
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
      if (response.statusCode == 200 &&
          payload is Map &&
          payload['status'] == 'success') {
        _phase = SubStoreBackendPhase.running;
        _error = null;
      } else if (_process == null) {
        _phase = SubStoreBackendPhase.stopped;
      }
    } catch (_) {
      if (_process == null) _phase = SubStoreBackendPhase.stopped;
    } finally {
      client.close(force: true);
    }
  }

  Future<SubStoreBackendStatus> start() async {
    if (system.isAndroid) {
      return subStoreService.start();
    }

    if (_phase == SubStoreBackendPhase.running) {
      return status;
    }

    _phase = SubStoreBackendPhase.starting;
    _error = null;

    try {
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

      final hasRuntime = await File(nodeExecutable).exists();
      final hasScript = await File(scriptPath).exists();

      if (!hasRuntime && system.isWindows) {
        _phase = SubStoreBackendPhase.failed;
        _error = '未检测到内置 JS 运行时 (node.exe)。支持配置远程 Sub-Store 或置入单文件引擎。';
        return status;
      }

      if (!hasScript) {
        _phase = SubStoreBackendPhase.failed;
        _error = '未找到 Sub-Store 脚本资源 ($scriptPath)';
        return status;
      }

      _process = await Process.start(
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
        await Future.delayed(const Duration(milliseconds: 200));
        await _probe();
        if (_phase == SubStoreBackendPhase.running) break;
      }

      if (_phase != SubStoreBackendPhase.running) {
        final failedProcess = _process;
        _process = null;
        failedProcess?.kill();
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

  Future<SubStoreBackendStatus> stop() async {
    if (system.isAndroid) {
      return subStoreService.stop();
    }

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
    return status;
  }
}

final desktopSubStoreManager = DesktopSubStoreManager();
