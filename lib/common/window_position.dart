import 'dart:math' as math;
import 'dart:ui';

bool hasReachableWindowTitle(Rect window, Rect workArea) {
  if (!window.isFinite ||
      !workArea.isFinite ||
      window.isEmpty ||
      workArea.isEmpty) {
    return false;
  }
  final title = Rect.fromLTWH(
    window.left,
    window.top,
    window.width,
    math.min(32, window.height),
  );
  final visible = title.intersect(workArea);
  return visible.height >= title.height &&
      visible.width >= math.min(160, window.width);
}
