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
  final TextEditingController _urlController = TextEditingController(
    text: 'http://127.0.0.1:3000',
  );

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _openInBrowser(String url) {
    if (url.trim().isEmpty) return;
    dialogs.openUrl(url.trim());
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
                      '高级订阅组合、节点清洗与分流定制枢纽',
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
                '💡 提示：Sub-Store 是强大的高级订阅管理工具。您可以在本地（如 Termux / 独立后台）或远端服务器启动服务，在此快速调起配置并一键回填至 BfClash。',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ...generateSection(
        title: '服务连接与控制',
        items: [
          ListItem(
            title: const Text('服务后端地址'),
            subtitle: Text(_urlController.text),
            leading: const Icon(Icons.link),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              _openInBrowser(_urlController.text);
            },
          ),
          ListItem(
            title: const Text('官方在线 Web 前端'),
            subtitle: const Text('https://sub-store.vercel.app'),
            leading: const Icon(Icons.public),
            trailing: const Icon(Icons.launch),
            onTap: () {
              _openInBrowser('https://sub-store.vercel.app');
            },
          ),
        ],
      ),
      ...generateSection(
        title: '快捷通道 (一键回填)',
        items: [
          ListItem(
            title: const Text('从 Sub-Store 产物链接导入'),
            subtitle: const Text('在浏览器中复制 Sub-Store 生成的订阅链接，去「配置」页面添加即可'),
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
