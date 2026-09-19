import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AndroidUpdateAsset {
  final String url;
  final int size;
  final String name;

  const AndroidUpdateAsset({
    required this.url,
    required this.size,
    required this.name,
  });
}

class UpdateDownloadProgress {
  final int received;
  final int total;
  final double speedBytesPerSec;

  const UpdateDownloadProgress({
    required this.received,
    required this.total,
    required this.speedBytesPerSec,
  });

  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  static String formatBytes(num bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(d < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  String get formattedReceived => formatBytes(received);
  String get formattedTotal => formatBytes(total);
  String get formattedSpeed => '${formatBytes(speedBytesPerSec.round())}/s';
}

@visibleForTesting
Map<String, dynamic>? selectAndroidUpdateAssetEntry(
  List<dynamic>? assets,
  List<String> supportedAbis,
) {
  if (assets == null) return null;
  final apkAssets = assets.whereType<Map<String, dynamic>>().where((asset) {
    final name = (asset['name'] as String? ?? '').toLowerCase();
    return name.endsWith('.apk') &&
        (asset['browser_download_url'] as String? ?? '').isNotEmpty;
  }).toList();
  if (apkAssets.isEmpty) return null;

  final abiTokens = <String>[];
  for (final abi in supportedAbis) {
    switch (abi.toLowerCase()) {
      case 'arm64-v8a':
        abiTokens.addAll(['arm64-v8a', 'arm64']);
      case 'armeabi-v7a':
        abiTokens.addAll(['armeabi-v7a', 'armv7']);
      case 'x86_64':
        abiTokens.addAll(['x86_64', 'x64']);
    }
  }
  for (final token in abiTokens) {
    for (final asset in apkAssets) {
      if ((asset['name'] as String).toLowerCase().contains(token)) {
        return asset;
      }
    }
  }
  for (final asset in apkAssets) {
    final name = (asset['name'] as String).toLowerCase();
    if (name.contains('universal') || name.contains('android.apk')) {
      return asset;
    }
  }
  return apkAssets.length == 1 ? apkAssets.single : null;
}

@visibleForTesting
String? selectAndroidUpdateAsset(
  List<dynamic>? assets,
  List<String> supportedAbis,
) {
  final entry = selectAndroidUpdateAssetEntry(assets, supportedAbis);
  return entry?['browser_download_url'] as String?;
}

Future<AndroidUpdateAsset?> androidUpdateAssetInfo(
  Map<String, dynamic> release,
) async {
  if (!Platform.isAndroid) return null;
  final info = await DeviceInfoPlugin().androidInfo;
  final entry = selectAndroidUpdateAssetEntry(
    release['assets'] as List<dynamic>?,
    info.supportedAbis,
  );
  if (entry == null) return null;
  final url = entry['browser_download_url'] as String? ?? '';
  if (url.isEmpty) return null;
  final size = entry['size'] as int? ?? 0;
  final name = entry['name'] as String? ?? '';
  return AndroidUpdateAsset(url: url, size: size, name: name);
}

Future<String?> androidUpdateDownloadUrl(Map<String, dynamic> release) async {
  final asset = await androidUpdateAssetInfo(release);
  return asset?.url;
}

/// Download Android update with intelligent dual-channel mirror fallback and speed tracking.
Future<File> downloadAndroidUpdate(
  Dio dio,
  String rawUrl, {
  void Function(int received, int total)? onProgress,
  void Function(UpdateDownloadProgress progress)? onUpdateProgress,
}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/bfclash_update.apk');
  if (await file.exists()) await file.delete();

  final candidateUrls = [
    rawUrl,
    'https://ghfast.top/$rawUrl',
    'https://mirror.ghproxy.com/$rawUrl',
  ];

  DioException? lastError;

  for (final url in candidateUrls) {
    try {
      if (await file.exists()) await file.delete();

      var lastSampleTime = DateTime.now().millisecondsSinceEpoch;
      var lastReceivedBytes = 0;
      var currentSpeed = 0.0;

      await dio.download(
        url,
        file.path,
        onReceiveProgress: (received, total) {
          onProgress?.call(received, total);

          final now = DateTime.now().millisecondsSinceEpoch;
          final timeDelta = now - lastSampleTime;
          if (timeDelta >= 400 || (received == total && total > 0)) {
            final bytesDelta = received - lastReceivedBytes;
            if (timeDelta > 0) {
              final instantSpeed = (bytesDelta / (timeDelta / 1000.0));
              currentSpeed = currentSpeed == 0.0
                  ? instantSpeed
                  : (currentSpeed * 0.7 + instantSpeed * 0.3);
            }
            lastSampleTime = now;
            lastReceivedBytes = received;
          }

          onUpdateProgress?.call(
            UpdateDownloadProgress(
              received: received,
              total: total,
              speedBytesPerSec: currentSpeed,
            ),
          );
        },
        options: Options(
          followRedirects: true,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 10),
        ),
      );
      if (await file.exists() && await file.length() > 10 * 1024 * 1024) {
        return file;
      }
    } on DioException catch (e) {
      lastError = e;
      continue;
    } catch (_) {
      continue;
    }
  }

  if (await file.exists() && await file.length() > 0) {
    return file;
  }
  if (lastError != null) throw lastError;
  throw Exception('下载更新失败，所有镜像源均不可用');
}
