import 'package:fl_clash/common/update.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> asset(String name, {int size = 50000000}) => {
  'name': name,
  'size': size,
  'browser_download_url': 'https://example.test/$name',
};

void main() {
  test('selects the APK matching the device primary ABI', () {
    final url = selectAndroidUpdateAsset(
      [
        asset('BfClash-0.2.10-android-x86_64.apk'),
        asset('BfClash-0.2.10-android-arm64-v8a.apk'),
        asset('BfClash-0.2.10-android-armeabi-v7a.apk'),
      ],
      ['arm64-v8a', 'armeabi-v7a'],
    );
    expect(url, endsWith('arm64-v8a.apk'));
  });

  test('selects asset entry with full metadata', () {
    final entry = selectAndroidUpdateAssetEntry(
      [asset('BfClash-0.2.10-android-arm64-v8a.apk', size: 55000000)],
      ['arm64-v8a'],
    );
    expect(entry?['name'], 'BfClash-0.2.10-android-arm64-v8a.apk');
    expect(entry?['size'], 55000000);
  });

  test('formats bytes correctly', () {
    expect(UpdateDownloadProgress.formatBytes(0), '0 B');
    expect(UpdateDownloadProgress.formatBytes(1024), '1 KB');
    expect(UpdateDownloadProgress.formatBytes(55 * 1024 * 1024), '55 MB');
  });

  test('does not install an incompatible APK when several are present', () {
    final url = selectAndroidUpdateAsset(
      [
        asset('BfClash-0.2.10-android-arm64-v8a.apk'),
        asset('BfClash-0.2.10-android-x86_64.apk'),
      ],
      ['armeabi-v7a'],
    );
    expect(url, isNull);
  });

  test('accepts a universal APK', () {
    final url = selectAndroidUpdateAsset(
      [asset('BfClash-0.2.10-android-universal.apk')],
      ['x86_64'],
    );
    expect(url, endsWith('universal.apk'));
  });
}
