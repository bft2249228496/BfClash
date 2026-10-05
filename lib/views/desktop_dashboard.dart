import 'package:bfclash/common/channel_config.dart';
import 'package:bfclash/common/common.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/views/dashboard/widgets/core_status_button.dart';
import 'package:bfclash/views/dashboard/widgets/network_speed.dart';
import 'package:bfclash/views/dashboard/widgets/outbound_mode.dart';
import 'package:bfclash/views/dashboard/widgets/start_button.dart';
import 'package:bfclash/views/dashboard/widgets/traffic_usage.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class DesktopDashboardView extends ConsumerWidget {
  const DesktopDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coreStatus = ref.watch(coreStatusProvider);
    final isConnected = coreStatus == CoreStatus.connected;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1050;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _DesktopTopStatusBar(isConnected: isConnected),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                if (isWide) ...[
                  const SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _DesktopHeroActionCard(),
                              SizedBox(height: 16),
                              OutboundMode(),
                              SizedBox(height: 16),
                              NetworkSpeed(),
                            ],
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TrafficUsage(),
                              SizedBox(height: 16),
                              _DesktopQuickAccessPanel(),
                              SizedBox(height: 16),
                              _DesktopSystemEnvironmentCard(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DesktopHeroActionCard(),
                        SizedBox(height: 16),
                        OutboundMode(),
                        SizedBox(height: 16),
                        NetworkSpeed(),
                        SizedBox(height: 16),
                        TrafficUsage(),
                        SizedBox(height: 16),
                        _DesktopQuickAccessPanel(),
                        SizedBox(height: 16),
                        _DesktopSystemEnvironmentCard(),
                      ],
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DesktopTopStatusBar extends ConsumerWidget {
  const _DesktopTopStatusBar({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final runTime = ref.watch(runTimeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isConnected
                  ? Colors.green.withValues(alpha: 0.15)
                  : context.colorScheme.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isConnected
                    ? Colors.green.withValues(alpha: 0.4)
                    : context.colorScheme.error.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? Colors.green : context.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'Core Active' : 'Core Idle',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isConnected ? Colors.green : context.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'BfClash Desktop Edition',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (runTime != null)
            Text(
              'Uptime: ${DateTime.fromMillisecondsSinceEpoch(runTime).show}',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'JetBrainsMono',
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 16),
          IconButton(
            tooltip: appLocalizations.checkUpdate,
            icon: const Icon(Icons.sync, size: 20),
            onPressed: () {
              ref.read(commonActionProvider.notifier).autoCheckUpdate();
            },
          ),
        ],
      ),
    );
  }
}

class _DesktopHeroActionCard extends StatelessWidget {
  const _DesktopHeroActionCard();

  @override
  Widget build(BuildContext context) {
    return const CommonCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(child: StartButton()),
            SizedBox(width: 16),
            CoreStatusButton(),
          ],
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

class _DesktopSystemEnvironmentCard extends StatelessWidget {
  const _DesktopSystemEnvironmentCard();

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.desktop_windows, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Windows Desktop Environment',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'TUN 模式驱动: WinTUN (${WindowsChannelConfig.helperServiceName} 托管)',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'UWP 回环豁免: 搭载内置 EnableLoopback.exe 提权调用',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '备份与还原支持: WebDAV 远程链路与本地 .bfclash / .zip 导入导出双模已就绪',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
