import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubStoreView extends ConsumerStatefulWidget {
  const SubStoreView({super.key});

  @override
  ConsumerState<SubStoreView> createState() => _SubStoreViewState();
}

class _SubStoreViewState extends ConsumerState<SubStoreView> {
  bool _isLocalMode = false;
  final TextEditingController _remoteUrlController = TextEditingController(
    text: 'http://170.9.31.29:3001',
  );

  @override
  void dispose() {
    _remoteUrlController.dispose();
    super.dispose();
  }

  String get _currentBackendUrl {
    if (_isLocalMode) {
      return 'http://127.0.0.1:3000';
    }
    return _remoteUrlController.text.trim();
  }

  void _openSubStoreWeb() {
    final backend = _currentBackendUrl;
    if (backend.isEmpty) {
      context.showNotifier('请先输入有效的后端地址');
      return;
    }
    // Automatically inject api parameter so official web connects seamlessly without manual configuration errors
    final uri = Uri.parse('https://sub-store.vercel.app')
        .replace(queryParameters: {'api': backend});
    dialogs.openUrl(uri.toString());
  }

  void _openDirectBackend() {
    final backend = _currentBackendUrl;
    if (backend.isEmpty) return;
    dialogs.openUrl(backend);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final items = [
      ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.hub,
                    color: Color(0xFF818CF8),
                    size: 32,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sub-Store 订阅管理',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '双模驱动 · 本地自建与远程 VPS 订阅管理枢纽',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                '💡 支持双模运行：既可直接连接远程自建的 VPS 后端，亦支持手机本地独立运行。打开 Web 控制台时将自动免配注入后端 API，告别手动填写与网络报错。',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ...generateSection(
        title: '运行模式选择',
        items: [
          ListItem(
            title: const Text('模式切换'),
            subtitle: Text(
              _isLocalMode ? '当前：本地单机模式 (127.0.0.1:3000)' : '当前：远程 VPS 模式',
            ),
            leading: Icon(_isLocalMode ? Icons.phone_android : Icons.cloud),
            trailing: Switch(
              value: _isLocalMode,
              onChanged: (val) {
                setState(() {
                  _isLocalMode = val;
                });
              },
            ),
          ),
          if (!_isLocalMode)
            ListItem(
              title: const Text('远程 VPS 后端地址'),
              subtitle: Text(
                _remoteUrlController.text.isEmpty
                    ? '未配置'
                    : _remoteUrlController.text,
              ),
              leading: const Icon(Icons.dns),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final controller = TextEditingController(text: _remoteUrlController.text);
                final res = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('修改远程 VPS 后端地址'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: '如: http://170.9.31.29:3001',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
                if (res != null && res.isNotEmpty) {
                  setState(() {
                    _remoteUrlController.text = res;
                  });
                }
              },
            )
          else
            ListItem(
              title: const Text('本地内置服务状态'),
              subtitle: const Text('本地运行环境 (端口: 3000)'),
              leading: const Icon(Icons.memory, color: Colors.green),
              trailing: const Text(
                '准备就绪',
                style: TextStyle(color: Colors.green),
              ),
            ),
        ],
      ),
      ...generateSection(
        title: '快捷打开与控制',
        items: [
          ListItem(
            title: const Text('打开 Web 管理控制台 (自动注入后端)'),
            subtitle: const Text('一键直达官方 Web 控制台，免除手动配置'),
            leading: const Icon(
              Icons.open_in_browser,
              color: Color(0xFF6366F1),
            ),
            trailing: const Icon(Icons.launch),
            onTap: _openSubStoreWeb,
          ),
          ListItem(
            title: const Text('直连后端原生面板'),
            subtitle: Text(_currentBackendUrl),
            leading: const Icon(Icons.link),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openDirectBackend,
          ),
        ],
      ),
      ...generateSection(
        title: '订阅回填',
        items: [
          ListItem(
            title: const Text('从 Sub-Store 导入订阅'),
            subtitle: const Text('在 Sub-Store 复制产物链接后，前往「配置」添加即可'),
            leading: const Icon(Icons.download),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.showNotifier('请在 Sub-Store 复制产物链接后，前往「配置」页面新建导入');
            },
          ),
        ],
      ),
    ];

    return CommonScaffold(
      title: 'Sub-Store',
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, index) => items[index],
        padding: const EdgeInsets.only(top: 16, bottom: 24),
      ),
    );
  }
}
