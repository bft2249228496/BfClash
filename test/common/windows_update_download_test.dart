import 'dart:io';
import 'dart:typed_data';

import 'package:bfclash/common/windows_update.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class BytesAdapter implements HttpClientAdapter {
  final List<int> bytes;
  BytesAdapter(this.bytes);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    bytes,
    200,
    headers: {
      Headers.contentLengthHeader: [bytes.length.toString()],
    },
  );
  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> release({
  bool beta = true,
  String arch = 'amd64',
  String? digest,
}) => {
  'prerelease': beta,
  'draft': false,
  'assets': [
    {
      'name': 'BfClash-0.2.27-windows-$arch${beta ? '-beta' : ''}-setup.exe',
      'browser_download_url':
          'https://github.com/example/releases/download/v1/setup.exe',
      'size': 4,
      'digest': digest ?? 'sha256:${sha256.convert([1, 2, 3, 4])}',
    },
  ],
};

void main() {
  test('selects installer only for the running channel and architecture', () {
    expect(
      selectWindowsUpdateAsset(release(), beta: true, architecture: 'AMD64'),
      isNotNull,
    );
    expect(
      selectWindowsUpdateAsset(release(), beta: false, architecture: 'AMD64'),
      isNull,
    );
    expect(
      selectWindowsUpdateAsset(release(), beta: true, architecture: 'ARM64'),
      isNull,
    );
    expect(
      selectWindowsUpdateAsset(
        release(beta: false),
        beta: false,
        architecture: 'x64',
      ),
      isNotNull,
    );
  });
  test('accepts the numbered Windows beta package name', () {
    final data = release();
    (data['assets'] as List).first['name'] =
        'BfClash-0.2.27-beta.1281-windows-amd64-setup.exe';
    expect(
      selectWindowsUpdateAsset(data, beta: true, architecture: 'AMD64'),
      isNotNull,
    );
    expect(
      selectWindowsUpdateAsset(data, beta: false, architecture: 'AMD64'),
      isNull,
    );
  });

  test('rejects installer without a verifiable digest', () {
    expect(
      selectWindowsUpdateAsset(
        release(digest: ''),
        beta: true,
        architecture: 'AMD64',
      ),
      isNull,
    );
  });
  for (final failure in ['none', 'size', 'digest']) {
    test(
      'download validates integrity and cleans failures: $failure',
      () async {
        final root = await Directory.systemTemp.createTemp('update-test-');
        addTearDown(() => root.delete(recursive: true));
        final dio = Dio()..httpClientAdapter = BytesAdapter([1, 2, 3, 4]);
        addTearDown(() => dio.close(force: true));
        final asset = WindowsUpdateAsset(
          url: 'https://github.com/example/setup.exe',
          size: failure == 'size' ? 5 : 4,
          sha256Digest: failure == 'digest'
              ? '0' * 64
              : sha256.convert([1, 2, 3, 4]).toString(),
        );
        final operation = downloadWindowsUpdate(
          dio,
          asset,
          temporaryDirectory: root,
        );
        if (failure == 'none') {
          final file = await operation;
          expect(await file.readAsBytes(), [1, 2, 3, 4]);
          expect(file.path, endsWith('.exe'));
        } else {
          await expectLater(operation, throwsFormatException);
          expect(await root.list().toList(), isEmpty);
        }
      },
    );
  }
}
