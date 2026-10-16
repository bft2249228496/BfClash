import 'dart:io';
import 'dart:ui' as ui;

import 'package:bfclash/common/common.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/views/desktop_dashboard.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fixed_network_detection.dart';
import '../helpers/test_app.dart';

void main() {
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
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
  for (final width in [900.0, 1400.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('desktop overview at $width in ${brightness.name}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            networkDetectionProvider.overrideWith(FixedNetworkDetection.new),
          ],
        );
        addTearDown(container.dispose);
        globalState.container = container;
        container.read(coreStatusProvider.notifier).value =
            CoreStatus.connected;
        container.read(runTimeProvider.notifier).value = 125000;
        const key = ValueKey('desktop-preview');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: TestApp(
              locale: const Locale('en'),
              includeNavigatorKey: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xff6366f1),
                  brightness: brightness,
                ),
              ).withAppShapes,
              child: const RepaintBoundary(
                key: key,
                child: DesktopDashboardView(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('192.0.2.42'), findsOneWidget);
        expect(find.text('Proxy running'), findsOneWidget);
        final output = Platform.environment['BFCLASH_SCREENSHOT_DIR'];
        if (output != null) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(output).create(recursive: true);
            await File(
              '$output/desktop-${width.toInt()}-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
