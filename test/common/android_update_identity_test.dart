import 'package:bfclash/common/update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> release(String tag, {bool apk = true}) => {
    'tag_name': tag,
    'assets': [
      {'name': apk ? 'app-arm64-v8a.apk' : 'app.exe'},
    ],
  };
  test(
    'installed beta never offers the RC package with a different identity',
    () {
      final releases = [
        release('v0.2.29-rc.3'),
        release('v0.2.29-beta.2'),
        release('v0.2.27-windows-ci.39134501289', apk: false),
      ];
      final compatible = releases
          .where(
            (item) =>
                isAndroidReleaseCompatible(item, 'com.lansway.client.beta'),
          )
          .toList();
      expect(compatible.map((item) => item['tag_name']), ['v0.2.29-beta.2']);
    },
  );
  test('stable and RC identity never offers isolated beta updates', () {
    expect(
      isAndroidReleaseCompatible(
        release('v0.2.29-beta.2'),
        'com.bfclash.client',
      ),
      isFalse,
    );
    expect(
      isAndroidReleaseCompatible(release('v0.2.29-rc.3'), 'com.bfclash.client'),
      isTrue,
    );
    expect(
      isAndroidReleaseCompatible(release('v0.2.29'), 'com.bfclash.client'),
      isTrue,
    );
    expect(
      isAndroidReleaseCompatible(release('v0.2.29'), 'unknown.app'),
      isFalse,
    );
    expect(
      isAndroidReleaseCompatible(
        release('v0.2.29', apk: false),
        'com.bfclash.client',
      ),
      isFalse,
    );
  });
}
