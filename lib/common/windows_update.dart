import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:bfclash/common/update.dart';

import 'package:bfclash/common/package.dart';

Map<String, dynamic>? selectWindowsBetaRelease(
  List<dynamic> releases, {
  required String currentVersion,
  required String currentRunId,
  required String architecture,
}) {
  final currentRun = int.tryParse(currentRunId);
  if (currentRun == null) return null;
  final currentBase = currentVersion.split('+').first.split('-').first;
  final arch = switch (architecture.toLowerCase()) {
    'amd64' || 'x64' || 'x86_64' => 'amd64',
    'arm64' || 'aarch64' => 'arm64',
    _ => null,
  };
  if (arch == null) return null;
  Map<String, dynamic>? best;
  String? bestTag;
  for (final release in releases.whereType<Map<String, dynamic>>()) {
    if (release['draft'] == true || release['prerelease'] != true) continue;
    final tag = release['tag_name'] as String? ?? '';
    final match = RegExp(
      r'^v?(\d+\.\d+\.\d+)-windows-ci\.(\d+)$',
    ).firstMatch(tag);
    if (match == null) continue;
    final base = match.group(1)!;
    final run = int.tryParse(match.group(2)!);
    if (run == null) continue;
    final comparison = compareVersions(base, currentBase);
    if (comparison < 0 || (comparison == 0 && run <= currentRun)) continue;
    final assets = release['assets'];
    if (assets is! List) continue;
    final hasInstaller = assets.whereType<Map<String, dynamic>>().any((asset) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      final url = asset['browser_download_url'] as String? ?? '';
      return name.startsWith('bfclash-') &&
          name.contains('-windows-$arch-') &&
          (name.endsWith('-beta-setup.exe') ||
              RegExp(
                r'^bfclash-\d+\.\d+\.\d+-beta\.\d+-windows-[a-z0-9]+-setup\.exe$',
              ).hasMatch(name)) &&
          Uri.tryParse(url)?.scheme == 'https';
    });
    if (!hasInstaller) continue;
    if (bestTag == null || compareVersions(tag, bestTag) > 0) {
      best = release;
      bestTag = tag;
    }
  }
  return best;
}

class WindowsUpdateAsset {
  final String url;
  final int size;
  final String sha256Digest;

  const WindowsUpdateAsset({
    required this.url,
    required this.size,
    required this.sha256Digest,
  });
}

WindowsUpdateAsset? selectWindowsUpdateAsset(
  Map<String, dynamic> release, {
  required bool beta,
  required String architecture,
}) {
  if (release['draft'] == true || (release['prerelease'] == true) != beta) {
    return null;
  }
  final arch = switch (architecture.toLowerCase()) {
    'amd64' || 'x64' || 'x86_64' => 'amd64',
    'arm64' || 'aarch64' => 'arm64',
    _ => null,
  };
  if (arch == null) return null;
  final assets = release['assets'];
  if (assets is! List) return null;
  for (final asset in assets.whereType<Map<String, dynamic>>()) {
    final name = (asset['name'] as String? ?? '').toLowerCase();
    final pattern = beta
        ? '^bfclash-[0-9]+\\.[0-9]+\\.[0-9]+-windows-$arch-beta-setup\\.exe\$'
        : '^bfclash-[0-9]+\\.[0-9]+\\.[0-9]+-windows-$arch-setup\\.exe\$';
    final versionedBeta =
        beta &&
        RegExp(
          '^bfclash-[0-9]+\\.[0-9]+\\.[0-9]+-beta\\.[0-9]+-windows-$arch-setup\\.exe\$',
        ).hasMatch(name);
    if (!RegExp(pattern).hasMatch(name) && !versionedBeta) continue;
    final url = asset['browser_download_url'] as String? ?? '';
    final uri = Uri.tryParse(url);
    final digest = asset['digest'] as String? ?? '';
    final size = asset['size'];
    if (uri?.scheme != 'https' ||
        uri?.host != 'github.com' ||
        size is! int ||
        size <= 0 ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest)) {
      continue;
    }
    return WindowsUpdateAsset(
      url: url,
      size: size,
      sha256Digest: digest.substring(7).toLowerCase(),
    );
  }
  return null;
}

Future<File> downloadWindowsUpdate(
  Dio dio,
  WindowsUpdateAsset asset, {
  void Function(UpdateDownloadProgress progress)? onUpdateProgress,
  Directory? temporaryDirectory,
}) async {
  final directory = await (temporaryDirectory ?? Directory.systemTemp)
      .createTemp('bfclash-update-');
  final partial = File('${directory.path}/installer.part');
  final watch = Stopwatch()..start();
  try {
    await dio.download(
      asset.url,
      partial.path,
      options: Options(
        followRedirects: true,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 10),
      ),
      onReceiveProgress: (received, total) => onUpdateProgress?.call(
        UpdateDownloadProgress(
          received: received,
          total: asset.size,
          speedBytesPerSec: watch.elapsedMilliseconds > 0
              ? received * 1000 / watch.elapsedMilliseconds
              : 0,
        ),
      ),
    );
    if (await partial.length() != asset.size) {
      throw const FormatException('Update size mismatch');
    }
    final digest = await sha256.bind(partial.openRead()).first;
    if (digest.toString() != asset.sha256Digest) {
      throw const FormatException('Update checksum mismatch');
    }
    return await partial.rename('${directory.path}/BfClash-update-setup.exe');
  } catch (_) {
    if (await directory.exists()) await directory.delete(recursive: true);
    rethrow;
  }
}
