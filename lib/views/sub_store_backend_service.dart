import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bfclash/common/common.dart';
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
  final String _endpoint = 'http://127.0.0.1:3001';
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
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 500);
      final request = await client.getUrl(Uri.parse('$_endpoint/api/status'));
      final response = await request.close();
      if (response.statusCode == 200) {
        _phase = SubStoreBackendPhase.running;
        _error = null;
      } else {
        if (_process == null) _phase = SubStoreBackendPhase.stopped;
      }
    } catch (_) {
      if (_process == null) {
        _phase = SubStoreBackendPhase.stopped;
      }
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

      final scriptPath = p.join(
        runtimeDir,
        'data',
        'flutter_assets',
        'assets',
        'substore',
        'backend',
        '2.39.8',
        'sub-store-0.min.js',
      );

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
        environment: {'SUB_STORE_PORT': '3001'},
        mode: ProcessStartMode.normal,
      );

      _process?.stdout.transform(utf8.decoder).listen((data) {
        commonPrint.log('SubStore stdout: $data');
      });

      _process?.stderr.transform(utf8.decoder).listen((data) {
        commonPrint.log('SubStore stderr: $data');
      });

      unawaited(
        _process?.exitCode.then((exitCode) {
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
        _phase = SubStoreBackendPhase.running;
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

    _process?.kill(ProcessSignal.sigterm);
    _process = null;
    _phase = SubStoreBackendPhase.stopped;
    return status;
  }
}

final desktopSubStoreManager = DesktopSubStoreManager();
