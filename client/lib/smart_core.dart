import 'dart:convert';
import 'dart:io';

enum CoreType { mihomo, smartCore }

class CoreReleaseInfo {
  final String version;
  final String sha256;
  final String downloadUrl;
  final DateTime releaseDate;

  const CoreReleaseInfo({
    required this.version,
    required this.sha256,
    required this.downloadUrl,
    required this.releaseDate,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'sha256': sha256,
    'downloadUrl': downloadUrl,
    'releaseDate': releaseDate.toIso8601String(),
  };

  factory CoreReleaseInfo.fromJson(Map<String, dynamic> json) =>
      CoreReleaseInfo(
        version: json['version'] as String,
        sha256: json['sha256'] as String,
        downloadUrl: json['downloadUrl'] as String,
        releaseDate: DateTime.parse(json['releaseDate'] as String),
      );
}

class SmartCoreEngine {
  final Directory coreStorageDir;
  CoreType _activeCore = CoreType.mihomo;
  String _activeVersion = 'v1.19.30';

  SmartCoreEngine({required this.coreStorageDir});

  CoreType get activeCore => _activeCore;
  String get activeVersion => _activeVersion;

  File get _versionRecordFile =>
      File('${coreStorageDir.path}/active_core.json');

  Future<void> initialize() async {
    if (await _versionRecordFile.exists()) {
      try {
        final content = await _versionRecordFile.readAsString();
        final map = json.decode(content);
        if (map is Map<String, dynamic>) {
          _activeCore = map['coreType'] == 'smartCore'
              ? CoreType.smartCore
              : CoreType.mihomo;
          _activeVersion = map['version'] as String? ?? 'v1.19.30';
        }
      } catch (_) {}
    }
  }

  Future<bool> switchCore(CoreType targetCore, {String? targetVersion}) async {
    final previousCore = _activeCore;
    final previousVersion = _activeVersion;

    try {
      _activeCore = targetCore;
      if (targetVersion != null) {
        _activeVersion = targetVersion;
      }
      await _persistState();
      return true;
    } catch (_) {
      // 失败回退
      _activeCore = previousCore;
      _activeVersion = previousVersion;
      return false;
    }
  }

  Future<bool> verifyAndRollbackOnFailure(bool healthCheckPassed) async {
    if (!healthCheckPassed) {
      // 健康检查失败，自动回退到默认稳定 Mihomo 内核
      _activeCore = CoreType.mihomo;
      _activeVersion = 'v1.19.30';
      await _persistState();
      return false;
    }
    return true;
  }

  Future<void> _persistState() async {
    if (!await coreStorageDir.exists()) {
      await coreStorageDir.create(recursive: true);
    }
    final data = {
      'coreType': _activeCore.name,
      'version': _activeVersion,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _versionRecordFile.writeAsString(json.encode(data), flush: true);
  }
}
