import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

@visibleForTesting
String? selectAndroidUpdateAsset(
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
        return asset['browser_download_url'] as String;
      }
    }
  }
  for (final asset in apkAssets) {
    final name = (asset['name'] as String).toLowerCase();
    if (name.contains('universal') || name.contains('android.apk')) {
      return asset['browser_download_url'] as String;
    }
  }
  return apkAssets.length == 1
      ? apkAssets.single['browser_download_url'] as String
      : null;
}

Future<String?> androidUpdateDownloadUrl(Map<String, dynamic> release) async {
  if (!Platform.isAndroid) return null;
  final info = await DeviceInfoPlugin().androidInfo;
  return selectAndroidUpdateAsset(
    release['assets'] as List<dynamic>?,
    info.supportedAbis,
  );
}

Future<File> downloadAndroidUpdate(
  Dio dio,
  String url, {
  void Function(int received, int total)? onProgress,
}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/bfclash_update.apk');
  if (await file.exists()) await file.delete();
  await dio.download(
    url,
    file.path,
    onReceiveProgress: onProgress,
    options: Options(
      followRedirects: true,
      receiveTimeout: const Duration(minutes: 10),
    ),
  );
  return file;
}
