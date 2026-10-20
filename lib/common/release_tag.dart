/// 版本号解析与发布 tag 规范。纯 Dart 实现，不依赖 Flutter，
/// 便于 `dart run tool/verify_release_tag.dart` 在 CI 里复用同一套规则。
///
/// 规范见 docs/release-versioning.md。
library;

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
      final preParts = pre.split('.');
      final last = preParts.last;
      final parsedLast = int.tryParse(last);
      if (parsedLast != null) {
        preReleaseNum = parsedLast;
        preRelease = preParts.length > 1
            ? preParts.sublist(0, preParts.length - 1).join('.')
            : '';
      } else {
        preRelease = pre;
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

/// Release channel encoded in the tag itself: `-beta.N` / `-rc.N` is a test
/// build, a bare `vX.Y.Z` is a stable build.
enum ReleaseChannel { stable, beta }

/// Android 产品线占 0.x，Windows 占 1.x，两条线永不交叉，避免 tag 撞号。
const androidReleaseMajor = 0;
const windowsReleaseMajor = 1;

/// Canonical release tag: `v<MAJOR>.<MINOR>.<PATCH>[-<stage>.<n>]`.
///
/// [stage] only accepts `beta` and `rc`. Ad-hoc names such as
/// `-windows-ci.39391134050`, `-pre.4` or `-new` are rejected on purpose —
/// keeping the tag space machine-checkable instead of relying on
/// `tag.contains('beta')` heuristics.
class ReleaseTag {
  final String raw;
  final String version;
  final VersionInfo info;

  const ReleaseTag._(this.raw, this.version, this.info);

  static final RegExp pattern = RegExp(
    r'^[vV](\d+\.\d+\.\d+(?:-(?:beta|rc)\.\d+)?)$',
  );

  static ReleaseTag? tryParse(String? rawTag) {
    final raw = (rawTag ?? '').trim();
    final match = pattern.firstMatch(raw);
    if (match == null) return null;
    final version = match.group(1)!;
    return ReleaseTag._(raw, version, VersionInfo.parse(version));
  }

  int get major => info.major;

  ReleaseChannel get channel =>
      info.preRelease == null ? ReleaseChannel.stable : ReleaseChannel.beta;

  bool get isBeta => channel == ReleaseChannel.beta;
}
