import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/channel_config.dart';
import 'package:bfclash/common/windows_update.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/state.dart';

class Request {
  late final Dio dio;
  late final Dio _clashDio;
  Dio get clashDio => _clashDio;
  String? userAgent;

  ProviderReader? _read;

  void attach(ProviderReader read) {
    _read = read;
  }

  Request() {
    dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    _clashDio = Dio();
    _clashDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (Uri uri) {
          client.userAgent = globalState.ua;
          final read = _read;
          if (read == null) {
            return 'DIRECT';
          }
          return BfClashHttpOverrides.findProxyForReader(read, uri);
        };
        return client;
      },
    );
  }

  Future<Response<Uint8List>> getFileResponseForUrl(String url) async {
    try {
      return await _clashDio.get<Uint8List>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
    } catch (e) {
      commonPrint.log(
        'getFileResponseForUrl error ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      rethrow;
    }
  }

  Future<Response<String>> getTextResponseForUrl(String url) async {
    try {
      return await _clashDio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
    } catch (e) {
      commonPrint.log(
        'getTextResponseForUrl error ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final version = globalState.packageInfo.version;
      final androidPackage = system.isAndroid
          ? globalState.packageInfo.packageName
          : null;
      final isCurrentBeta =
          (system.isWindows && WindowsChannelConfig.isBeta) ||
          isPreReleaseVersion(version);

      final list = await _fetchReleases();

      if (system.isWindows && WindowsChannelConfig.isBeta) {
        return selectWindowsBetaRelease(
          list,
          currentVersion: version,
          currentRunId: WindowsChannelConfig.ciRunId,
          architecture: Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '',
        );
      }

      return _selectRelease(
        list,
        version: version,
        beta: isCurrentBeta,
        androidPackage: androidPackage,
      );
    } on WindowsUpdateIdentityException {
      throw MessageException(
        currentAppLocalizations.windowsUpdateIdentityUnknown,
      );
    } catch (e) {
      commonPrint.log('checkForUpdate failed: $e', logLevel: LogLevel.warning);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReleases() async {
    final response = await _clashDio.get(
      'https://api.github.com/repos/$repository/releases?per_page=100',
      options: _updateRequestOptions,
    );
    if (response.statusCode != 200) {
      throw HttpException('Update check returned HTTP ${response.statusCode}');
    }
    return (response.data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// 通道严格隔离：正式版只认无 stage 后缀的 tag，测试版只认 `-beta.N` / `-rc.N`。
  /// 平台由 tag 主线号段 + 资产类型双重判定，不再依赖 tag 字符串包含关系。
  Map<String, dynamic>? _selectRelease(
    List<Map<String, dynamic>> releases, {
    required String version,
    required bool beta,
    required String? androidPackage,
  }) {
    final channel = beta ? ReleaseChannel.beta : ReleaseChannel.stable;
    Map<String, dynamic>? best;
    String? bestVersion;
    for (final release in releases) {
      if (release['draft'] == true) continue;
      if ((release['prerelease'] == true) != beta) continue;
      final tag = ReleaseTag.tryParse(release['tag_name'] as String?);
      if (tag == null) continue;
      if (tag.channel != channel) continue;
      if (!_platformAccepts(tag, release, androidPackage)) continue;
      if (compareVersions(tag.version, version) <= 0) continue;
      if (bestVersion == null ||
          compareVersions(tag.version, bestVersion) > 0) {
        bestVersion = tag.version;
        best = release;
      }
    }
    return best;
  }

  bool _platformAccepts(
    ReleaseTag tag,
    Map<String, dynamic> release,
    String? androidPackage,
  ) {
    if (androidPackage != null) {
      return isAndroidReleaseCompatible(release, androidPackage);
    }
    if (system.isWindows) {
      return tag.major == windowsReleaseMajor &&
          isWindowsReleaseCompatible(release);
    }
    // 其他平台沿用“取最高版本”的宽松策略。
    return true;
  }

  Options get _updateRequestOptions => Options(
    responseType: ResponseType.json,
    sendTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  );

  final Map<String, IpInfo Function(Map<String, dynamic>)> _ipInfoSources = {
    'https://ipwho.is': IpInfo.fromIpWhoIsJson,
    'https://api.myip.com': IpInfo.fromMyIpJson,
    'https://ipapi.co/json': IpInfo.fromIpApiCoJson,
    'https://ident.me/json': IpInfo.fromIdentMeJson,
    'http://ip-api.com/json': IpInfo.fromIpAPIJson,
    'https://api.ip.sb/geoip': IpInfo.fromIpSbJson,
    'https://ipinfo.io/json': IpInfo.fromIpInfoIoJson,
  };

  Future<Result<IpInfo?>> checkIp({CancelToken? cancelToken}) async {
    var failureCount = 0;
    final token = cancelToken ?? CancelToken();
    final futures = _ipInfoSources.entries.map((source) async {
      final Completer<Result<IpInfo?>> completer = Completer();
      void handleFailRes() {
        if (!completer.isCompleted && failureCount == _ipInfoSources.length) {
          completer.complete(Result.success(null));
        }
      }

      final future = dio
          .get<Map<String, dynamic>>(
            source.key,
            cancelToken: token,
            options: Options(responseType: ResponseType.json),
          )
          .timeout(const Duration(seconds: 10));
      unawaited(
        future
            .then((res) {
              if (res.statusCode == HttpStatus.ok && res.data != null) {
                completer.complete(Result.success(source.value(res.data!)));
                return;
              }
              commonPrint.log('checkIp data empty', logLevel: LogLevel.info);
              failureCount++;
              handleFailRes();
            })
            .catchError((e) {
              failureCount++;
              if (e is DioException && e.type == DioExceptionType.cancel) {
                completer.complete(Result.error('cancelled'));
                return;
              }
              commonPrint.log('checkIp error $e', logLevel: LogLevel.warning);
              handleFailRes();
            }),
      );
      return completer.future;
    });
    final res = await Future.any(futures);
    token.cancel();
    return res;
  }
}

final request = Request();

String? getFileNameForDisposition(String? disposition) {
  if (disposition == null) return null;
  final parseValue = HeaderValue.parse(disposition);
  final parameters = parseValue.parameters;
  final fileNamePointKey = parameters.keys.firstWhere(
    (key) => key == 'filename*',
    orElse: () => '',
  );
  if (fileNamePointKey.isNotEmpty) {
    final res = parameters[fileNamePointKey]?.split("''") ?? [];
    if (res.length >= 2) {
      return Uri.decodeComponent(res[1]);
    }
  }
  final fileNameKey = parameters.keys.firstWhere(
    (key) => key == 'filename',
    orElse: () => '',
  );
  if (fileNameKey.isEmpty) return null;
  return parameters[fileNameKey];
}

/// Derives a useful profile label from a subscription URL when the server does
/// not provide a Content-Disposition filename.
String? getProfileNameForUrl(String? value) {
  final source = value?.trim() ?? '';
  if (source.isEmpty) return null;
  try {
    final uri = Uri.parse(source);
    if (!uri.hasScheme || uri.host.isEmpty) return null;
    const nameKeys = {'name', 'filename', 'title', 'tag'};
    for (final entry in uri.queryParameters.entries) {
      if (!nameKeys.contains(entry.key.toLowerCase())) continue;
      final candidate = entry.value.trim();
      if (candidate.isNotEmpty) return candidate;
    }

    final segments = uri.pathSegments
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isNotEmpty) {
      var candidate = segments.last;
      const extensions = ['.yaml', '.yml', '.txt', '.json', '.conf'];
      final lowerCandidate = candidate.toLowerCase();
      for (final extension in extensions) {
        if (lowerCandidate.endsWith(extension)) {
          candidate = candidate.substring(
            0,
            candidate.length - extension.length,
          );
          break;
        }
      }
      const genericSegments = {
        'raw',
        'get',
        'sub',
        'subscribe',
        'link',
        'config',
      };
      if (candidate.isNotEmpty &&
          !genericSegments.contains(candidate.toLowerCase())) {
        return candidate;
      }
    }

    if (uri.host.isNotEmpty) return uri.host;
  } on FormatException {
    return null;
  }
  return null;
}
