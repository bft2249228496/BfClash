import 'package:bfclash/common/release_tag.dart';
import 'package:bfclash/common/windows_update.dart'
    show WindowsUpdateIdentityException;

// Frozen selector shipped in v1.0.0-beta.1871; keep its behavior for migration tests.
Map<String, dynamic>? selectInstalled1871Release(
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
