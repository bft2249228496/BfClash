import 'dart:convert';
import 'dart:io';

class SubscriptionInfo {
  final String id;
  final String name;
  final String url;
  final DateTime? lastUpdated;
  final int uploadBytes;
  final int downloadBytes;
  final int totalBytes;
  final DateTime? expireDate;
  final bool autoUpdate;
  final int updateIntervalHours;

  const SubscriptionInfo({
    required this.id,
    required this.name,
    required this.url,
    this.lastUpdated,
    this.uploadBytes = 0,
    this.downloadBytes = 0,
    this.totalBytes = 0,
    this.expireDate,
    this.autoUpdate = true,
    this.updateIntervalHours = 24,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'lastUpdated': lastUpdated?.toIso8601String(),
    'uploadBytes': uploadBytes,
    'downloadBytes': downloadBytes,
    'totalBytes': totalBytes,
    'expireDate': expireDate?.toIso8601String(),
    'autoUpdate': autoUpdate,
    'updateIntervalHours': updateIntervalHours,
  };

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) =>
      SubscriptionInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.tryParse(json['lastUpdated'] as String)
            : null,
        uploadBytes: (json['uploadBytes'] as num?)?.toInt() ?? 0,
        downloadBytes: (json['downloadBytes'] as num?)?.toInt() ?? 0,
        totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
        expireDate: json['expireDate'] != null
            ? DateTime.tryParse(json['expireDate'] as String)
            : null,
        autoUpdate: json['autoUpdate'] as bool? ?? true,
        updateIntervalHours:
            (json['updateIntervalHours'] as num?)?.toInt() ?? 24,
      );

  String get formattedTraffic {
    if (totalBytes <= 0) return '不限流量';
    final used = uploadBytes + downloadBytes;
    final usedGb = (used / (1024 * 1024 * 1024)).toStringAsFixed(1);
    final totalGb = (totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
    return '$usedGb GB / $totalGb GB';
  }
}

class SubscriptionManager {
  final Directory storageDir;
  final List<SubscriptionInfo> _subscriptions = [];

  SubscriptionManager({required this.storageDir});

  List<SubscriptionInfo> get subscriptions => List.unmodifiable(_subscriptions);

  File get _indexFile => File('${storageDir.path}/subscriptions.json');

  Future<void> load() async {
    _subscriptions.clear();
    if (await _indexFile.exists()) {
      try {
        final raw = await _indexFile.readAsString();
        final list = json.decode(raw);
        if (list is List) {
          for (var item in list) {
            if (item is Map<String, dynamic>) {
              _subscriptions.add(SubscriptionInfo.fromJson(item));
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void> save() async {
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }
    final encoded = json.encode(_subscriptions.map((s) => s.toJson()).toList());
    await _indexFile.writeAsString(encoded, flush: true);
  }

  Future<SubscriptionInfo> addSubscription({
    required String name,
    required String url,
  }) async {
    final trimmedUrl = url.trim();
    if (!trimmedUrl.startsWith('http://') &&
        !trimmedUrl.startsWith('https://')) {
      throw ArgumentError('仅支持 HTTP/HTTPS 订阅链接');
    }

    final id = 'sub_${DateTime.now().millisecondsSinceEpoch}';
    final sub = SubscriptionInfo(
      id: id,
      name: name.trim().isEmpty ? '我的订阅' : name.trim(),
      url: trimmedUrl,
      lastUpdated: DateTime.now(),
    );
    _subscriptions.add(sub);
    await save();
    return sub;
  }

  Future<bool> removeSubscription(String id) async {
    final initialLen = _subscriptions.length;
    _subscriptions.removeWhere((s) => s.id == id);
    final removed = _subscriptions.length < initialLen;
    if (removed) {
      await save();
      final contentFile = File('${storageDir.path}/sub_$id.yaml');
      if (await contentFile.exists()) {
        await contentFile.delete();
      }
    }
    return removed;
  }

  static Map<String, int> parseSubscriptionUserInfoHeader(String? header) {
    if (header == null || header.isEmpty) return {};
    final result = <String, int>{};
    final parts = header.split(';');
    for (var part in parts) {
      final kv = part.trim().split('=');
      if (kv.length == 2) {
        final key = kv[0].trim();
        final val = int.tryParse(kv[1].trim());
        if (val != null) {
          result[key] = val;
        }
      }
    }
    return result;
  }
}
