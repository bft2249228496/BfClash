import 'dart:ui';

import 'package:bfclash/common/window_position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const primary = Rect.fromLTWH(0, 0, 1920, 1040);
  test('does not restore a window with only its bottom corner visible', () {
    expect(
      hasReachableWindowTitle(
        const Rect.fromLTWH(-500, -500, 800, 700),
        primary,
      ),
      isFalse,
    );
  });
  test(
    'keeps a reachable title on a secondary display with negative coordinates',
    () {
      expect(
        hasReachableWindowTitle(
          const Rect.fromLTWH(-1200, 80, 800, 700),
          const Rect.fromLTWH(-1920, 0, 1920, 1040),
        ),
        isTrue,
      );
    },
  );
  test('rejects taskbar-only visibility and an inaccessible sliver', () {
    expect(
      hasReachableWindowTitle(const Rect.fromLTWH(80, 1030, 800, 700), primary),
      isFalse,
    );
    expect(
      hasReachableWindowTitle(const Rect.fromLTWH(1900, 80, 800, 700), primary),
      isFalse,
    );
  });
  test('accepts a large window with a reachable title', () {
    expect(
      hasReachableWindowTitle(
        const Rect.fromLTWH(-200, 80, 2500, 1400),
        primary,
      ),
      isTrue,
    );
  });
  test('rejects non-finite and empty saved geometry', () {
    expect(
      hasReachableWindowTitle(
        const Rect.fromLTWH(double.nan, 80, 800, 700),
        primary,
      ),
      isFalse,
    );
    expect(hasReachableWindowTitle(Rect.zero, primary), isFalse);
  });
}
