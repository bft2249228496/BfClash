// 发布前校验 tag 是否符合 docs/release-versioning.md。
//
//   dart run tool/verify_release_tag.dart --tag v0.3.0 --platform android
//
// 校验项：
//   1. tag 形状 / 预发布段是否合规（自造后缀一律拒绝）
//   2. 产品线与 tag 主线号段是否一致（Android=0.x，Windows=1.x）
//   3. pubspec.yaml 的 version 去掉 `+build` 是否与 tag 逐字符相等
// 退出码非 0 时 CI 应当直接失败。
import 'dart:io';

import 'package:bfclash/common/release_tag.dart';

void main(List<String> args) {
  String? tag;
  String? platform;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--tag':
        tag = args[++i];
      case '--platform':
        platform = args[++i];
      case '--help':
        _usage();
        exit(0);
    }
  }

  if (tag == null || tag.isEmpty) {
    _usage();
    exit(2);
  }

  final errors = <String>[];
  final parsed = ReleaseTag.tryParse(tag);
  if (parsed == null) {
    errors.add(
      'tag "$tag" 不符合 v<MAJOR>.<MINOR>.<PATCH>[-beta.N|-rc.N]；'
      '不得包含产品名、run id、日期或 ci/pre 等自造后缀',
    );
  }

  final pubspecVersion = _readPubspecVersion();
  if (pubspecVersion == null) {
    errors.add('无法从 pubspec.yaml 读取 version');
  }

  if (parsed != null) {
    if (platform != null) {
      final expectedMajor = switch (platform) {
        'android' => androidReleaseMajor,
        'windows' => windowsReleaseMajor,
        _ => null,
      };
      if (expectedMajor == null) {
        errors.add('未知平台 "$platform"，只支持 android / windows');
      } else if (parsed.major != expectedMajor) {
        errors.add(
          '$platform 产品线必须使用 $expectedMajor.x 号段，实际为 ${parsed.major}.x',
        );
      }
    }

    if (pubspecVersion != null) {
      final base = pubspecVersion.split('+').first.trim();
      if (base != parsed.version) {
        errors.add('pubspec.yaml version "$base" 与 tag "$tag" 不一致');
      }
      if (!pubspecVersion.contains('+')) {
        errors.add('pubspec.yaml version 必须带 +build 号，例如 ${parsed.version}+64');
      }
    }
  }

  if (errors.isNotEmpty) {
    stderr.writeln('tag 校验失败：');
    for (final error in errors) {
      stderr.writeln('  - $error');
    }
    exit(1);
  }

  final channel = parsed!.isBeta ? 'Beta' : '正式';
  final platformLabel = switch (parsed.major) {
    androidReleaseMajor => 'Android',
    windowsReleaseMajor => 'Windows',
    _ => 'Unknown',
  };
  final packageOrAppId = parsed.major == androidReleaseMajor
      ? (parsed.isBeta ? 'com.bfclash.client.beta' : 'com.bfclash.client')
      : (parsed.isBeta ? 'A19F870C-…' : '728B3532-…');

  stdout.writeln('tag 校验通过');
  stdout.writeln('  tag          : $tag');
  stdout.writeln('  版本         : ${parsed.version}');
  stdout.writeln('  平台 / 通道  : $platformLabel / $channel');
  stdout.writeln('  prerelease   : ${parsed.isBeta}');
  stdout.writeln('  通道身份     : $packageOrAppId');
  stdout.writeln(
    '  Release 标题 : BfClash $platformLabel'
    '${parsed.isBeta ? ' Beta' : ''} ${parsed.version}',
  );
  stdout.writeln(
    '  资产名前缀   : BfClash-${parsed.version}-'
    '${platformLabel.toLowerCase()}-',
  );
}

String? _readPubspecVersion() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) return null;
  for (final line in file.readAsLinesSync()) {
    final match = RegExp(r'^version:\s*(\S+)\s*$').firstMatch(line);
    if (match != null) return match.group(1);
  }
  return null;
}

void _usage() {
  stdout.writeln(
    'usage: dart run tool/verify_release_tag.dart '
    '--tag v<MAJOR>.<MINOR>.<PATCH>[-beta.N|-rc.N] [--platform android|windows]',
  );
}
