import 'package:bfclash/common/common.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/common/desktop_style.dart';
import 'package:bfclash/views/about.dart';
import 'package:bfclash/views/resources.dart';
import 'package:bfclash/widgets/locale_setting_item.dart';
import 'package:bfclash/views/application_setting.dart';
import 'package:bfclash/views/backup_and_restore.dart';
import 'package:bfclash/views/config/config.dart';
import 'package:bfclash/views/config/advanced.dart';
import 'package:bfclash/views/developer.dart';
import 'package:bfclash/views/hotkey.dart';
import 'package:bfclash/views/sub_store.dart';
import 'package:bfclash/views/theme.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class DesktopToolsView extends ConsumerWidget {
  const DesktopToolsView({super.key});

  void _open(BuildContext context, Widget target) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => target));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = context.appLocalizations;
    return CommonScaffold(
      title: labels.tools,
      body: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _ToolCard(
                  title: labels.checkUpdate,
                  subtitle: _versionLabel(),
                  icon: Icons.system_update_alt_rounded,
                  prominent: true,
                  onTap: () => globalState.safeRun(() async {
                    final data = await request.checkForUpdate();
                    if (!context.mounted) return;
                    await ref
                        .read(commonActionProvider.notifier)
                        .checkUpdateResultHandle(data: data, isUser: true);
                  }, title: labels.checkUpdate),
                ),
                _ToolCard(
                  title: labels.backupAndRestore,
                  subtitle: labels.backupAndRestoreDesc,
                  icon: Icons.cloud_sync_outlined,
                  onTap: () => _open(context, const BackupAndRestore()),
                ),
              ];
              if (constraints.maxWidth < 720) {
                return Column(
                  children: [cards[0], const SizedBox(height: 16), cards[1]],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 20),
                  Expanded(child: cards[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _ToolCard(
            title: labels.subStoreTitle,
            subtitle: labels.subStoreLocalModeDesc,
            icon: Icons.hub_outlined,
            onTap: () => _open(context, const SubStoreView()),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ActionChip(
                avatar: const Icon(Icons.view_timeline, size: 18),
                label: Text(labels.requests),
                onPressed: () => ref
                    .read(currentPageLabelProvider.notifier)
                    .toPage(PageLabel.requests),
              ),
              ActionChip(
                avatar: const Icon(Icons.ballot_outlined, size: 18),
                label: Text(labels.connections),
                onPressed: () => ref
                    .read(currentPageLabelProvider.notifier)
                    .toPage(PageLabel.connections),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListHeader(title: labels.settings),
          const LocaleSettingItem(),
          LayoutBuilder(
            builder: (context, constraints) {
              final entries =
                  <
                    ({
                      String title,
                      String subtitle,
                      IconData icon,
                      Widget target,
                    })
                  >[
                    (
                      title: labels.resources,
                      subtitle: labels.resources,
                      icon: Icons.storage_outlined,
                      target: const ResourcesView(),
                    ),
                    (
                      title: labels.basicConfig,
                      subtitle: labels.basicConfigDesc,
                      icon: Icons.edit_note,
                      target: const ConfigView(),
                    ),
                    (
                      title: labels.advancedConfig,
                      subtitle: labels.advancedConfigDesc,
                      icon: Icons.build_circle_outlined,
                      target: const AdvancedConfigView(),
                    ),
                    (
                      title: labels.application,
                      subtitle: labels.applicationDesc,
                      icon: Icons.settings_outlined,
                      target: const ApplicationSettingView(),
                    ),
                    (
                      title: labels.theme,
                      subtitle: labels.themeDesc,
                      icon: Icons.palette_outlined,
                      target: const ThemeView(),
                    ),
                    if (system.isDesktop)
                      (
                        title: labels.hotkeyManagement,
                        subtitle: labels.hotkeyManagementDesc,
                        icon: Icons.keyboard_outlined,
                        target: const HotKeyView(),
                      ),
                    (
                      title: labels.about,
                      subtitle: '${labels.about} BfClash',
                      icon: Icons.info_outline,
                      target: const AboutView(),
                    ),
                    (
                      title: labels.developerMode,
                      subtitle: labels.developerModeDesc,
                      icon: Icons.developer_mode,
                      target: const DeveloperView(),
                    ),
                  ];
              final width = constraints.maxWidth >= 1000
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (final entry in entries)
                    SizedBox(
                      width: width,
                      child: _ToolCard(
                        title: entry.title,
                        subtitle: entry.subtitle,
                        icon: entry.icon,
                        compact: true,
                        onTap: () => _open(context, entry.target),
                      ),
                    ),
                  if (system.isWindows)
                    SizedBox(
                      width: width,
                      child: _ToolCard(
                        title: labels.loopback,
                        subtitle: labels.loopbackDesc,
                        icon: Icons.lock_open,
                        compact: true,
                        onTap: () =>
                            globalState.safeRun<void>(launchLoopbackTool),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _versionLabel() {
  try {
    return 'v${globalState.packageInfo.version}';
  } on Error {
    return 'BfClash';
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.prominent = false,
    this.compact = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool prominent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      radius: AppCorner.lg,
      onPressed: onTap,
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 24),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 10 : 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: desktopAccentGradient(context).colors
                      .map((color) => color.withValues(alpha: 0.14))
                      .toList(),
                ),
                borderRadius: AppRadius.md,
              ),
              child: Icon(
                icon,
                size: compact ? 22 : 30,
                color: context.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style:
                        (compact
                                ? context.textTheme.titleSmall
                                : context.textTheme.titleLarge)
                            ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 20),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: prominent
                            ? desktopAccentGradient(context)
                            : null,
                        borderRadius: AppRadius.sm,
                        border: prominent
                            ? null
                            : Border.all(
                                color: context.colorScheme.outlineVariant,
                              ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Text(
                          title,
                          style: context.textTheme.labelLarge?.copyWith(
                            color: prominent
                                ? const Color(0xFF10101A)
                                : context.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (compact) const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}
