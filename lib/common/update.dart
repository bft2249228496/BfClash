import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:bfclash/common/package.dart';
import 'package:bfclash/common/resumable_download.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AndroidUpdateAsset {
  final String url;
  final int size;
  final String name;
  final String? sha256Digest;

  const AndroidUpdateAsset({
    required this.url,
    required this.size,
    required this.name,
    this.sha256Digest,
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
    var numStr = d.toStringAsFixed(d < 10 && i > 0 ? 1 : 0);
    if (numStr.endsWith('.0')) {
      numStr = numStr.substring(0, numStr.length - 2);
    }
    return '$numStr ${suffixes[i]}';
  }

  String get formattedReceived => formatBytes(received);
  String get formattedTotal => formatBytes(total);
  String get formattedSpeed => '${formatBytes(speedBytesPerSec.round())}/s';
}

const androidStablePackage = 'com.bfclash.client';
const androidBetaPackage = 'com.bfclash.client.beta';

/// 旧品牌遗留的 Beta 包名，存量用户仍在使用，安装包身份判定需继续接受。
const legacyAndroidBetaPackage = 'com.lansway.client.beta';

bool isAndroidReleaseCompatible(
  Map<String, dynamic> release,
  String packageName,
) {
  final tag = ReleaseTag.tryParse(release['tag_name'] as String?);
  if (tag == null) return false;
  // Android 只吃 0.x 主线，Windows 的 1.x tag 永远不可见。
  if (tag.major != androidReleaseMajor) return false;
  final accepted = tag.isBeta
      ? const {androidBetaPackage, legacyAndroidBetaPackage}
      : const {androidStablePackage};
  if (!accepted.contains(packageName)) return false;
  return _hasAssetWithExtension(release, '.apk');
}

bool isWindowsReleaseCompatible(Map<String, dynamic> release) {
  final tag = ReleaseTag.tryParse(release['tag_name'] as String?);
  if (tag != null && tag.major != windowsReleaseMajor) return false;
  return _hasAssetWithExtension(release, '.exe') ||
      _hasAssetWithExtension(release, '.zip');
}

bool _hasAssetWithExtension(Map<String, dynamic> release, String extension) {
  final assets = release['assets'];
  if (assets is! List) return false;
  return assets.whereType<Map<String, dynamic>>().any(
    (asset) => (asset['name'] as String? ?? '').toLowerCase().endsWith(extension),
  );
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
  final digest = entry['digest'] as String? ?? '';
  return AndroidUpdateAsset(
    url: url,
    size: size,
    name: name,
    sha256Digest: RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest)
        ? digest.substring(7).toLowerCase()
        : null,
  );
}

Future<String?> androidUpdateDownloadUrl(Map<String, dynamic> release) async {
  final asset = await androidUpdateAssetInfo(release);
  return asset?.url;
}

Future<File> downloadAndroidUpdate(
  Dio dio,
  String rawUrl, {
  void Function(int received, int total)? onProgress,
  void Function(UpdateDownloadProgress progress)? onUpdateProgress,
  int expectedSize = 0,
  String? sha256Digest,
  CancelToken? cancelToken,
  Directory? temporaryDirectory,
}) async {
  final root = temporaryDirectory ?? await getTemporaryDirectory();
  final identity = sha256.convert(utf8.encode('$rawUrl:$sha256Digest'));
  final directory = Directory('${root.path}/bfclash-update-$identity');
  final urls = [
    rawUrl,
    if (sha256Digest != null) 'https://ghfast.top/$rawUrl',
    if (sha256Digest != null) 'https://mirror.ghproxy.com/$rawUrl',
  ];
  for (var index = 0; index < urls.length; index++) {
    try {
      return await downloadResumableFile(
        dio,
        url: urls[index],
        directory: directory,
        fileName: 'bfclash_update.apk',
        expectedSize: expectedSize,
        expectedSha256: sha256Digest,
        cancelToken: cancelToken,
        onProgress: (received, total, speed) {
          onProgress?.call(received, total);
          onUpdateProgress?.call(
            UpdateDownloadProgress(
              received: received,
              total: total,
              speedBytesPerSec: speed,
            ),
          );
        },
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || index == urls.length - 1) rethrow;
    }
  }
  throw StateError('No update download source');
}
