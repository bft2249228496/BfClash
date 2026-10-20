import 'dart:async';

import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/permission.dart';
import 'package:bfclash/common/system_dns.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/manager/window_manager.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/widgets/animated_visibility.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(checkIpProvider, (prev, next) {
      if (prev != next && next.isInit && next.containsDetection) {
        ref.read(networkDetectionProvider.notifier).startCheck();
      }
    });
    ref.listenManual(configProvider, (prev, next) {
      if (prev != next) {
        ref.read(storeActionProvider.notifier).savePreferencesDebounce();
      }
    });
    ref.listenManual(needUpdateGroupsProvider, (prev, next) {
      if (prev != next) {
        ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
      }
    });
    ref.listenManual(suspendProvider, (prev, next) {
      final isStart = ref.read(isStartProvider);
      if (prev != next && isStart) {
        debouncer.call(FunctionTag.suspend, () async {
          final core = ref.read(coreHandlerProvider);
          if (next == true) {
            await core.stopListener();
          } else {
            await core.startListener();
          }
          ref.read(checkIpNumProvider.notifier).add();
        });
      }
    });
    final systemDns = systemDnsCoordinator;
    if (systemDns != null) {
      ref.listenManual(shouldPatchSystemDnsProvider, (prev, next) {
        unawaited(systemDns.sync(next));
      }, fireImmediately: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    commonPrint.log('$state');
    if (state == AppLifecycleState.resumed) {
      permissions.check(ref.read);
      render?.resume();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(setupActionProvider.notifier).tryCheckIp();
      });
    }
  }

  @override
  void didChangePlatformBrightness() {
    ref.read(themeActionProvider.notifier).updateBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (_) {
        render?.resume();
      },
      child: widget.child,
    );
  }
}

class AppEnvManager extends StatelessWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      if (globalState.isPre) {
        return Banner(
          message: 'DEBUG',
          location: BannerLocation.topEnd,
          child: child,
        );
      }
    }
    if (globalState.isPre) {
      return Banner(
        message: globalState.appEnv.toUpperCase(),
        location: BannerLocation.topEnd,
        child: child,
      );
    }
    return child;
  }
}

class _SidebarRail extends StatelessWidget {
  const _SidebarRail({
    required this.items,
    required this.currentIndex,
    required this.showLabel,
    required this.onSelected,
  });

  final List<NavigationItem> items;
  final int currentIndex;
  final bool showLabel;
  final void Function(int index) onSelected;

  @override
  Widget build(BuildContext context) {
    final extended =
        system.isDesktop &&
        showLabel &&
        MediaQuery.sizeOf(context).width >= 1100;
    if (extended) {
      return SizedBox(
        width: 236,
        child: _ExtendedSidebar(
          items: items,
          currentIndex: currentIndex,
          onSelected: onSelected,
        ),
      );
    }
    final labelStyle = context.textTheme.labelLarge!.copyWith(
      color: context.colorScheme.onSurface,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: NavigationRail(
            scrollable: true,
            minExtendedWidth: system.isDesktop ? 236 : 200,
            minWidth: system.isDesktop ? 76 : null,
            groupAlignment: -1,
            indicatorShape: system.isDesktop ? AppShape.sm : null,
            indicatorColor: system.isDesktop
                ? context.colorScheme.primary.withValues(alpha: 0.14)
                : null,
            backgroundColor: Colors.transparent,
            selectedLabelTextStyle: labelStyle,
            unselectedLabelTextStyle: labelStyle,
            destinations: [
              for (final item in items)
                NavigationRailDestination(
                  icon: item.icon,
                  label: Text(item.label.label),
                ),
            ],
            onDestinationSelected: onSelected,
            extended: false,
            selectedIndex: currentIndex,
            labelType: showLabel
                ? NavigationRailLabelType.all
                : NavigationRailLabelType.none,
          ),
        ),
      ],
    );
  }
}

const _monitorLabels = {PageLabel.dashboard};const _networkLabels = {
  PageLabel.proxies,
  PageLabel.profiles,
  PageLabel.requests,
  PageLabel.connections,
};
const _diagnosticsLabels = {PageLabel.logs};

// Widget tests render the shell without bootstrap, where packageInfo is unset.
String _sidebarVersionLabel() {
  try {
    return 'v${globalState.packageInfo.version}';
  } on Error {
    return 'BfClash';
  }
}

