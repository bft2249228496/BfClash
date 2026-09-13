import 'dart:async';

import 'package:flutter/services.dart';

enum VpnStatus { disconnected, connecting, connected, disconnecting, error }

class VpnServiceController {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.lansway.client/vpn_control',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.lansway.client/vpn_status',
  );

  static final StreamController<VpnStatus> _statusStreamController =
      StreamController<VpnStatus>.broadcast();

  static VpnStatus _currentStatus = VpnStatus.disconnected;
  static String? _lastErrorMessage;
  static bool _initialized = false;

  static VpnStatus get currentStatus => _currentStatus;
  static String? get lastErrorMessage => _lastErrorMessage;
  static Stream<VpnStatus> get statusStream => _statusStreamController.stream;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    try {
      _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is String) {
            _handleRawStatus(event);
          }
        },
        onError: (dynamic error) {
          _lastErrorMessage = error.toString();
          _currentStatus = VpnStatus.error;
          _statusStreamController.add(_currentStatus);
        },
      );
    } catch (_) {
      // 兼容测试环境无 EventChannel mock 的情况
    }

    // 同步初始化状态
    syncStatus();
  }

  static Future<String?> getStorageDirectory() async {
    try {
      final dir = await _methodChannel.invokeMethod<String>('getFilesDir');
      return dir;
    } catch (_) {
      return null;
    }
  }

  static Future<VpnStatus> syncStatus() async {
    try {
      final status = await _methodChannel.invokeMethod<String>('getStatus');
      if (status != null) {
        _handleRawStatus(status);
      }
    } catch (_) {}
    return _currentStatus;
  }

  static void _handleRawStatus(String raw) {
    if (raw.startsWith('error:')) {
      _lastErrorMessage = raw.substring(6);
      _currentStatus = VpnStatus.error;
    } else {
      switch (raw) {
        case 'connecting':
          _currentStatus = VpnStatus.connecting;
          _lastErrorMessage = null;
          break;
        case 'connected':
          _currentStatus = VpnStatus.connected;
          _lastErrorMessage = null;
          break;
        case 'disconnecting':
          _currentStatus = VpnStatus.disconnecting;
          break;
        case 'disconnected':
        default:
          _currentStatus = VpnStatus.disconnected;
          break;
      }
    }
    _statusStreamController.add(_currentStatus);
  }

  static Future<bool> startVpn(String configYaml) async {
    if (configYaml.trim().isEmpty) {
      throw ArgumentError('配置文件不能为空，拒绝启动空 TUN');
    }
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'startVpn',
        <String, dynamic>{'config': configYaml},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      _lastErrorMessage = e.message;
      _currentStatus = VpnStatus.error;
      _statusStreamController.add(_currentStatus);
      rethrow;
    }
  }

  static Future<bool> stopVpn() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopVpn');
      return result ?? false;
    } on PlatformException catch (e) {
      _lastErrorMessage = e.message;
      rethrow;
    }
  }
}
