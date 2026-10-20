import 'dart:io';

import 'package:bfclash/common/resumable_download.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

Future<void> main(List<String> args) async {
  final dio = Dio()
    ..httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
    );
  try {
    await downloadResumableFile(
      dio,
      url: args[0],
      directory: Directory(args[1]),
      fileName: 'update.bin',
      expectedSize: int.parse(args[2]),
      expectedSha256: args[3],
    );
  } finally {
    dio.close(force: true);
  }
}
