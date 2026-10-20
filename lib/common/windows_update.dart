import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:bfclash/common/update.dart';
import 'package:bfclash/common/resumable_download.dart';

import 'package:bfclash/common/package.dart';

class WindowsUpdateIdentityException implements Exception {
  const WindowsUpdateIdentityException();

  @override
  String toString() =>
      'Windows beta build identity or architecture is unavailable';
}

Map<String, dynamic>? selectWindowsBetaRelease(
  List<dynamic> releases, {
  required String currentVersion,
  required String currentRunId,
  required String architecture,
}) {
  final currentRun = int.tryParse(currentRunId);
  if (currentRun == null || currentRun <= 0) {
    throw const WindowsUpdateIdentityException();
  }
  final currentBase = currentVersion.split('+').first.split('-').first;
  final arch = switch (architecture.toLowerCase()) {
    'amd64' || 'x64' || 'x86_64' => 'amd64',
    'arm64' || 'aarch64' => 'arm64',
    _ => null,
  };
  if (arch == null) throw const WindowsUpdateIdentityException();
  Map<String, dynamic>? best;
  String? bestBase;
  int? bestRun;
  for (final release in releases.whereType<Map<String, dynamic>>()) {
    if (release['draft'] == true || release['prerelease'] != true) continue;
    final tag = release['tag_name'] as String? ?? '';
    // 新格式 `v1.0.1-beta.1861`；`-windows-ci.N` 仅用于兼容历史 tag。
    final match = RegExp(
      r'^v?(\d+\.\d+\.\d+)-(?:beta|rc|windows-ci)\.(\d+)$',
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
    // 新旧两种 tag 都带预发布段，直接比较原始 tag 会因 stage 名称不同而失序，
    // 因此按 (基础版本, 构建号) 显式比较。
    if (bestBase == null || bestRun == null) {
      best = release;
      bestBase = base;
      bestRun = run;
      continue;
    }
    final better =
        compareVersions(base, bestBase) > 0 ||
        (compareVersions(base, bestBase) == 0 && run > bestRun);
    if (better) {
      best = release;
      bestBase = base;
      bestRun = run;
    }
  }
  return best;
}

class WindowsUpdateAsset {
  final String url;
  final int size;
  final String sha256Digest;

  /// Release asset file name, used to read the packaged version for the
  /// portable (overwrite) updater.
  final String name;

  const WindowsUpdateAsset({
    required this.url,
    required this.size,
    required this.sha256Digest,
    this.name = '',
  });

  /// `0.2.27-beta.1811` from `BfClash-0.2.27-beta.1811-windows-amd64.zip`.
  String get packagedVersion {
    final match = RegExp(
      r'^BfClash-(\d+\.\d+\.\d+(?:-beta\.\d+)?)-windows-',
      caseSensitive: false,
    ).firstMatch(name);
    return match?.group(1) ?? '';
  }
}

enum WindowsUpdateAssetKind {
  /// Inno Setup installer, executed through `runas`.
  installer,

  /// Portable archive, unpacked over the installed files.
  portable,
}

WindowsUpdateAsset? selectWindowsUpdateAsset(
  Map<String, dynamic> release, {
  required bool beta,
  required String architecture,
}) => _selectWindowsAsset(
  release,
  beta: beta,
  architecture: architecture,
  kind: WindowsUpdateAssetKind.installer,
);

WindowsUpdateAsset? selectWindowsPortableUpdateAsset(
  Map<String, dynamic> release, {
  required bool beta,
  required String architecture,
}) => _selectWindowsAsset(
  release,
  beta: beta,
  architecture: architecture,
  kind: WindowsUpdateAssetKind.portable,
);

WindowsUpdateAsset? _selectWindowsAsset(
  Map<String, dynamic> release, {
  required bool beta,
  required String architecture,
  required WindowsUpdateAssetKind kind,
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
  final patterns = switch (kind) {
    WindowsUpdateAssetKind.installer =>
      beta
          ? [
              RegExp(
                '^bfclash-[0-9]+\\.[0-9]+\\.[0-9]+-windows-$arch-beta-setup\\.exe\$',
              ),
              RegExp(
                '^bfclash-[0-9]+\\.[0-9]+\\.[0-9]+-beta\\.[0-9]+-windows-$arch-setup\\.exe\$',
              ),
            ]
          : [
              RegExp(
                '^bfclash-[0-9]+\\.[0-9]+\\.[0-9]+-windows-$arch-setup\\.exe\$',
              ),
            ],
    WindowsUpdateAssetKind.portable =>
      beta
          ? [
              RegExp(
                '^bfclash-[0-9]+\\.[0-9]+\\.[0-9]+-beta\\.[0-9]+-windows-$arch\\.zip\$',
              ),
              RegExp(
                '^bfclash-[0-9]+\\.[0-9]+\\.[0-9]+-windows-$arch-beta\\.zip\$',
              ),
            ]
          : [RegExp('^bfclash-[0-9]+\\.[0-9]+\\.[0-9]+-windows-$arch\\.zip\$')],
  };
  for (final asset in assets.whereType<Map<String, dynamic>>()) {
    final name = (asset['name'] as String? ?? '').toLowerCase();
    if (!patterns.any((pattern) => pattern.hasMatch(name))) continue;
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
      name: asset['name'] as String? ?? '',
    );
  }
  return null;
}

Future<File> downloadWindowsUpdate(
  Dio dio,
  WindowsUpdateAsset asset, {
  void Function(UpdateDownloadProgress progress)? onUpdateProgress,
  Directory? temporaryDirectory,
  CancelToken? cancelToken,
  String fileName = 'BfClash-update-setup.exe',
}) async {
  final identity = sha256.convert(
    utf8.encode('${asset.url}:${asset.sha256Digest}'),
  );
  final directory = Directory(
    '${(temporaryDirectory ?? Directory.systemTemp).path}/bfclash-update-$identity',
  );
  return downloadResumableFile(
    dio,
    url: asset.url,
    directory: directory,
    fileName: fileName,
    expectedSize: asset.size,
    expectedSha256: asset.sha256Digest,
    cancelToken: cancelToken,
    onProgress: (received, total, speed) => onUpdateProgress?.call(
      UpdateDownloadProgress(
        received: received,
        total: total,
        speedBytesPerSec: speed,
      ),
    ),
  );
}
