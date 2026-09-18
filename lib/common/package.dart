import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'common.dart';

extension PackageInfoExtension on PackageInfo {
  String get ua => [
    '$appName/v$version',
    'clash-verge',
    'Platform/${Platform.operatingSystem}',
  ].join(' ');
}

class VersionInfo {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;
  final int? preReleaseNum;
  final int build;

  VersionInfo({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
    this.preReleaseNum,
    required this.build,
  });

  static VersionInfo parse(String raw) {
    var v = raw.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    int build = 0;
    if (v.contains('+')) {
      final parts = v.split('+');
      v = parts[0];
      build = int.tryParse(parts[1]) ?? 0;
    }

    String? preRelease;
    int? preReleaseNum;
    if (v.contains('-')) {
      final parts = v.split('-');
      v = parts[0];
      final pre = parts.sublist(1).join('-');
      preRelease = pre;
      final match = RegExp(r'^(.*?)[.-]?(\\d+)$').firstMatch(pre);
      if (match != null) {
        preRelease = match.group(1);
        preReleaseNum = int.tryParse(match.group(2)!);
      }
    }

    final nums = v.split('.');
    final major = nums.isNotEmpty ? (int.tryParse(nums[0]) ?? 0) : 0;
    final minor = nums.length > 1 ? (int.tryParse(nums[1]) ?? 0) : 0;
    final patch = nums.length > 2 ? (int.tryParse(nums[2]) ?? 0) : 0;

    return VersionInfo(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: preRelease,
      preReleaseNum: preReleaseNum,
      build: build,
    );
  }

  int compareTo(VersionInfo other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    final thisIsPre = preRelease != null;
    final otherIsPre = other.preRelease != null;
    if (thisIsPre && !otherIsPre) return -1;
    if (!thisIsPre && otherIsPre) return 1;
    if (thisIsPre && otherIsPre) {
      if (preRelease != other.preRelease) {
        return (preRelease ?? '').compareTo(other.preRelease ?? '');
      }
      final p1 = preReleaseNum ?? 0;
      final p2 = other.preReleaseNum ?? 0;
      if (p1 != p2) return p1.compareTo(p2);
    }

    return build.compareTo(other.build);
  }
}

int compareVersions(String version1, String version2) {
  return VersionInfo.parse(version1).compareTo(VersionInfo.parse(version2));
}

bool isPreReleaseVersion(String version) {
  return VersionInfo.parse(version).preRelease != null;
}

const releaseNotesBeginMarker = '<!-- flclash:changelog:begin -->';
const releaseNotesEndMarker = '<!-- flclash:changelog:end -->';

List<String> parseReleaseBody(String? body) {
  if (body == null) return [];
  final regex = RegExp(r'^[ \t]*-[ \t]+(.*)$', multiLine: true);
  return regex
      .allMatches(scopeReleaseNotes(body))
      .map((match) => match.group(1)?.trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

String scopeReleaseNotes(String body) {
  final begin = body.indexOf(releaseNotesBeginMarker);
  if (begin < 0) return body;
  final start = begin + releaseNotesBeginMarker.length;
  final end = body.indexOf(releaseNotesEndMarker, start);
  return end < 0 ? body.substring(start) : body.substring(start, end);
}
