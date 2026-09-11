import 'package:flutter/material.dart';

import 'theme_system.dart';
import 'vpn_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  VpnServiceController.initialize();
  runApp(const LanswayApp());
}

class LanswayApp extends StatefulWidget {
  const LanswayApp({super.key});

  static _LanswayAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_LanswayAppState>();

  @override
  State<LanswayApp> createState() => _LanswayAppState();
}

class _LanswayAppState extends State<LanswayApp> {
  String _currentThemeId = 'gemini';
  ThemeMode _themeMode = ThemeMode.dark;

  void setTheme(String themeId) {
    setState(() => _currentThemeId = themeId);
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = AppThemeSystem.getTheme(_currentThemeId);

    return MaterialApp(
      title: '澜序 · Lansway',
      debugShowCheckedModeBanner: false,
      theme: themeConfig.toThemeData(Brightness.light),
      darkTheme: themeConfig.toThemeData(Brightness.dark),
      themeMode: _themeMode,
      home: ClientShell(
        currentThemeId: _currentThemeId,
        themeMode: _themeMode,
        onThemeChanged: setTheme,
        onThemeModeChanged: setThemeMode,
      ),
    );
  }
}

class ClientShell extends StatefulWidget {
  final String currentThemeId;
  final ThemeMode themeMode;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const ClientShell({
    super.key,
    required this.currentThemeId,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onThemeModeChanged,
  });

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int selected = 0;
  static const labels = ['概览', '代理', '订阅', '工具', '设置'];
  static const icons = [
    Icons.home_outlined,
    Icons.route_outlined,
    Icons.folder_outlined,
    Icons.grid_view_outlined,
    Icons.settings_outlined,
  ];

  VpnStatus _vpnStatus = VpnStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _vpnStatus = VpnServiceController.currentStatus;
    VpnServiceController.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _vpnStatus = status;
        });
      }
    });
  }

  String _formatStatus(VpnStatus status) {
    switch (status) {
      case VpnStatus.connecting:
        return '正在连接...';
      case VpnStatus.connected:
        return '已连接';
      case VpnStatus.disconnecting:
        return '正在断开...';
      case VpnStatus.error:
        return '异常: ${VpnServiceController.lastErrorMessage ?? "未知错误"}';
      case VpnStatus.disconnected:
      default:
        return '未连接 (代理服务尚未接入)';
    }
  }

  Widget _buildBody() {
    switch (selected) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildProxiesTab();
      case 2:
        return _buildSubscriptionsTab();
      case 3:
        return _buildToolsTab();
      case 4:
        return _buildSettingsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('概览', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _vpnStatus == VpnStatus.connected
                          ? Icons.shield
                          : Icons.shield_outlined,
                      color: _vpnStatus == VpnStatus.connected
                          ? Colors.greenAccent
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatStatus(_vpnStatus),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '代理服务尚未接入。完成 Android 内核验证后开放连接。未接入内核前不启动空 TUN，避免阻断系统网络。',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProxiesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('代理', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('导入真实配置后，在这里管理代理组与节点切换。杜绝使用模拟假数据填充。'),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('订阅', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('支持 URL/文件导入、解析、自动更新与失败回退。订阅凭据存入私有安全沙箱。'),
          ),
        ),
      ],
    );
  }

  Widget _buildToolsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('工具', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('WebDAV 备份同步、Sub-Store 内嵌运行时、YAML/JS 覆写与日志导出。'),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('设置', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '外观主题 (6套配色)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppThemeSystem.themes.map((t) {
                      final isSelected = t.id == widget.currentThemeId;
                      return ChoiceChip(
                        label: Text('${t.name} (${t.subtitle})'),
                        selected: isSelected,
                        onSelected: (_) => widget.onThemeChanged(t.id),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 32),
                  Text('明暗模式', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('跟随系统'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('浅色'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('深色'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {widget.themeMode},
                    onSelectionChanged: (set) =>
                        widget.onThemeModeChanged(set.first),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('澜序 · Lansway'),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              _formatStatus(_vpnStatus),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    ),
    body: Padding(padding: const EdgeInsets.all(24), child: _buildBody()),
    bottomNavigationBar: NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (value) => setState(() => selected = value),
      destinations: List.generate(
        labels.length,
        (index) => NavigationDestination(
          icon: Icon(icons[index]),
          label: labels[index],
        ),
      ),
    ),
  );
}
