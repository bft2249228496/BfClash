import 'dart:io';
import 'dart:ui' as ui;

import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/desktop_style.dart';
import 'package:bfclash/manager/app_manager.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/views/navigation.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/views/desktop_dashboard.dart';
import 'package:bfclash/views/desktop_tools.dart';
import 'package:bfclash/views/profiles/profiles.dart';
import 'package:bfclash/views/proxies/proxies.dart';
import 'package:bfclash/views/proxies/card.dart';
import 'package:bfclash/views/connection/connections.dart';
import 'package:bfclash/views/logs.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fixed_network_detection.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

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
  for (final screen in [
    'desktop',
    'tools',
    'profiles',
    'proxies',
    'connections',
    'logs',
  ]) {
    for (final width in [900.0, 1400.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('$screen overview at $width in ${brightness.name}', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final profiles = [
            Profile.normal(
              label: 'Personal subscription',
              url: 'https://example.test/sub',
            ).copyWith(
              subscriptionInfo: const SubscriptionInfo(
                upload: 1024,
                download: 2048,
                total: 8192,
                expire: 1893456000,
              ),
            ),
            Profile.normal(label: 'Local configuration'),
          ];
          const groups = [
            Group(
              type: GroupType.Selector,
              name: 'PROXY',
              now: 'Example node',
              all: [
                Proxy(name: 'Example node', type: 'ss'),
                Proxy(name: 'Backup node', type: 'trojan'),
                Proxy(name: 'DIRECT', type: 'Direct'),
              ],
            ),
            Group(
              type: GroupType.Selector,
              name: 'Streaming',
              now: 'DIRECT',
              all: [Proxy(name: 'DIRECT', type: 'Direct')],
            ),
          ];
          final container = ProviderContainer(
            overrides: [
              if (screen == 'profiles' || screen == 'proxies') ...[
                profilesProvider.overrideWith(() => TestProfiles(profiles)),
                currentProfileIdProvider.overrideWithBuild(
                  (_, _) => profiles.first.id,
                ),
              ],
              if (screen == 'proxies') ...[
                proxiesStyleSettingProvider.overrideWithBuild(
                  (_, _) => const ProxiesStyleProps(type: ProxiesType.tab),
                ),
                currentGroupsStateProvider.overrideWithValue(
                  const GroupsState(value: groups),
                ),
                proxiesTabStateProvider.overrideWith(
                  (ref) => const ProxiesTabState(
                    groups: groups,
                    currentGroupName: 'PROXY',
                    proxyCardType: ProxyCardType.expand,
                  ),
                ),
              ],
              navigationItemsStateProvider.overrideWithValue(
                NavigationItemsState(
                  value: navigation.getItems(openLogs: true, hasProxies: true),
                ),
              ),
              networkDetectionProvider.overrideWith(FixedNetworkDetection.new),
            ],
          );
          addTearDown(container.dispose);
          globalState.container = container;
          container
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(showLabel: true));
          container.read(coreStatusProvider.notifier).value =
              CoreStatus.connected;
          container.read(runTimeProvider.notifier).value = 125000;
          container.read(viewSizeProvider.notifier).value = Size(width, 1000);
          navigationPort = navigation;
          addTearDown(() => navigationPort = null);
          container.read(currentPageLabelProvider.notifier).toPage(
            switch (screen) {
              'desktop' => PageLabel.dashboard,
              'profiles' => PageLabel.profiles,
              'proxies' => PageLabel.proxies,
              'connections' => PageLabel.connections,
              'logs' => PageLabel.logs,
              _ => PageLabel.tools,
            },
          );
          const key = ValueKey('desktop-preview');
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: TestApp(
                locale: const Locale('en'),
                includeNavigatorKey: false,
                theme: buildDesktopTheme(
                  ThemeData(
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xff6366f1),
                      brightness: brightness,
                    ),
                  ).withAppShapes,
                ),
                child: RepaintBoundary(
                  key: key,
                  child: AppSidebarContainer(
                    child: switch (screen) {
                      'desktop' => const DesktopDashboardView(),
                      'profiles' => const ProfilesView(),
                      'proxies' => const ProxiesView(),
                      'connections' => ConnectionsView(
                        connectionsReader: () async => [
                          TrackerInfo(
                            id: 'preview',
                            metadata: const Metadata(
                              network: 'tcp',
                              host: 'example.test',
                              process: 'Browser.exe',
                              destinationIP: '192.0.2.1',
                              destinationPort: '443',
                            ),
                            upload: 2048,
                            download: 16384,
                            start: DateTime(2026, 10, 18),
                            chains: ['Example node', 'PROXY'],
                            rule: 'Match',
                            rulePayload: '',
                          ),
                        ],
                      ),
                      'logs' => const LogsView(),
                      _ => const DesktopToolsView(),
                    },
                  ),
                ),
              ),
            ),
          );
          if (screen == 'logs') {
            container
                .read(logsProvider.notifier)
                .add(
                  const Log(
                    payload:
                        '[TCP] example.test:443 matched Match using PROXY[Example node]',
                    dateTime: '2026-10-18 16:00:00',
                  ),
                );
            await tester.pump(const Duration(milliseconds: 350));
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (screen == 'desktop') {
            expect(find.text('192.0.2.42'), findsOneWidget);
            expect(find.text('Proxy running'), findsOneWidget);
            expect(
              find.byIcon(Icons.power_settings_new_rounded),
              findsOneWidget,
            );
          } else if (screen == 'connections') {
            expect(find.textContaining('example.test'), findsWidgets);
            expect(find.byIcon(Icons.block), findsOneWidget);
          } else if (screen == 'logs') {
            expect(find.textContaining('[TCP] example.test'), findsOneWidget);
            expect(find.byIcon(Icons.save_as_outlined), findsOneWidget);
          } else if (screen == 'proxies') {
            expect(find.byType(ProxyCard), findsWidgets);
            if (width >= 1400) {
              expect(
                find.byKey(const ValueKey('desktop-proxy-group-Streaming')),
                findsOneWidget,
              );
            } else {
              expect(find.byType(TabBar), findsOneWidget);
            }
          } else if (screen == 'profiles') {
            expect(find.text('Personal subscription'), findsOneWidget);
            expect(find.text('Local configuration'), findsOneWidget);
            expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
          } else {
            expect(find.text('Sub-Store'), findsWidgets);
            expect(find.text('Backup and restore'), findsWidgets);
          }
          expect(find.byType(NavigationRail), findsOneWidget);
          final rail = tester.widget<NavigationRail>(
            find.byType(NavigationRail),
          );
          expect(rail.extended, width >= 1100);
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
                '$output/$screen-${width.toInt()}-${brightness.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
