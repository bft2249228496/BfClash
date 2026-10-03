import 'dart:io';

import 'package:bfclash/common/common.dart';
import 'package:bfclash/views/about.dart';
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
import 'package:path/path.dart' show dirname, join;

class DesktopToolsView extends ConsumerStatefulWidget {
  const DesktopToolsView({super.key});

  @override
  ConsumerState<DesktopToolsView> createState() => _DesktopToolsViewState();
}

class _DesktopToolsViewState extends ConsumerState<DesktopToolsView> {
  Widget _selectedWidget = const BackupAndRestore();
  String _selectedTitle = '';

  void _selectView(String title, Widget view) {
    setState(() {
      _selectedTitle = title;
      _selectedWidget = view;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    if (_selectedTitle.isEmpty) {
      _selectedTitle = appLocalizations.backupAndRestore;
    }

    return CommonScaffold(
      title: appLocalizations.tools,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 950;

          final listMenu = ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              ListHeader(title: appLocalizations.settings),
              _buildMenuItem(
                title: appLocalizations.backupAndRestore,
                subtitle: appLocalizations.backupAndRestoreDesc,
                icon: Icons.cloud_sync,
                target: const BackupAndRestore(),
                isWide: isWide,
              ),
              _buildMenuItem(
                title: appLocalizations.subStoreTitle,
                subtitle: appLocalizations.subStoreLocalModeDesc,
                icon: Icons.hub,
                iconColor: const Color(0xFF818CF8),
                target: const SubStoreView(),
                isWide: isWide,
              ),
              _buildMenuItem(
                title: appLocalizations.basicConfig,
                subtitle: appLocalizations.basicConfigDesc,
                icon: Icons.edit_note,
                target: const ConfigView(),
                isWide: isWide,
              ),
              _buildMenuItem(
                title: appLocalizations.advancedConfig,
                subtitle: appLocalizations.advancedConfigDesc,
                icon: Icons.build_circle_outlined,
                target: const AdvancedConfigView(),
                isWide: isWide,
              ),
              _buildMenuItem(
                title: appLocalizations.application,
                subtitle: appLocalizations.applicationDesc,
                icon: Icons.settings,
                target: const ApplicationSettingView(),
                isWide: isWide,
              ),
              _buildMenuItem(
                title: appLocalizations.theme,
                subtitle: appLocalizations.themeDesc,
                icon: Icons.palette_outlined,
                target: const ThemeView(),
                isWide: isWide,
              ),
              if (system.isDesktop)
                _buildMenuItem(
                  title: appLocalizations.hotkeyManagement,
                  subtitle: appLocalizations.hotkeyManagementDesc,
                  icon: Icons.keyboard,
                  target: const HotKeyView(),
                  isWide: isWide,
                ),
              if (system.isWindows)
                ListItem(
                  leading: const Icon(Icons.lock_open),
                  title: Text(appLocalizations.loopback),
                  subtitle: Text(appLocalizations.loopbackDesc),
                  trailing: const Icon(Icons.arrow_outward, size: 18),
                  onTap: () {
                    windows?.runas(
                      '"${join(dirname(Platform.resolvedExecutable), "EnableLoopback.exe")}"',
                      '',
                    );
                  },
                ),
              ListHeader(title: appLocalizations.other),
              _buildMenuItem(
                title: appLocalizations.about,
                subtitle: '${appLocalizations.about} BfClash',
                icon: Icons.info_outline,
                target: const AboutView(),
                isWide: isWide,
              ),
              _buildMenuItem(
                title: appLocalizations.developerMode,
                subtitle: '调试与高级状态监测',
                icon: Icons.developer_mode,
                target: const DeveloperView(),
                isWide: isWide,
              ),
            ],
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 380,
                  child: listMenu,
                ),
                VerticalDivider(
                  width: 1,
                  color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: FocusTraversalGroup(
                    child: _selectedWidget,
                  ),
                ),
              ],
            );
          }

          return listMenu;
        },
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    required Widget target,
    required bool isWide,
  }) {
    final isSelected = isWide && _selectedTitle == title;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? context.colorScheme.secondaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListItem(
          leading: Icon(icon, color: iconColor ?? context.colorScheme.primary),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? context.colorScheme.onSecondaryContainer : null,
            ),
          ),
          subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: isWide
              ? (isSelected
                  ? Icon(Icons.chevron_right, color: context.colorScheme.primary)
                  : null)
              : const Icon(Icons.chevron_right),
          onTap: () {
            if (isWide) {
              _selectView(title, target);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => target),
              );
            }
          },
        ),
      ),
    );
  }
}
