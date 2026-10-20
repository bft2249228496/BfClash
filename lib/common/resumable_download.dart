import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

typedef DownloadSample = void Function(int received, int total, double speed);

Future<File> downloadResumableFile(
  Dio dio, {
  required String url,
  required Directory directory,
  required String fileName,
  required int expectedSize,
  String? expectedSha256,
  CancelToken? cancelToken,
  DownloadSample? onProgress,
}) async {
  await directory.create(recursive: true);
  final partial = File('${directory.path}/download.part');
  final completed = File('${directory.path}/$fileName');
  final verifiedResume = expectedSha256 != null;
  final watch = Stopwatch()..start();
  var sampleTime = 0;
  var sampleBytes = 0;
  var speed = 0.0;
  void emit(int received, int total, {bool force = false}) {
    final elapsed = watch.elapsedMilliseconds;
    if (!force && elapsed - sampleTime < 250) return;
    final interval = elapsed - sampleTime;
    if (interval > 0) speed = (received - sampleBytes) * 1000 / interval;
    sampleTime = elapsed;
    sampleBytes = received;
    onProgress?.call(received, total, speed);
  }

  Future<bool> valid(File file) async {
    if (!await file.exists()) return false;
    if (expectedSize > 0 && await file.length() != expectedSize) return false;
    if (await file.length() == 0) return false;
    if (expectedSha256 != null) {
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString() == expectedSha256.toLowerCase();
    }
    return true;
  }

  try {
    if (verifiedResume && await valid(completed)) {
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      emit(await completed.length(), expectedSize, force: true);
      return completed;
    }
    if (await completed.exists()) await completed.delete();
    var offset = verifiedResume && await partial.exists()
        ? await partial.length()
        : 0;
    if (expectedSize > 0 && offset > expectedSize) offset = 0;
    if (expectedSize > 0 && offset == expectedSize && await valid(partial)) {
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      emit(offset, expectedSize, force: true);
      return await partial.rename(completed.path);
    }
    if (expectedSize > 0 && offset == expectedSize) offset = 0;
    sampleBytes = offset;
    emit(offset, expectedSize, force: true);
    final response = await dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          HttpHeaders.acceptEncodingHeader: 'identity',
          if (offset > 0) HttpHeaders.rangeHeader: 'bytes=$offset-',
        },
        followRedirects: true,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 10),
        validateStatus: (status) => status == 200 || status == 206,
      ),
    );
    final body = response.data!;
    var total = expectedSize;
    var consumed = false;
    try {
      if (response.statusCode == 206) {
        final range = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(
          response.headers.value(HttpHeaders.contentRangeHeader) ?? '',
        );
        if (range == null ||
            int.parse(range[1]!) != offset ||
            int.parse(range[2]!) < offset ||
            int.parse(range[2]!) >= int.parse(range[3]!) ||
            (expectedSize > 0 && int.parse(range[3]!) != expectedSize)) {
          throw const FormatException('Invalid update content range');
        }
        total = int.parse(range[3]!);
      } else {
        offset = 0;
        final length = int.tryParse(
          response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
        );
        if (expectedSize > 0 && length != null && length != expectedSize) {
          throw const FormatException('Update size mismatch');
        }
        if (total <= 0) total = length ?? 0;
      }
      sampleBytes = offset;
      sampleTime = watch.elapsedMilliseconds;
      emit(offset, total, force: true);
      final sink = partial.openWrite(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      var received = offset;
      var firstChunk = true;
      try {
        consumed = true;
        await for (final chunk in body.stream) {
          if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
          received += chunk.length;
          if (total > 0 && received > total) {
            throw const FormatException('Update exceeds expected size');
          }
          sink.add(chunk);
          emit(received, total, force: firstChunk);
          firstChunk = false;
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      if (total > 0 && received != total) {
        throw const HttpException('Incomplete update download');
      }
      if (!await valid(partial)) {
        throw const FormatException('Update integrity check failed');
      }
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      emit(received, total, force: true);
      return await partial.rename(completed.path);
    } finally {
      if (!consumed) await body.stream.listen(null).cancel();
    }
  } on FormatException {
    if (await directory.exists()) await directory.delete(recursive: true);
    rethrow;
  } catch (_) {
    // Only a cryptographically identified asset can safely reuse partial bytes.
    if (!verifiedResume && await directory.exists()) {
      await directory.delete(recursive: true);
    }
    rethrow;
  }
}
