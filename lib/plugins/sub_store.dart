import 'package:fl_clash/common/constant.dart';
import 'package:flutter/services.dart';

enum SubStoreBackendPhase { stopped, starting, running, failed }

class SubStoreBackendStatus {
  const SubStoreBackendStatus({
    required this.phase,
    required this.endpoint,
    required this.backendVersion,
    this.error,
  });

  factory SubStoreBackendStatus.fromMap(Map<Object?, Object?> map) {
    return SubStoreBackendStatus(
      phase: SubStoreBackendPhase.values.firstWhere(
        (phase) => phase.name == map['phase'],
        orElse: () => SubStoreBackendPhase.failed,
      ),
      endpoint: map['endpoint'] as String? ?? '',
      backendVersion: map['backendVersion'] as String? ?? '',
      error: map['error'] as String?,
    );
  }

  final SubStoreBackendPhase phase;
  final String endpoint;
  final String backendVersion;
  final String? error;

  bool get isRunning => phase == SubStoreBackendPhase.running;
  bool get isBusy => phase == SubStoreBackendPhase.starting;
}

class SubStoreService {
  SubStoreService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('$packageName/sub-store');

  final MethodChannel _channel;

  Future<SubStoreBackendStatus> status() => _invoke('status');

  Future<SubStoreBackendStatus> start() => _invoke('start');

  Future<SubStoreBackendStatus> stop() => _invoke('stop');

  Future<SubStoreBackendStatus> _invoke(String method) async {
    final response = await _channel.invokeMethod<Map<Object?, Object?>>(method);
    if (response == null) {
      throw StateError('Sub-Store backend returned no status');
    }
    return SubStoreBackendStatus.fromMap(response);
  }
}

final subStoreService = SubStoreService();
