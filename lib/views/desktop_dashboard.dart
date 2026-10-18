import 'package:bfclash/common/common.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/providers/providers.dart' hide NetworkDetection;
import 'package:bfclash/state.dart';
import 'package:bfclash/views/dashboard/widgets/core_status_button.dart';
import 'package:bfclash/views/dashboard/widgets/network_speed.dart';
import 'package:bfclash/views/dashboard/widgets/network_detection.dart';
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
              SizedBox(height: 16),
              NetworkSpeed(),
            ],
          );
          const insights = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NetworkDetection(),
              SizedBox(height: 12),
              TrafficUsage(),
            ],
          );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                children: [
                  const _DesktopTopStatusBar(),
                  const SizedBox(height: 24),
                  _DesktopConnectionCard(
                    running: running,
                    connected: connected,
                  ),
                  const SizedBox(height: 20),
                  if (wide)
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: controls),
                        SizedBox(width: 16),
                        Expanded(flex: 5, child: insights),
                      ],
                    )
                  else ...[
                    const NetworkDetection(),
                    const SizedBox(height: 12),
                    controls,
                    const SizedBox(height: 12),
                    const TrafficUsage(),
                  ],
                  const SizedBox(height: 16),
                  const _DesktopQuickAccessPanel(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DesktopTopStatusBar extends ConsumerWidget {
  const _DesktopTopStatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = context.appLocalizations;
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
        IconButton.outlined(
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
    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: ShapeDecoration(
                    color: active
                        ? colors.primaryContainer.withValues(alpha: 0.55)
                        : colors.surfaceContainerHighest,
                    shape: AppShape.md,
                  ),
                  child: Icon(
                    active ? Icons.shield_rounded : Icons.shield_outlined,
                    color: active ? colors.primary : colors.onSurfaceVariant,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active ? labels.proxyRunning : labels.proxyStopped,
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        runtime == null
                            ? labels.start
                            : '${labels.time}: ${getTimeText(runtime)}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final action = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoreStatusButton(),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(commonActionProvider.notifier).toggleRunning(),
                  icon: Icon(
                    running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20,
                  ),
                  label: Text(running ? labels.stop : labels.start),
                ),
              ],
            );
            if (constraints.maxWidth < 500) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 20),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 20),
                action,
              ],
            );
          },
        ),
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
                    ref
                        .read(currentPageLabelProvider.notifier)
                        .toPage(PageLabel.tools);
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.hub, size: 16),
                  label: Text(appLocalizations.subStoreTitle),
                  onPressed: () {
                    ref
                        .read(currentPageLabelProvider.notifier)
                        .toPage(PageLabel.tools);
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
