import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:bfclash/common/common.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/views/dashboard/widgets/network_speed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';

void main() {
  setUpAll(() async {
    final font = Platform.environment['BFCLASH_CJK_FONT'];
    if (font != null) {
      final loader = FontLoader('UiPreviewCjk')
        ..addFont(
          Future.value(ByteData.sublistView(await File(font).readAsBytes())),
        );
      await loader.load();
    }
    final icons = File(
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (await icons.exists()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(await icons.readAsBytes())),
          ))
          .load();
    }
  });
  for (final width in [320.0, 390.0, 720.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('mobile rates follow latest sample at $width scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final container = ProviderContainer(
          overrides: [dashboardCoreStatsProvider.overrideWithValue(false)],
        );
        addTearDown(container.dispose);
        globalState.container = container;
        container.read(viewSizeProvider.notifier).value = Size(width, 900);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: TestApp(
              textScaleFactor: scale,
              locale: const Locale('zh', 'CN'),
              theme: ThemeData(
                fontFamily: 'UiPreviewCjk',
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xff6366f1),
                  brightness: Brightness.dark,
                ),
              ).withAppShapes,
              child: const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(16),
                  child: RepaintBoundary(
                    key: ValueKey('mobile-rates'),
                    child: NetworkSpeed(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('0 B/s', findRichText: true), findsNWidgets(2));
        const sample = Traffic(down: 3 * 1024 * 1024, up: 512 * 1024);
        for (var i = 0; i < 29; i++) {
          container
              .read(trafficsProvider.notifier)
              .addTraffic(
                Traffic(
                  down: (i % 7 + 1) * 256 * 1024,
                  up: (i % 5 + 1) * 64 * 1024,
                ),
              );
        }
        container.read(trafficsProvider.notifier).addTraffic(sample);
        container.read(totalTrafficProvider.notifier).value = const Traffic(
          down: 999999999,
          up: 888888888,
        );
        await tester.pump();
        expect(
          find.text(
            '${sample.down.traffic.value} ${sample.down.traffic.unit}/s',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            '${sample.up.traffic.value} ${sample.up.traffic.unit}/s',
            findRichText: true,
          ),
          findsOneWidget,
        );
        final output = Platform.environment['BFCLASH_SCREENSHOT_DIR'];
        if (output != null && width == 390 && scale == 1) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('mobile-rates')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(output).create(recursive: true);
            await File(
              '$output/mobile-rates.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        container.read(trafficsProvider.notifier).clear();
        await tester.pump();
        expect(find.text('0 B/s', findRichText: true), findsNWidgets(2));
        expect(
          tester
              .getSize(find.byKey(const ValueKey('network-speed-chart')))
              .height,
          greaterThan(tester.getSize(find.byType(NetworkSpeed)).height * 0.5),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
