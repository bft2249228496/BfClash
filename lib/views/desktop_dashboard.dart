import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/desktop_style.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/models/models.dart' show Group, TrafficShowExt;
import 'package:bfclash/providers/providers.dart' hide NetworkDetection;
import 'package:bfclash/state.dart';
import 'package:bfclash/views/dashboard/widgets/core_status_button.dart';
import 'package:bfclash/views/backup_and_restore.dart';
import 'package:bfclash/views/sub_store.dart';
import 'package:bfclash/views/dashboard/widgets/network_speed.dart';
import 'package:bfclash/views/dashboard/widgets/network_detection.dart';
import 'package:bfclash/views/dashboard/widgets/intranet_ip.dart';
import 'package:bfclash/views/dashboard/widgets/outbound_mode.dart';
import 'package:bfclash/views/dashboard/widgets/quick_options.dart';
import 'package:bfclash/views/dashboard/widgets/traffic_usage.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class DesktopDashboardView extends ConsumerWidget {
  const DesktopDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(isStartProvider);
    final connected = ref.watch(coreStatusProvider) == CoreStatus.connected;
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          final tiles = constraints.maxWidth >= 1080;
          const controls = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutboundModeV2(),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SystemProxyButton()),
                  SizedBox(width: 12),
                  Expanded(child: TUNButton()),
                ],
              ),
            ],
          );
          const quickAccess = _DesktopQuickAccessPanel();
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                children: [
                  const _DesktopTopStatusBar(),
                  const SizedBox(height: 24),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 320,
                          child: _DesktopConnectionCard(
                            running: running,
                            connected: connected,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: NetworkSpeed(height: 340, showRates: true),
                        ),
                      ],
                    )
                  else ...[
                    _DesktopConnectionCard(
                      running: running,
                      connected: connected,
                    ),
                    const SizedBox(height: 16),
                    const NetworkSpeed(height: 260, showRates: true),
                  ],
                  const SizedBox(height: 12),
                  const _DesktopTrafficStatsRow(),
                  if (tiles) ...[
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: OutboundModeV2()),
                        SizedBox(width: 12),
                        Expanded(child: SystemProxyButton()),
                        SizedBox(width: 12),
                        Expanded(child: TUNButton()),
                        SizedBox(width: 12),
                        Expanded(child: NetworkDetection()),
                        SizedBox(width: 12),
                        Expanded(child: IntranetIP()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 360, child: TrafficUsage()),
                        SizedBox(width: 16),
                        Expanded(child: quickAccess),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    controls,
                    const SizedBox(height: 16),
                    if (wide)
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: NetworkDetection()),
                          SizedBox(width: 16),
                          Expanded(child: TrafficUsage()),
                        ],
                      )
                    else ...[
                      const NetworkDetection(),
                      const SizedBox(height: 12),
                      const TrafficUsage(),
                    ],
                    const SizedBox(height: 16),
                    quickAccess,
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DesktopTopStatusBar extends StatelessWidget {
  const _DesktopTopStatusBar();

  @override
  Widget build(BuildContext context) {
    final labels = context.appLocalizations;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showRates = constraints.maxWidth >= 760;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BfClash',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels.dashboard,
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _DesktopStatusCapsule(showRates: showRates),
            const Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _CheckUpdateButton(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CheckUpdateButton extends ConsumerWidget {
  const _CheckUpdateButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = context.appLocalizations;
    return IconButton.outlined(
      tooltip: labels.checkUpdate,
      icon: const Icon(Icons.system_update_alt_rounded, size: 20),
      onPressed: () async {
        await globalState.safeRun(() async {
          final data = await request.checkForUpdate();
          if (!context.mounted) return;
          await ref
              .read(commonActionProvider.notifier)
              .checkUpdateResultHandle(data: data, isUser: true);
        }, title: labels.checkUpdate);
      },
    );
  }
}

/// Pill in the dashboard header: core status plus the live up/down rates
/// streamed by [trafficsProvider], mirroring the prototype's header strip.
class _DesktopStatusCapsule extends ConsumerWidget {
  const _DesktopStatusCapsule({required this.showRates});

  final bool showRates;

  static const _online = Color(0xFF34D399);
  static const _warning = Color(0xFFFBBF24);
  static const _downTint = Color(0xFF38BDF8);
  static const _upTint = Color(0xFFC084FC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = context.appLocalizations;
    final colors = context.colorScheme;
    final status = ref.watch(coreStatusProvider);
    final running = ref.watch(isStartProvider);

    late final String label;
    late final Color tone;
    if (status == CoreStatus.connecting) {
      label = labels.connecting;
      tone = _warning;
    } else if (!running) {
      label = labels.proxyStopped;
      tone = colors.onSurfaceVariant;
    } else if (status == CoreStatus.connected) {
      label = labels.proxyRunning;
      tone = _online;
    } else {
      label = labels.disconnected;
      tone = _warning;
    }

    final traffic = ref.watch(trafficsProvider).list.lastOrNull;
    final active = running && status == CoreStatus.connected;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tone,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: tone.withValues(alpha: active ? 0.55 : 0.2),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showRates) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 16, color: colors.outlineVariant),
            const SizedBox(width: 12),
            _RateText(
              icon: Icons.arrow_downward_rounded,
              tint: _downTint,
              value: traffic?.down,
            ),
            const SizedBox(width: 12),
            _RateText(
              icon: Icons.arrow_upward_rounded,
              tint: _upTint,
              value: traffic?.up,
            ),
          ],
        ],
      ),
    );
  }
}

