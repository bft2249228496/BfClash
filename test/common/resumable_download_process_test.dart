import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('a killed downloader resumes verified bytes in a new process', () async {
    final root = await Directory.systemTemp.createTemp('bf-process-resume-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final processes = <Process>[];
    final releaseFirst = Completer<void>();
    addTearDown(() async {
      if (!releaseFirst.isCompleted) releaseFirst.complete();
      for (final process in processes) {
        process.kill();
        await process.exitCode;
      }
      await server.close(force: true);
      await root.delete(recursive: true);
    });
    final bytes = List<int>.generate(65536, (index) => index % 251);
    final digest = sha256.convert(bytes).toString();
    final offsets = <int>[];
    server.listen((request) async {
      final range = request.headers.value(HttpHeaders.rangeHeader);
      final offset = range == null
          ? 0
          : int.parse(range.substring(6).split('-').first);
      offsets.add(offset);
      final response = request.response;
      response.contentLength = bytes.length - offset;
      if (offset > 0) {
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $offset-${bytes.length - 1}/${bytes.length}',
        );
      }
      try {
        if (offsets.length == 1) {
          response.add(bytes.sublist(0, 32768));
          await response.flush();
          await releaseFirst.future;
        } else {
          response.add(bytes.sublist(offset));
        }
        await response.close();
      } on IOException {
        // Killing the first client deliberately interrupts its response.
      }
    });
    final flutterRoot =
        Platform.environment['FLUTTER_ROOT'] ??
        p.dirname(
          p.dirname(
            p.dirname(
              p.dirname(p.dirname(p.dirname(Platform.resolvedExecutable))),
            ),
          ),
        );
    final dart = p.join(
      flutterRoot,
      'bin',
      'cache',
      'dart-sdk',
      'bin',
      Platform.isWindows ? 'dart.exe' : 'dart',
    );
    expect(
      File(dart).existsSync(),
      isTrue,
      reason: 'Use the Flutter SDK Dart runtime',
    );
    Future<(Process, Future<String>)> startWorker() async {
      final process = await Process.start(dart, [
        '--packages=${p.absolute('.dart_tool/package_config.json')}',
        p.absolute('test/fixtures/resumable_download_worker.dart'),
        'http://127.0.0.1:${server.port}/owned-update',
        root.path,
        '${bytes.length}',
        digest,
      ]);
      processes.add(process);
      unawaited(process.stdout.drain<void>());
      final error = process.stderr.transform(utf8.decoder).join();
      return (process, error);
    }

    final (first, firstError) = await startWorker();
    final partial = File(p.join(root.path, 'download.part'));
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while ((!await partial.exists() || await partial.length() < 16384) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(await partial.exists(), isTrue);
    expect(await partial.length(), inInclusiveRange(16384, 32768));
    expect(first.kill(), isTrue);
    await first.exitCode.timeout(const Duration(seconds: 10));
    await firstError;
    final persisted = await partial.length();
    expect(File(p.join(root.path, 'update.bin')).existsSync(), isFalse);
    releaseFirst.complete();
    final (second, secondError) = await startWorker();
    expect(
      await second.exitCode.timeout(const Duration(seconds: 20)),
      0,
      reason: await secondError,
    );
    expect(offsets, [0, persisted]);
    final completed = File(p.join(root.path, 'update.bin'));
    expect(await completed.length(), bytes.length);
    expect(sha256.convert(await completed.readAsBytes()).toString(), digest);
    expect(await partial.exists(), isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
