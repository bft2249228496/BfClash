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
import 'package:bfclash/views/dashboard/widgets/network_speed.dart';
import 'package:bfclash/views/desktop_dashboard.dart';
import 'package:bfclash/views/desktop_tools.dart';
import 'package:bfclash/views/profiles/profiles.dart';
import 'package:bfclash/views/proxies/proxies.dart';
import 'package:bfclash/views/proxies/card.dart';
import 'package:bfclash/views/connection/connections.dart';
import 'package:bfclash/views/connection/requests.dart';
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
  for (final screen in [
    'desktop',
    'tools',
    'profiles',
    'proxies',
    'connections',
    'requests',
    'logs',
  ]) {
    for (final scenario in [
      (width: 900.0, locale: const Locale('en'), scale: 1.0),
      (width: 1400.0, locale: const Locale('en'), scale: 1.0),
      (width: 840.0, locale: const Locale('zh', 'CN'), scale: 1.3),
    ]) {
      final width = scenario.width;
      final chinese = scenario.locale.languageCode == 'zh';
      final height = chinese ? 592.0 : 1000.0;
      final remoteLabel = chinese
          ? '个人订阅 · 香港日本美国多地区线路与流媒体策略配置'
          : 'Personal subscription';
      final localLabel = chinese ? '本地配置 · 自定义规则与脚本' : 'Local configuration';
      for (final brightness in Brightness.values) {
        testWidgets(
          '$screen overview at $width in ${brightness.name} ${scenario.locale} scale ${scenario.scale}',
          (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = scenario.scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            tester.view.physicalSize = Size(width, height);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final profiles = [
              Profile.normal(
                label: remoteLabel,
                url: 'https://example.test/sub',
              ).copyWith(
                subscriptionInfo: const SubscriptionInfo(
                  upload: 1024,
                  download: 2048,
                  total: 8192,
                  expire: 1893456000,
                ),
              ),
              Profile.normal(label: localLabel),
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
                if (screen == 'desktop') ...[
                  dashboardCoreStatsProvider.overrideWithValue(false),
                  appSettingProvider.overrideWithBuild(
                    (_, _) => const AppSettingProps(),
                  ),
                  currentGroupsStateProvider.overrideWithValue(
                    const GroupsState(value: groups),
                  ),
                  delayDataSourceProvider.overrideWithValue(const {
                    'https://www.gstatic.com/generate_204': {
                      'Example node': 42,
                    },
                  }),
                ],
                if (screen != 'desktop' && screen != 'proxies') ...[
                  currentGroupsStateProvider.overrideWithValue(
                    const GroupsState(value: []),
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
                    value: navigation.getItems(
                      openLogs: true,
                      hasProxies: true,
                    ),
                  ),
                ),
                networkDetectionProvider.overrideWith(
                  FixedNetworkDetection.new,
                ),
                localIpProvider.overrideWithBuild((_, _) => '192.168.31.22'),
              ],
            );
            addTearDown(container.dispose);
            globalState.container = container;
            if (screen == 'requests') {
              container
                  .read(requestsProvider.notifier)
                  .addRequest(
                    TrackerInfo(
                      id: 'request-preview',
                      metadata: const Metadata(
                        network: 'tcp',
                        host: 'example.test',
                        process: 'Browser.exe',
                        destinationIP: '192.0.2.1',
                        destinationPort: '443',
                      ),
                      start: DateTime(2026, 10, 18),
                      chains: ['Example node', 'PROXY'],
                      rule: 'Match',
                      rulePayload: '',
                    ),
                  );
            }
            container
                .read(appSettingProvider.notifier)
                .update((state) => state.copyWith(showLabel: true));
            container.read(coreStatusProvider.notifier).value =
                CoreStatus.connected;
            container.read(runTimeProvider.notifier).value = 125000;
            container.read(viewSizeProvider.notifier).value = Size(
              width,
              height,
            );
            navigationPort = navigation;
            addTearDown(() => navigationPort = null);
            container.read(currentPageLabelProvider.notifier).toPage(
              switch (screen) {
                'desktop' => PageLabel.dashboard,
                'profiles' => PageLabel.profiles,
                'proxies' => PageLabel.proxies,
                'connections' => PageLabel.connections,
                'requests' => PageLabel.requests,
                'logs' => PageLabel.logs,
                _ => PageLabel.tools,
              },
            );
            const key = ValueKey('desktop-preview');
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: TestApp(
                  locale: scenario.locale,
                  includeNavigatorKey: false,
                  theme: buildDesktopTheme(
                    ThemeData(
                      fontFamilyFallback: const ['DesktopCjk'],
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
                        'requests' => const RequestsView(),
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
              // Hero card state plus the header status capsule.
              expect(
                find.text(chinese ? '代理运行中' : 'Proxy running'),
                findsWidgets,
              );
              expect(
                find.byIcon(Icons.power_settings_new_rounded),
                findsOneWidget,
              );
              final dashboardScroll = find
                  .descendant(
                    of: find.byType(DesktopDashboardView),
                    matching: find.byType(Scrollable),
                  )
                  .first;
              if (find.text('192.0.2.42').hitTestable().evaluate().isEmpty) {
                await tester.scrollUntilVisible(
                  find.text('192.0.2.42'),
                  250,
                  scrollable: dashboardScroll,
                );
                expect(find.text('192.0.2.42').hitTestable(), findsOneWidget);
                tester
                    .state<ScrollableState>(dashboardScroll)
                    .position
                    .jumpTo(0);
                await tester.pumpAndSettle();
              }
              expect(tester.takeException(), isNull);
            } else if (screen == 'requests') {
              expect(find.textContaining('example.test'), findsWidgets);
              expect(find.byIcon(Icons.search), findsOneWidget);
              expect(find.byIcon(Icons.block), findsOneWidget);
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
              expect(find.text(remoteLabel), findsOneWidget);
              expect(find.text(localLabel), findsOneWidget);
              expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
            } else {
              expect(find.text('Sub-Store'), findsWidgets);
              expect(
                find.text(chinese ? '备份与恢复' : 'Backup and restore'),
                findsWidgets,
              );
            }
            if (width >= 1100) {
              expect(find.byType(NavigationRail), findsNothing);
              expect(find.text('Monitor'), findsOneWidget);
              expect(find.text('Network'), findsOneWidget);
              expect(find.text('Diagnostics'), findsOneWidget);
            } else {
              final rail = tester.widget<NavigationRail>(
                find.byType(NavigationRail),
              );
              expect(rail.extended, isFalse);
            }
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
                  '$output/$screen-${width.toInt()}-${brightness.name}-${scenario.locale}-${scenario.scale}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
