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
          const tileHeight = 124.0;
          const controls = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutboundModeV2(height: tileHeight),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SystemProxyButton(height: tileHeight)),
                  SizedBox(width: 12),
                  Expanded(child: TUNButton(height: tileHeight)),
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
                  const _DesktopHeader(),
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
                          child: NetworkSpeed(height: 380, showRates: true),
                        ),
                      ],
                    )
                  else ...[
                    _DesktopConnectionCard(
                      running: running,
                      connected: connected,
                    ),
                    const SizedBox(height: 16),
                    const NetworkSpeed(height: 320, showRates: true),
                  ],
                  if (tiles) ...[
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: OutboundModeV2(height: tileHeight)),
                        SizedBox(width: 12),
                        Expanded(child: SystemProxyButton(height: tileHeight)),
                        SizedBox(width: 12),
                        Expanded(child: TUNButton(height: tileHeight)),
                        SizedBox(width: 12),
                        Expanded(child: NetworkDetection(height: tileHeight)),
                        SizedBox(width: 12),
                        Expanded(child: IntranetIP(height: tileHeight)),
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

/// Page header: title with subtitle on the left, status capsule and the
/// refresh / update actions on the right, mirroring the prototype.
class _DesktopHeader extends ConsumerWidget {
  const _DesktopHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = context.appLocalizations;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showRates = constraints.maxWidth >= 760;
        final title = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                labels.dashboard,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels.dashboardSubtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
        final refreshButton = OutlinedButton.icon(
          onPressed: () =>
              ref.read(networkDetectionProvider.notifier).startCheck(),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            side: BorderSide(color: context.colorScheme.outlineVariant),
            foregroundColor: context.colorScheme.onSurface,
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(labels.refresh),
        );
        final updateButton = FilledButton.icon(
          onPressed: () async {
            await globalState.safeRun(() async {
              final data = await request.checkForUpdate();
              if (!context.mounted) return;
              await ref
                  .read(commonActionProvider.notifier)
                  .checkUpdateResultHandle(data: data, isUser: true);
            }, title: labels.checkUpdate);
          },
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          icon: const Icon(Icons.system_update_alt_rounded, size: 18),
          label: Text(labels.checkUpdate),
        );
        if (constraints.maxWidth >= 1000) {
          return Row(
            children: [
              title,
              const SizedBox(width: 16),
              _DesktopStatusCapsule(showRates: showRates),
              const SizedBox(width: 12),
              refreshButton,
              const SizedBox(width: 8),
              updateButton,
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                title,
                const SizedBox(width: 12),
                const _DesktopStatusCapsule(showRates: false),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [refreshButton, const SizedBox(width: 8), updateButton],
            ),
          ],
        );
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
              icon: Icons.south_rounded,
              tint: kDashboardDownTint,
              value: traffic?.down,
            ),
            const SizedBox(width: 12),
            _RateText(
              icon: Icons.north_rounded,
              tint: kDashboardUpTint,
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

/// The left "connection console" card: big power toggle, current node and
/// runtime / mode / port summary, following the prototype layout.
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
    final mode = ref.watch(patchClashConfigProvider.select((s) => s.mode));
    final port = ref.watch(patchClashConfigProvider.select((s) => s.mixedPort));
    return SizedBox(
      height: 380,
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
                        child: InfoHeader(
                          padding: EdgeInsets.zero,
                          info: Info(
                            label: labels.connectionConsole,
                            iconData: Icons.lan_rounded,
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
                        shadows: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.35),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: IconButton.filled(
                          tooltip: running ? labels.stop : labels.start,
                          onPressed: connecting
                              ? null
                              : () => ref
                                    .read(commonActionProvider.notifier)
                                    .toggleRunning(),
                          style: IconButton.styleFrom(
                            fixedSize: const Size.square(112),
                            backgroundColor: colors.surfaceContainerLow,
                            foregroundColor: colors.primary,
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(
                            Icons.power_settings_new_rounded,
                            size: 46,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    connecting
                        ? labels.connecting
                        : active
                        ? labels.connected
                        : labels.proxyStopped,
                    textAlign: TextAlign.center,
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (active)
                    const _DesktopCurrentNodeRow()
                  else
                    Text(
                      labels.start,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ConsoleStat(
                          label: labels.runtimeLabel,
                          value: runtime == null ? '—' : getTimeText(runtime),
                        ),
                      ),
                      Expanded(
                        child: _ConsoleStat(
                          label: labels.outboundMode,
                          value: mode.label,
                        ),
                      ),
                      Expanded(
                        child: _ConsoleStat(
                          label: labels.portLabel,
                          value: ':$port',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsoleStat extends StatelessWidget {
  const _ConsoleStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
