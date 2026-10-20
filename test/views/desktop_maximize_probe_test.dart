import 'dart:io';
import 'dart:ui' as ui;

import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/desktop_style.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/views/dashboard/widgets/network_speed.dart';
import 'package:bfclash/views/desktop_dashboard.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fixed_network_detection.dart';
import '../helpers/test_app.dart';

/// Maximised-window layout probe: pumps the desktop dashboard at common
/// maximised logical resolutions across text scales, records every overflow
/// instead of failing, and dumps screenshots for manual inspection.
void main() {
  setUpAll(() async {
    final home = Directory.systemTemp;
    AppPath.supportDirectory = () async => home;
    AppPath.temporaryDirectory = () async => home;
    AppPath.cacheDirectory = () async => home;
    AppPath.downloadDirectory = () async => home;
    final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
    final cjkFont = Platform.environment['BFCLASH_CJK_FONT'];
    if (cjkFont != null) {
      final loader = FontLoader('DesktopCjk')
        ..addFont(
          Future.value(ByteData.sublistView(await File(cjkFont).readAsBytes())),
        );
      await loader.load();
    }
    for (final font in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(
        '$root/bin/cache/artifacts/material_fonts/${font.value}',
      );
      if (await file.exists()) {
        final loader = FontLoader(font.key)
          ..addFont(
            Future.value(ByteData.sublistView(await file.readAsBytes())),
          );
        await loader.load();
      }
    }
  });

  final scenarios = [
    // (width, height, locale, scale) — maximised logical sizes on Windows.
    (
      width: 1366.0,
      height: 728.0,
      locale: const Locale('zh', 'CN'),
      scale: 1.0,
    ),
    (
      width: 1536.0,
      height: 816.0,
      locale: const Locale('zh', 'CN'),
      scale: 1.0,
    ),
    (
      width: 1536.0,
      height: 816.0,
      locale: const Locale('zh', 'CN'),
      scale: 1.3,
    ),
    (
      width: 1920.0,
      height: 1040.0,
      locale: const Locale('zh', 'CN'),
      scale: 1.0,
    ),
    (
      width: 1920.0,
      height: 1040.0,
      locale: const Locale('zh', 'CN'),
      scale: 1.3,
    ),
    (width: 1920.0, height: 1040.0, locale: const Locale('en'), scale: 1.5),
    (
      width: 2560.0,
      height: 1360.0,
      locale: const Locale('zh', 'CN'),
      scale: 1.0,
    ),
    (
      width: 2560.0,
      height: 1360.0,
      locale: const Locale('zh', 'CN'),
      scale: 1.3,
    ),
  ];

  for (final scenario in scenarios) {
    final width = scenario.width;
    final height = scenario.height;
    testWidgets('maximized probe ${width.toInt()}x${height.toInt()} '
        '${scenario.locale} scale ${scenario.scale}', (tester) async {
      final overflows = <String>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        final message = details.toString();
        if (message.contains('overflowed') ||
            message.contains('RenderFlex') ||
            message.contains('RenderConstrainedBox')) {
          overflows.add(message);
        } else {
          previousHandler?.call(details);
        }
      };
      addTearDown(() => FlutterError.onError = previousHandler);

      tester.platformDispatcher.textScaleFactorTestValue = scenario.scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const groups = [
        Group(
          type: GroupType.Selector,
          name: 'PROXY',
          now: 'Example node',
          all: [
            Proxy(name: 'Example node', type: 'ss'),
            Proxy(name: 'Backup node', type: 'trojan'),
          ],
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          dashboardCoreStatsProvider.overrideWithValue(false),
          appSettingProvider.overrideWithBuild(
            (_, _) => const AppSettingProps(),
          ),
          currentGroupsStateProvider.overrideWithValue(
            const GroupsState(value: groups),
          ),
          delayDataSourceProvider.overrideWithValue(const {
            'https://www.gstatic.com/generate_204': {'Example node': 42},
          }),
          networkDetectionProvider.overrideWith(FixedNetworkDetection.new),
          localIpProvider.overrideWithBuild((_, _) => '192.168.31.22'),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(showLabel: true));
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      container.read(runTimeProvider.notifier).value = 125000;
      container.read(viewSizeProvider.notifier).value = Size(width, height);

      const key = ValueKey('maximize-probe');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            locale: scenario.locale,
            includeNavigatorKey: false,
            textScaleFactor: scenario.scale,
            theme: buildDesktopTheme(
              ThemeData(
                fontFamilyFallback: const ['DesktopCjk'],
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xff6366f1),
                ),
              ).withAppShapes,
            ),
            child: const RepaintBoundary(
              key: key,
              child: DesktopDashboardView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final output = Platform.environment['BFCLASH_SCREENSHOT_DIR'];
      if (output != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File(
            '$output/maximize-${width.toInt()}x${height.toInt()}-${scenario.locale}-s${scenario.scale}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      // ignore: avoid_print
      print(
        'PROBE ${width.toInt()}x${height.toInt()} '
        '${scenario.locale} scale=${scenario.scale} '
        'overflows=${overflows.length}',
      );
      for (final o in overflows.take(4)) {
        // ignore: avoid_print
        print('---- OVERFLOW ----\n$o');
      }
      expect(overflows, isEmpty, reason: 'layout overflows at maximize scale');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