class _ExtendedSidebar extends StatelessWidget {
  const _ExtendedSidebar({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<NavigationItem> items;
  final int currentIndex;
  final void Function(int index) onSelected;

  List<({int index, NavigationItem item})> _of(Set<PageLabel> labels) {
    return [
      for (var i = 0; i < items.length; i++)
        if (labels.contains(items[i].label)) (index: i, item: items[i]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.appLocalizations;
    final groups = [
      (labels.navGroupMonitor, _of(_monitorLabels)),
      (labels.navGroupNetwork, _of(_networkLabels)),
      (labels.navGroupDiagnostics, _of(_diagnosticsLabels)),
    ];
    final pinned = _of({PageLabel.tools});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final (title, entries) in groups)
                if (entries.isNotEmpty) ...[
                  _SidebarSectionLabel(label: title),
                  for (final entry in entries)
                    _SidebarTile(
                      item: entry.item,
                      selected: entry.index == currentIndex,
                      onTap: () => onSelected(entry.index),
                    ),
                  const SizedBox(height: 4),
                ],
            ],
          ),
        ),
        if (pinned.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(
                  height: 1,
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                for (final entry in pinned)
                  _SidebarTile(
                    item: entry.item,
                    selected: entry.index == currentIndex,
                    onTap: () => onSelected(entry.index),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SidebarTile extends ConsumerWidget {
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  int? _badgeCount(WidgetRef ref) {
    if (item.label != PageLabel.proxies) return null;
    final groups = ref.watch(currentGroupsStateProvider).value;
    if (groups.isEmpty) return null;
    final names = <String>{
      for (final group in groups)
        for (final proxy in group.all) proxy.name,
    };
    return names.isEmpty ? null : names.length;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorScheme;
    final badge = _badgeCount(ref);
    final foreground = selected ? colors.primary : colors.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: AppRadius.sm,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.sm,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                IconTheme.merge(
                  data: IconThemeData(
                    size: 18,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                  child: item.icon,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.onSurface.withValues(alpha: 0.08),
                      shape: AppShape.full,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      child: Text(
                        '$badge',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  Widget _buildBackground({
    required BuildContext context,
    required Widget child,
  }) {
    return Material(
      color: system.isDesktop
          ? context.colorScheme.surfaceContainerLowest
          : context.colorScheme.surfaceContainer,
      child: child,
    );
  }

  void _updateSideBarWidth(WidgetRef ref, double contentWidth) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sideWidthProvider.notifier).value =
          ref.read(viewSizeProvider.select((state) => state.width)) -
          contentWidth;
    });
  }

  void _handleToPage(WidgetRef ref, PageLabel pageLabel) {
    final focusNode = FocusManager.instance.primaryFocus;
    final preserveNavigationFocus =
        focusNode?.context?.findAncestorWidgetOfExactType<NavigationRail>() !=
        null;
    ref.read(currentPageLabelProvider.notifier).toPage(pageLabel);
    if (!preserveNavigationFocus || focusNode == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNode.context != null && focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final isMobileView = navigationState.viewMode == ViewMode.mobile;
    final currentIndex = navigationState.currentIndex;
    final showLabel = ref.watch(appSettingProvider).showLabel;
    final extended =
        system.isDesktop &&
        showLabel &&
        MediaQuery.sizeOf(context).width >= 1100;
    return Container(
      color: system.isDesktop
          ? context.colorScheme.surfaceContainerLowest
          : context.colorScheme.surfaceContainer,
      child: Row(
        children: [
          AnimatedVisibility.sidebar(
            visible: !isMobileView,
            child: _buildBackground(
              context: context,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (system.isMacOS) const SizedBox(height: 22),
                    const SizedBox(height: 10),
                    if (!system.isMacOS) ...[
                      if (extended)
                        SizedBox(
                          width: 236,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                const ClipRect(child: AppIcon()),
                                const SizedBox(width: 12),
                                Text(
                                  'BfClash',
                                  style: context.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const ClipRect(child: AppIcon()),
                      const SizedBox(height: 12),
                    ],
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: const HiddenBarScrollBehavior(),
                        child: _SidebarRail(
                          items: navigationItems,
                          currentIndex: currentIndex,
                          showLabel: showLabel,
                          onSelected: (index) {
                            _handleToPage(ref, navigationItems[index].label);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (extended)
                      SizedBox(
                        width: 236,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Row(
                            children: [
                              Text(
                                _sidebarVersionLabel(),
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'GPL-3.0',
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: context.appLocalizations.toggleLabel,
                      onPressed: () {
                        ref
                            .read(appSettingProvider.notifier)
                            .update(
                              (state) =>
                                  state.copyWith(showLabel: !state.showLabel),
                            );
                      },
                      icon: Icon(
                        Icons.menu,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: ClipRect(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  _updateSideBarWidth(ref, constraints.maxWidth);
                  return child;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
