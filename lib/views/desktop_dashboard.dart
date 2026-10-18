import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/desktop_style.dart';
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
                  const SizedBox(height: 20),
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
