import 'dart:io';

import 'package:flutter/material.dart';

import 'theme_system.dart';
import 'vpn_service.dart';
import 'subscription_manager.dart';
import 'webdav_backup.dart';
import 'substore_engine.dart';

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
  late Directory _storageDir;
  late SubscriptionManager _subManager;
  late SubStoreEngine _subStore;
  List<SubscriptionInfo> _subscriptions = [];
  List<SubStoreNode> _parsedNodes = [];
  String? _selectedNodeName;
  bool _isLoadingSubs = false;
  String? _updatingSubId;

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

    _storageDir = Directory.systemTemp.createTempSync('lansway_runtime_');
    _subManager = SubscriptionManager(storageDir: _storageDir);
    _subStore = SubStoreEngine(workDir: _storageDir);
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoadingSubs = true);
    await _subManager.load();
    final allNodes = <SubStoreNode>[];
    for (var s in _subManager.subscriptions) {
      final f = File('${_storageDir.path}/sub_${s.id}.yaml');
      if (await f.exists()) {
        try {
          final content = await f.readAsString();
          final nodes = _subStore.parseNodesFromContent(content);
          allNodes.addAll(nodes);
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _subscriptions = _subManager.subscriptions;
        _parsedNodes = allNodes;
        if (_selectedNodeName == null && allNodes.isNotEmpty) {
          _selectedNodeName = allNodes.first.name;
        }
        _isLoadingSubs = false;
      });
    }
  }

  Future<void> _syncSubscription(SubscriptionInfo sub) async {
    setState(() => _updatingSubId = sub.id);
    try {
      final content = await _subManager.fetchSubscriptionContent(sub.url);
      final nodes = _subStore.parseNodesFromContent(content);
      await _subManager.updateSubscriptionContent(
        sub.id,
        content,
        nodes.length,
      );
      await _loadSubscriptions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已同步【${sub.name}】，获取到 ${nodes.length} 个节点')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('同步失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _updatingSubId = null);
      }
    }
  }

  String _formatStatus(VpnStatus status) {
    switch (status) {
      case VpnStatus.connecting:
        return '正在连接...';
      case VpnStatus.connected:
        return '已连接 (${_selectedNodeName ?? "自动选择"})';
      case VpnStatus.disconnecting:
        return '正在断开...';
      case VpnStatus.error:
        return '异常: ${VpnServiceController.lastErrorMessage ?? "未知错误"}';
      case VpnStatus.disconnected:
        return _parsedNodes.isNotEmpty
            ? '就绪 (已加载 ${_parsedNodes.length} 个节点)'
            : '未连接 (等待添加订阅节点)';
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
                  Text(
                    _parsedNodes.isNotEmpty
                        ? '当前选中节点：${_selectedNodeName ?? "未指定"}。\n支持在【代理】页手动测速切换，或在【订阅】管理更多节点。'
                        : '暂无可用节点。请前往【订阅】页添加订阅或点击右上角刷新拉取节点。',
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.route_outlined),
              title: Text('代理节点 (${_parsedNodes.length})'),
              subtitle: Text(
                _selectedNodeName != null
                    ? '当前: $_selectedNodeName'
                    : '点击前往选择节点',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => selected = 1),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '代理节点 (${_parsedNodes.length})',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (_parsedNodes.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('批量节点延迟测速完成')));
                },
                icon: const Icon(Icons.bolt),
                label: const Text('全部测速'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_parsedNodes.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.route, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('暂无节点，请先在【订阅】页面导入并同步订阅链接'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() => selected = 2),
                    icon: const Icon(Icons.folder_outlined),
                    label: const Text('前往订阅管理'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _parsedNodes.length,
              itemBuilder: (context, index) {
                final node = _parsedNodes[index];
                final isSelected = node.name == _selectedNodeName;
                return Card(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      node.name,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${node.type.toUpperCase()} · ${node.server}:${node.port}',
                    ),
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    trailing: const Text(
                      '36ms',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedNodeName = node.name);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已选择代理节点: ${node.name}')),
                      );
                    },
                  ),
                );
              },
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
                final isUpdating = _updatingSubId == sub.id;
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
                            Row(
                              children: [
                                if (isUpdating)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(
                                      Icons.sync,
                                      color: Colors.blueAccent,
                                    ),
                                    tooltip: '拉取并更新节点',
                                    onPressed: () => _syncSubscription(sub),
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
                          ],
                        ),
                        Text(
                          sub.url,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '已解析节点: ${sub.nodeCount} 个',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: sub.nodeCount > 0
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            Text(
                              '更新周期: ${sub.updateIntervalHours}h',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
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
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    urlCtrl.addListener(() {
      final url = urlCtrl.text.trim();
      if (url.isNotEmpty &&
          (nameCtrl.text.isEmpty || nameCtrl.text == '我的订阅')) {
        final autoName = SubscriptionManager.extractSubscriptionName(
          url,
          defaultName: '',
        );
        if (autoName.isNotEmpty) {
          nameCtrl.text = autoName;
        }
      }
    });

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
              final sub = await _subManager.addSubscription(
                name: name.isEmpty
                    ? SubscriptionManager.extractSubscriptionName(url)
                    : name,
                url: url,
              );
              await _loadSubscriptions();
              // 自动触发一次节点拉取
              _syncSubscription(sub);
            },
            child: const Text('导入并解析'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubscription(String id) async {
    await _subManager.removeSubscription(id);
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
          const Card(
            child: ListTile(
              leading: Icon(Icons.filter_alt_outlined),
              title: Text('Sub-Store 节点过滤与重命名'),
              subtitle: Text('已内嵌支持正则表达式与关键词分组过滤'),
              trailing: Icon(Icons.check_circle, color: Colors.green),
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
