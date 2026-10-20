import 'dart:io';

import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/desktop_style.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/views/navigation.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/views/dashboard/widgets/network_speed.dart';
import 'package:bfclash/views/desktop_dashboard.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fixed_network_detection.dart';
import '../helpers/test_app.dart';

/// 探针：最大化时最后一行「流量统计」与「工具」两张卡片必须等高
/// （上下边界重合）。覆盖多个最大化宽度与字体缩放。
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

  for (final scenario in [
    (width: 1366.0, height: 800.0, scale: 1.0),
    (width: 1536.0, height: 816.0, scale: 1.3),
    (width: 1920.0, height: 1040.0, scale: 1.0),
    (width: 1920.0, height: 1040.0, scale: 1.5),
    (width: 2560.0, height: 1360.0, scale: 1.3),
    (width: 2560.0, height: 1360.0, scale: 1.5),
  ]) {
    testWidgets(
      'traffic usage and quick access cards align at ${scenario.width} scale ${scenario.scale}',
      (tester) async {
        final width = scenario.width;
        final height = scenario.height;
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
              Proxy(name: 'DIRECT', type: 'Direct'),
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
            navigationItemsStateProvider.overrideWithValue(
              NavigationItemsState(
                value: navigation.getItems(openLogs: true, hasProxies: true),
              ),
            ),
            networkDetectionProvider.overrideWith(FixedNetworkDetection.new),
            localIpProvider.overrideWithBuild((_, _) => '192.168.31.22'),
          ],
        );
        addTearDown(container.dispose);
        globalState.container = container;
        container.read(coreStatusProvider.notifier).value =
            CoreStatus.connected;
        container.read(runTimeProvider.notifier).value = 125000;
        container.read(viewSizeProvider.notifier).value = Size(width, height);
        navigationPort = navigation;
        addTearDown(() => navigationPort = null);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: TestApp(
              locale: const Locale('zh', 'CN'),
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
              child: const DesktopDashboardView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final lastRow = find.byType(IntrinsicHeight);
        expect(lastRow, findsOneWidget);
        final cards = find.descendant(
          of: lastRow,
          matching: find.byType(CommonCard),
        );
        expect(cards, findsNWidgets(2));

        final trafficCard = tester.getRect(cards.first);
        final toolsCard = tester.getRect(cards.last);
        expect(
          (trafficCard.top - toolsCard.top).abs(),
          lessThan(0.5),
          reason:
              'top edges misaligned at ${scenario.width} scale ${scenario.scale}: '
              'traffic=${trafficCard.top} tools=${toolsCard.top}',
        );
        expect(
          (trafficCard.bottom - toolsCard.bottom).abs(),
          lessThan(0.5),
          reason:
              'bottom edges misaligned at ${scenario.width} scale ${scenario.scale}: '
              'traffic=${trafficCard.bottom} tools=${toolsCard.bottom}',
        );
      },
    );
  }
}
