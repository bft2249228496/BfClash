import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:bfclash/common/resumable_download.dart';
import 'package:bfclash/common/update.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';

const payload = [1, 2, 3, 4];

class ResumeAdapter implements HttpClientAdapter {
  bool interrupt = false;
  bool ignoreRange = false;
  bool wrongRange = false;
  CancelToken? pause;
  final offsets = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final range = options.headers[HttpHeaders.rangeHeader] as String?;
    final offset = range == null
        ? 0
        : int.parse(range.substring(6).split('-').first);
    offsets.add(offset);
    final actualOffset = ignoreRange ? 0 : offset;
    final bytes = payload.sublist(actualOffset);
    final fail = interrupt;
    interrupt = false;
    Stream<Uint8List> stream() async* {
      if (fail || pause != null) {
        yield Uint8List.fromList(bytes.take(2).toList());
        if (pause != null) {
          await pause!.whenCancel;
          return;
        }
        throw const SocketException('simulated disconnect');
      }
      yield Uint8List.fromList(bytes);
    }

    return ResponseBody(
      stream(),
      actualOffset > 0 ? 206 : 200,
      headers: {
        Headers.contentLengthHeader: ['${bytes.length}'],
        if (actualOffset > 0)
          HttpHeaders.contentRangeHeader: [
            'bytes ${wrongRange ? 0 : actualOffset}-3/4',
          ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory root;
  late Dio dio;
  late ResumeAdapter adapter;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('bf-resume-test-');
    adapter = ResumeAdapter();
    dio = Dio()..httpClientAdapter = adapter;
  });
  tearDown(() async {
    dio.close(force: true);
    if (await root.exists()) await root.delete(recursive: true);
  });
  Future<File> download({
    CancelToken? token,
    bool withHash = true,
    DownloadSample? onProgress,
  }) => downloadResumableFile(
    dio,
    url: 'https://github.com/example/update.exe',
    directory: root,
    fileName: 'update.exe',
    expectedSize: 4,
    expectedSha256: withHash ? sha256.convert(payload).toString() : null,
    cancelToken: token,
    onProgress: onProgress,
  );

  test(
    'disconnect preserves bytes and a new operation resumes with Range',
    () async {
      adapter.interrupt = true;
      await expectLater(download(), throwsA(anything));
      expect(await File('${root.path}/download.part').readAsBytes(), [1, 2]);
      final file = await download();
      expect(await file.readAsBytes(), payload);
      expect(adapter.offsets, [0, 2]);
    },
  );

  test(
    'server ignoring Range restarts rather than duplicating bytes',
    () async {
      await File('${root.path}/download.part').writeAsBytes([1, 2]);
      adapter.ignoreRange = true;
      expect(await (await download()).readAsBytes(), payload);
      expect(adapter.offsets, [2]);
    },
  );

  test('mismatched content range is rejected and discarded', () async {
    await File('${root.path}/download.part').writeAsBytes([1, 2]);
    adapter.wrongRange = true;
    await expectLater(download(), throwsFormatException);
    expect(await root.exists(), isFalse);
  });

  test('pause closes the partial file and permits a later resume', () async {
    final token = CancelToken();
    adapter.pause = token;
    await expectLater(
      download(
        token: token,
        onProgress: (received, _, _) {
          if (received == 2) token.cancel('paused');
        },
      ),
      throwsA(isA<DioException>()),
    );
    expect(await File('${root.path}/download.part').readAsBytes(), [1, 2]);
    adapter.pause = null;
    expect(await (await download()).readAsBytes(), payload);
    expect(adapter.offsets, [0, 2]);
  });

  test(
    'Android updater pauses and resumes a verified APK without fallback',
    () async {
      final token = CancelToken();
      adapter.pause = token;
      await expectLater(
        downloadAndroidUpdate(
          dio,
          'https://github.com/example/update.apk',
          temporaryDirectory: root,
          expectedSize: 4,
          sha256Digest: sha256.convert(payload).toString(),
          cancelToken: token,
          onUpdateProgress: (progress) {
            if (progress.received == 2) token.cancel('paused');
          },
        ),
        throwsA(isA<DioException>()),
      );
      adapter.pause = null;
      final apk = await downloadAndroidUpdate(
        dio,
        'https://github.com/example/update.apk',
        temporaryDirectory: root,
        expectedSize: 4,
        sha256Digest: sha256.convert(payload).toString(),
      );
      expect(await apk.readAsBytes(), payload);
      expect(adapter.offsets, [0, 2]);
    },
  );

  test(
    'real HTTP cancellation releases the request and resumes saved bytes',
    () async {
      final bytes = List<int>.generate(65536, (index) => index % 251);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final release = Completer<void>();
      final ranges = <String?>[];
      final handler = server.listen((request) async {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        ranges.add(range);
        try {
          if (range == null) {
            request.response.contentLength = bytes.length;
            request.response.add(bytes.sublist(0, 32768));
            await request.response.flush();
            await release.future;
          } else {
            final start = int.parse(range.substring(6).split('-').first);
            request.response.statusCode = 206;
            request.response.headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes $start-65535/65536',
            );
            request.response.contentLength = bytes.length - start;
            request.response.add(bytes.sublist(start));
          }
          await request.response.close();
        } catch (_) {}
      });
      final realDio = Dio();
      final token = CancelToken();
      Future<File> transfer(CancelToken? current) => downloadResumableFile(
        realDio,
        url: 'http://127.0.0.1:${server.port}/update',
        directory: root,
        fileName: 'verified.exe',
        expectedSize: bytes.length,
        expectedSha256: sha256.convert(bytes).toString(),
        cancelToken: current,
        onProgress: (received, _, _) {
          if (current != null && received >= 32768) {
            current.cancel('pause');
            if (!release.isCompleted) release.complete();
          }
        },
      );
      try {
        await expectLater(transfer(token), throwsA(isA<DioException>()));
        final saved = await File('${root.path}/download.part').length();
        expect(saved, 32768);
        expect(await (await transfer(null)).readAsBytes(), bytes);
        expect(ranges, [null, 'bytes=32768-']);
      } finally {
        if (!release.isCompleted) release.complete();
        realDio.close(force: true);
        await handler.cancel();
        await server.close(force: true);
      }
    },
  );

