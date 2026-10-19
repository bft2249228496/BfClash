import 'dart:io';
import 'dart:ui' as ui;

import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/desktop_style.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/views/about.dart';
import 'package:bfclash/views/application_setting.dart';
import 'package:bfclash/views/backup_and_restore.dart';
import 'package:bfclash/views/config/config.dart';
import 'package:bfclash/views/config/advanced.dart';
import 'package:bfclash/views/developer.dart';
import 'package:bfclash/views/hotkey.dart';
import 'package:bfclash/views/resources.dart';
import 'package:bfclash/views/sub_store.dart';
import 'package:bfclash/views/theme.dart';
import 'package:bfclash/views/navigation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fixed_network_detection.dart';
import '../helpers/test_app.dart';

void main() {
  setUpAll(() async {
    final home = Directory.systemTemp;
    AppPath.supportDirectory = () async => home;
    AppPath.temporaryDirectory = () async => home;
    AppPath.cacheDirectory = () async => home;
    AppPath.downloadDirectory = () async => home;
    globalState.appEnv = 'stable';
    globalState.packageInfo = PackageInfo(
      appName: 'BfClash',
      packageName: 'com.bfclash.client',
      version: '0.2.0',
      buildNumber: '1',
    );
    SharedPreferences.setMockInitialValues({});
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

  for (final entry in [
    (name: 'substore', view: const SubStoreView(), hasTimer: true),
    (name: 'resources', view: const ResourcesView(), hasTimer: false),
    (name: 'backup', view: const BackupAndRestore(), hasTimer: false),
    (name: 'basic-config', view: const ConfigView(), hasTimer: false),
    (name: 'advanced-config', view: const AdvancedConfigView(), hasTimer: false),
    (name: 'application', view: const ApplicationSettingView(), hasTimer: false),
    (name: 'theme', view: const ThemeView(), hasTimer: false),
    (name: 'hotkey', view: const HotKeyView(), hasTimer: false),
    (name: 'about', view: const AboutView(), hasTimer: false),
    (name: 'developer', view: const DeveloperView(), hasTimer: false),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('${entry.name} at 1400 in ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            appSettingProvider.overrideWithBuild(
              (_, _) => const AppSettingProps(),
            ),
            currentGroupsStateProvider.overrideWithValue(
              const GroupsState(value: []),
            ),
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
        container.read(viewSizeProvider.notifier).value = const Size(1400, 1000);

        const key = ValueKey('settings-preview');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: TestApp(
              includeNavigatorKey: false,
              theme: buildDesktopTheme(
                ThemeData(
                  fontFamilyFallback: const ['DesktopCjk'],
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xff6366f1),
                    brightness: brightness,
                  ),
                  brightness: brightness,
                ).withAppShapes,
              ),
              locale: const Locale('en'),
              child: RepaintBoundary(key: key, child: entry.view),
            ),
          ),
        );
        if (entry.hasTimer) {
          // SubStoreView runs a periodic status timer; never settles.
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
        } else {
          await tester.pumpAndSettle(const Duration(milliseconds: 200));
        }
        expect(tester.takeException(), isNull);

        final dir = Platform.environment['BFCLASH_SCREENSHOT_DIR'];
        if (dir != null) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '$dir/${entry.name}-1400-${brightness.name}-en-1.0.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
