import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';

class Request {
  late final Dio dio;
  late final Dio _clashDio;
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
          return FlClashHttpOverrides.findProxyForReader(read, uri);
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
      final isCurrentBeta = isPreReleaseVersion(version);

      if (!isCurrentBeta) {
        // 正式版：只检测官方最新正式发布版本
        final response = await dio.get(
          'https://api.github.com/repos/$repository/releases/latest',
          options: Options(responseType: ResponseType.json),
        );
        if (response.statusCode != 200) return null;
        final data = response.data as Map<String, dynamic>;
        final remoteVersion = data['tag_name'] as String? ?? '';
        final cleanTag = remoteVersion.replaceAll('v', '');
        if (isPreReleaseVersion(cleanTag)) return null;
        final hasUpdate = compareVersions(cleanTag, version) > 0;
        if (!hasUpdate) return null;
        return data;
      }

      // Beta / 预发布版：只检测同为 Beta / 预发布版本的更新
      final response = await dio.get(
        'https://api.github.com/repos/$repository/releases?per_page=10',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode != 200) return null;
      final list =
          (response.data as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];

      Map<String, dynamic>? bestRelease;
      String? bestVersion;

      for (final release in list) {
        if (release['draft'] == true) continue;
        final tagName = release['tag_name'] as String? ?? '';
        if (tagName.isEmpty) continue;
        final cleanTag = tagName.replaceAll('v', '');
        // 严格隔离：Beta 版本只接受同样带有 preRelease/Beta 标识的更新
        final isRemoteBeta =
            (release['prerelease'] == true) || isPreReleaseVersion(cleanTag);
        if (!isRemoteBeta) continue;

        if (compareVersions(cleanTag, version) > 0) {
          if (bestVersion == null ||
              compareVersions(cleanTag, bestVersion) > 0) {
            bestVersion = cleanTag;
            bestRelease = release;
          }
        }
      }

      return bestRelease;
    } catch (e) {
      commonPrint.log('checkForUpdate failed: $e', logLevel: LogLevel.warning);
      return null;
    }
  }

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