  test(
    'paused transfer uses the new proxy for its next range request',
    () async {
      final bytes = List<int>.generate(65536, (index) => index % 251);
      final first = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final second = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final release = Completer<void>();
      final seen = <(int, String?)>[];
      final subscriptions = <StreamSubscription<HttpRequest>>[];
      for (final server in [first, second]) {
        subscriptions.add(
          server.listen((request) async {
            final range = request.headers.value(HttpHeaders.rangeHeader);
            seen.add((server.port, range));
            try {
              if (server == first) {
                request.response.contentLength = bytes.length;
                request.response.add(bytes.sublist(0, 32768));
                await request.response.flush();
                await release.future;
              } else {
                final start = int.parse(range!.substring(6).split('-').first);
                request.response.statusCode = 206;
                request.response.headers.set(
                  HttpHeaders.contentRangeHeader,
                  'bytes $start-65535/65536',
                );
                request.response.contentLength = bytes.length - start;
                request.response.add(bytes.sublist(start));
              }
              await request.response.close();
            } catch (_) {}
          }),
        );
      }
      var proxyPort = first.port;
      final realDio = Dio()
        ..httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () =>
              HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:$proxyPort',
        );
      final token = CancelToken();
      Future<File> transfer(CancelToken? current) => downloadResumableFile(
        realDio,
        url: 'http://update.example.invalid/update.exe',
        directory: root,
        fileName: 'verified.exe',
        expectedSize: bytes.length,
        expectedSha256: sha256.convert(bytes).toString(),
        cancelToken: current,
        onProgress: (received, _, _) {
          if (current != null && received >= 32768) {
            current.cancel('pause');
            if (!release.isCompleted) release.complete();
          }
        },
      );
      try {
        await expectLater(transfer(token), throwsA(isA<DioException>()));
        expect(await File('${root.path}/download.part').length(), 32768);
        proxyPort = second.port;
        expect(await (await transfer(null)).readAsBytes(), bytes);
        expect(seen, [(first.port, null), (second.port, 'bytes=32768-')]);
      } finally {
        if (!release.isCompleted) release.complete();
        realDio.close(force: true);
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await first.close(force: true);
        await second.close(force: true);
      }
    },
  );

  test('completed cached file must pass hash before it is reused', () async {
    await File('${root.path}/update.exe').writeAsBytes(payload);
    expect(await (await download()).readAsBytes(), payload);
    expect(adapter.offsets, isEmpty);
  });

  test('unverified identity never appends a previous partial file', () async {
    await File('${root.path}/download.part').writeAsBytes([9, 9]);
    expect(await (await download(withHash: false)).readAsBytes(), payload);
    expect(adapter.offsets, [0]);
  });
}
