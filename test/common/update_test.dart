import 'package:fl_clash/common/update.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> asset(String name) => {
  'name': name,
  'browser_download_url': 'https://example.test/$name',
};

void main() {
  test('selects the APK matching the device primary ABI', () {
    final url = selectAndroidUpdateAsset(
      [
        asset('Lansway-0.2.10-android-x86_64.apk'),
        asset('Lansway-0.2.10-android-arm64-v8a.apk'),
        asset('Lansway-0.2.10-android-armeabi-v7a.apk'),
      ],
      ['arm64-v8a', 'armeabi-v7a'],
    );
    expect(url, endsWith('arm64-v8a.apk'));
  });
  test('does not install an incompatible APK when several are present', () {
    final url = selectAndroidUpdateAsset(
      [
        asset('Lansway-0.2.10-android-arm64-v8a.apk'),
        asset('Lansway-0.2.10-android-x86_64.apk'),
      ],
      ['armeabi-v7a'],
    );
    expect(url, isNull);
  });
  test('accepts a universal APK', () {
    final url = selectAndroidUpdateAsset(
      [asset('Lansway-0.2.10-android-universal.apk')],
      ['x86_64'],
    );
    expect(url, endsWith('universal.apk'));
  });
}
