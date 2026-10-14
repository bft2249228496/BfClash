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
          name.endsWith('-beta-setup.exe') &&
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