class _RateText extends StatelessWidget {
  const _RateText({required this.icon, required this.tint, this.value});

  final IconData icon;
  final Color tint;
  final num? value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final muted = colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: value == null ? muted : tint),
        const SizedBox(width: 4),
        Text(
          value == null ? '—' : '${value!.shortTraffic.show}/s',
          style: context.textTheme.labelMedium?.copyWith(
            color: colors.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _DesktopConnectionCard extends ConsumerWidget {
  const _DesktopConnectionCard({
    required this.running,
    required this.connected,
  });

  final bool running;
  final bool connected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = context.appLocalizations;
    final colors = context.colorScheme;
    final active = connected && running;
    final runtime = ref.watch(runTimeProvider);
    final connecting = ref.watch(coreStatusProvider) == CoreStatus.connecting;
    return SizedBox(
      height: 340,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          gradient: desktopAccentGradient(context),
          shape: AppShape.lg,
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: CommonCard(
            radius: AppCorner.lg,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          labels.dashboard,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const CoreStatusButton(),
                    ],
                  ),
                  const Spacer(),
                  Center(
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        gradient: desktopAccentGradient(context),
                        shape: const CircleBorder(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: IconButton.filled(
                          tooltip: running ? labels.stop : labels.start,
                          onPressed: connecting
                              ? null
                              : () => ref
                                    .read(commonActionProvider.notifier)
                                    .toggleRunning(),
                          style: IconButton.styleFrom(
                            fixedSize: const Size.square(96),
                            backgroundColor: colors.surfaceContainerLow,
                            foregroundColor: colors.primary,
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(
                            Icons.power_settings_new_rounded,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    active ? labels.proxyRunning : labels.proxyStopped,
                    textAlign: TextAlign.center,
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    runtime == null
                        ? labels.start
                        : '${labels.time}: ${getTimeText(runtime)}',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(height: 12),
                    const _DesktopCurrentNodeRow(),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopCurrentNodeRow extends ConsumerWidget {
  const _DesktopCurrentNodeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorScheme;
    final groups = ref.watch(currentGroupsStateProvider).value;
    Group? selector;
    for (final group in groups) {
      if (group.type == GroupType.Selector) {
        selector = group;
        break;
      }
    }
    final node = selector?.now;
    if (node == null || node.isEmpty) {
      return const SizedBox.shrink();
    }
    final delay = ref.watch(delayProvider(proxyName: node));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              node,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          if (delay != null) ...[
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.primary.withValues(alpha: 0.14),
                shape: AppShape.full,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                child: Text(
                  '$delay ms',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopTrafficStatsRow extends ConsumerWidget {
  const _DesktopTrafficStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = context.appLocalizations;
    final colors = context.colorScheme;
    final totalTraffic = ref.watch(totalTrafficProvider);
    return CommonCard(
      radius: AppCorner.lg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: _DesktopTrafficStatItem(
                icon: Icons.arrow_downward_rounded,
                iconColor: colors.secondary,
                label: labels.download,
                value: totalTraffic.down,
              ),
            ),
            Expanded(
              child: _DesktopTrafficStatItem(
                icon: Icons.arrow_upward_rounded,
                iconColor: colors.primary,
                label: labels.upload,
                value: totalTraffic.up,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopTrafficStatItem extends StatelessWidget {
  const _DesktopTrafficStatItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final num value;

  @override
  Widget build(BuildContext context) {
    final traffic = value.traffic;
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          traffic.value,
          style: context.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          traffic.unit,
          style: context.textTheme.bodySmall?.toLighter,
        ),
      ],
    );
  }
}

class _DesktopQuickAccessPanel extends ConsumerWidget {
  const _DesktopQuickAccessPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;

    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appLocalizations.tools,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.system_update, size: 16),
                  label: Text(appLocalizations.checkUpdate),
                  onPressed: () async {
                    await globalState.safeRun(() async {
                      final data = await request.checkForUpdate();
                      if (!context.mounted) return;
                      await ref
                          .read(commonActionProvider.notifier)
                          .checkUpdateResultHandle(data: data, isUser: true);
                    }, title: appLocalizations.checkUpdate);
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.cloud_sync, size: 16),
                  label: Text(appLocalizations.backupAndRestore),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BackupAndRestore(),
                      ),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.hub, size: 16),
                  label: Text(appLocalizations.subStoreTitle),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SubStoreView(),
                      ),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.view_timeline, size: 16),
                  label: Text(appLocalizations.requests),
                  onPressed: () {
                    ref
                        .read(currentPageLabelProvider.notifier)
                        .toPage(PageLabel.requests);
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.ballot, size: 16),
                  label: Text(appLocalizations.connections),
                  onPressed: () {
                    ref
                        .read(currentPageLabelProvider.notifier)
                        .toPage(PageLabel.connections);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
