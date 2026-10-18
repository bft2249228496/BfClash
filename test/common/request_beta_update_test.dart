import 'package:dio/dio.dart';
import 'package:bfclash/common/request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bfclash/state.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final version in ['0.2.27-beta.1']) {
    test('update request failure is not no-update for $version', () async {
      globalState.packageInfo = PackageInfo(
        appName: 'BfClash',
        packageName: 'com.bfclash.client',
        version: version,
        buildNumber: '1',
      );
      final client = Request();
      client.clashDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            ),
          ),
        ),
      );
      await expectLater(client.checkForUpdate(), throwsA(isA<DioException>()));
      client.clashDio.close(force: true);
      client.dio.close(force: true);
    });
  }
}
