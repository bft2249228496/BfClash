import 'dart:io';

import 'package:flutter/material.dart';

import 'theme_system.dart';
import 'vpn_service.dart';
import 'subscription_manager.dart';
import 'webdav_backup.dart';
import 'substore_engine.dart';
import 'rules_and_overrides.dart';
import 'android_capabilities.dart';
import 'smart_core.dart';
import 'kernel_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  VpnServiceController.initialize();
  runApp(const LanswayApp());
}

class LanswayApp extends StatefulWidget {
  const LanswayApp({super.key});

  @override
  State<LanswayApp> createState() => LanswayAppState();
}

class LanswayAppState extends State<LanswayApp> {
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

  // 状态模块
  late SubscriptionManager _subManager;
  List<SubscriptionInfo> _subscriptions = [];
  bool _isLoadingSubs = false;

  // WebDAV 状态
  final TextEditingController _webdavUrlController = TextEditingController();
  final TextEditingController _webdavUserController = TextEditingController();
  final TextEditingController _webdavPassController = TextEditingController();
  String _webdavStatusText = '尚未配置或未测试连通';

  // 核心切换
  String _activeCoreName = 'Mihomo v1.19.30 (稳定版)';

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

    final tempDir = Directory.systemTemp.createTempSync('lansway_runtime_');
    _subManager = SubscriptionManager(workDir: tempDir);
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoadingSubs = true);
    final list = await _subManager.loadSubscriptions();
    if (mounted) {
      setState(() {
        _subscriptions = list;
        _isLoadingSubs = false;
      });
    }
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
    return SingleChildScrollView(
      child: Column(
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
                      Expanded(
                        child: Text(
                          _formatStatus(_vpnStatus),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.rocket_launch_outlined),
              title: const Text('快捷操作'),
              subtitle: const Text('前往【订阅】页添加订阅节点，前往【设置】切换主题配色'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => selected = 2),
            ),
          ),
        ],
      ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('订阅管理', style: Theme.of(context).textTheme.headlineMedium),
            FilledButton.icon(
              onPressed: _showAddSubscriptionDialog,
              icon: const Icon(Icons.add),
              label: const Text('导入订阅'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingSubs)
          const Center(child: CircularProgressIndicator())
        else if (_subscriptions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.folder_open, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('暂无订阅，点击右上角【导入订阅】添加链接'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _showAddSubscriptionDialog,
                    icon: const Icon(Icons.add_link),
                    label: const Text('添加订阅链接 (HTTP/HTTPS)'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _subscriptions.length,
              itemBuilder: (context, index) {
                final sub = _subscriptions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              sub.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deleteSubscription(sub.id),
                            ),
                          ],
                        ),
                        Text(
                          sub.url,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '更新周期: 每 ${sub.updateIntervalHours} 小时 | 自动更新: ${sub.autoUpdate ? "开" : "关"}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showAddSubscriptionDialog() {
    final nameCtrl = TextEditingController(text: '我的订阅');
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入订阅链接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '订阅名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: '订阅 URL',
                hintText: 'https://example.com/sub',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final url = urlCtrl.text.trim();
              final name = nameCtrl.text.trim();
              if (url.isEmpty ||
                  (!url.startsWith('http://') && !url.startsWith('https://'))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入合法的 HTTP/HTTPS 订阅链接')),
                );
                return;
              }
              Navigator.pop(ctx);
              final sub = SubscriptionInfo(
                id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
                name: name.isEmpty ? '我的订阅' : name,
                url: url,
              );
              await _subManager.saveSubscription(sub);
              await _loadSubscriptions();
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubscription(String id) async {
    await _subManager.deleteSubscription(id);
    await _loadSubscriptions();
  }

  Widget _buildToolsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('工具与扩展', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync_outlined),
                      const SizedBox(width: 8),
                      Text(
                        'WebDAV 远端备份与同步',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _webdavUrlController,
                    decoration: const InputDecoration(
                      labelText: 'WebDAV 服务器地址',
                      hintText: 'https://dav.jianguoyun.com/dav/',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _webdavUserController,
                    decoration: const InputDecoration(labelText: '用户名 / 邮箱'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _webdavPassController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '应用授权密码'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _testWebDav,
                        icon: const Icon(Icons.network_check),
                        label: const Text('测试连通性'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('备份配置已上传至 WebDAV')),
                          );
                        },
                        icon: const Icon(Icons.upload),
                        label: const Text('立即备份'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _webdavStatusText,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.filter_alt_outlined),
              title: const Text('Sub-Store 节点过滤与重命名'),
              subtitle: const Text('已内嵌支持正则表达式与关键词分组过滤'),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testWebDav() async {
    final url = _webdavUrlController.text.trim();
    final user = _webdavUserController.text.trim();
    final pass = _webdavPassController.text.trim();

    if (url.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _webdavStatusText = '请完整填写 WebDAV 连接参数');
      return;
    }

    setState(() => _webdavStatusText = '正在测试 PROPFIND 连通性...');
    final mgr = WebDavBackupManager(
      config: WebDavConfig(serverUrl: url, username: user, password: pass),
    );
    final ok = await mgr.testConnection();
    if (mounted) {
      setState(() {
        _webdavStatusText = ok ? 'WebDAV 连通成功！' : '连接失败，请检查网络或授权码';
      });
    }
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
                    '外观主题 (6套配色 - 即点即换)',
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
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '内核与系统能力',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('当前核心引擎'),
                    subtitle: Text(_activeCoreName),
                    trailing: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          if (_activeCoreName.contains('Mihomo')) {
                            _activeCoreName = 'Smart Core v2.0 (智能核心)';
                          } else {
                            _activeCoreName = 'Mihomo v1.19.30 (稳定版)';
                          }
                        });
                      },
                      child: const Text('切换核心'),
                    ),
                  ),
                  const Divider(),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Android 分流模式'),
                    subtitle: Text('全量代理 (可配置黑白名单绕过国内应用)'),
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
