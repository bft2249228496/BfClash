import 'dart:io';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart';

class SubStoreView extends ConsumerStatefulWidget {
  const SubStoreView({super.key});

  @override
  ConsumerState<SubStoreView> createState() => _SubStoreViewState();
}

class _SubStoreViewState extends ConsumerState<SubStoreView> {
  bool _isLocalMode = true;
  final TextEditingController _remoteUrlController = TextEditingController();

  // Local Merge Controllers
  final TextEditingController _profileNameController = TextEditingController(
    text: '聚合订阅',
  );
  final TextEditingController _includeKeywordController =
      TextEditingController();
  final TextEditingController _excludeKeywordController = TextEditingController(
    text: '官网|到期|剩余|流量|重置',
  );

  final Set<int> _selectedProfileIds = {};
  bool _isMerging = false;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final saved = await preferences.getSubStoreRemoteUrl();
    if (mounted && saved.isNotEmpty) {
      setState(() {
        _remoteUrlController.text = saved;
      });
    }
  }

  @override
  void dispose() {
    _remoteUrlController.dispose();
    _profileNameController.dispose();
    _includeKeywordController.dispose();
    _excludeKeywordController.dispose();
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
      context.showNotifier('请先输入有效的远程 VPS 后端地址');
      return;
    }
    final uri = Uri.parse(
      'https://sub-store.vercel.app',
    ).replace(queryParameters: {'api': backend});
    dialogs.openUrl(uri.toString());
  }

  void _openDirectBackend() {
    final backend = _currentBackendUrl;
    if (backend.isEmpty) {
      context.showNotifier('请先输入有效的后端地址');
      return;
    }
    dialogs.openUrl(backend);
  }

  Future<void> _executeMerge(List<Profile> allProfiles) async {
    if (_selectedProfileIds.length < 2) {
      context.showNotifier('请至少勾选两个已添加的配置进行合并');
      return;
    }

    final newName = _profileNameController.text.trim().isEmpty
        ? '聚合订阅'
        : _profileNameController.text.trim();
    final includeRegexStr = _includeKeywordController.text.trim();
    final excludeRegexStr = _excludeKeywordController.text.trim();

    RegExp? includeRegex;
    RegExp? excludeRegex;
    try {
      if (includeRegexStr.isNotEmpty) {
        includeRegex = RegExp(includeRegexStr, caseSensitive: false);
      }
      if (excludeRegexStr.isNotEmpty) {
        excludeRegex = RegExp(excludeRegexStr, caseSensitive: false);
      }
    } catch (e) {
      context.showNotifier('正则表达式格式错误: $e');
      return;
    }

    setState(() {
      _isMerging = true;
    });

    try {
      final List<Map<dynamic, dynamic>> mergedProxies = [];
      final Set<String> seenNames = {};

      for (final profileId in _selectedProfileIds) {
        final profilePath = await appPath.getProfilePath(profileId.toString());
        final file = File(profilePath);
        if (!await file.exists()) continue;

        final content = await file.readAsString();
        final doc = loadYaml(content);
        if (doc is! Map) continue;

        final rawProxies = doc['proxies'];
        if (rawProxies is List) {
          for (final item in rawProxies) {
            if (item is Map) {
              final name = item['name']?.toString() ?? '';
              if (name.isEmpty) continue;

              // Filter include
              if (includeRegex != null && !includeRegex.hasMatch(name)) {
                continue;
              }
              // Filter exclude
              if (excludeRegex != null && excludeRegex.hasMatch(name)) {
                continue;
              }

              // Deduplicate name
              var finalName = name;
              int dupIndex = 1;
              while (seenNames.contains(finalName)) {
                finalName = '$name ($dupIndex)';
                dupIndex++;
              }
              seenNames.add(finalName);

              final proxyMap = Map<dynamic, dynamic>.from(item);
              proxyMap['name'] = finalName;
              mergedProxies.add(proxyMap);
            }
          }
        }
      }

      if (mergedProxies.isEmpty) {
        if (mounted) {
          context.showNotifier('未匹配到符合过滤规则的节点，请检查关键词设置');
        }
        return;
      }

      // Construct a clean Clash YAML profile
      final proxyNames = mergedProxies
          .map((e) => e['name'].toString())
          .toList();
      final StringBuffer yamlBuffer = StringBuffer();
      yamlBuffer.writeln('port: 7890');
      yamlBuffer.writeln('socks-port: 7891');
      yamlBuffer.writeln('allow-lan: false');
      yamlBuffer.writeln('mode: rule');
      yamlBuffer.writeln('log-level: info');
      yamlBuffer.writeln('unified-delay: true');
      yamlBuffer.writeln('tcp-concurrent: true');
      yamlBuffer.writeln('');

      // Proxies section
      yamlBuffer.writeln('proxies:');
      for (final p in mergedProxies) {
        yamlBuffer.writeln('  -');
        for (final entry in p.entries) {
          final k = entry.key;
          final v = entry.value;
          if (v is String) {
            yamlBuffer.writeln('    $k: "$v"');
          } else if (v is List) {
            yamlBuffer.writeln('    $k: [${v.join(", ")}]');
          } else {
            yamlBuffer.writeln('    $k: $v');
          }
        }
      }
      yamlBuffer.writeln('');

      // Proxy Groups
      yamlBuffer.writeln('proxy-groups:');
      yamlBuffer.writeln('  - name: 节点选择');
      yamlBuffer.writeln('    type: select');
      yamlBuffer.writeln('    proxies:');
      yamlBuffer.writeln('      - 自动选择');
      yamlBuffer.writeln('      - DIRECT');
      for (final n in proxyNames) {
        yamlBuffer.writeln('      - "$n"');
      }
      yamlBuffer.writeln('');
      yamlBuffer.writeln('  - name: 自动选择');
      yamlBuffer.writeln('    type: url-test');
      yamlBuffer.writeln('    url: http://www.gstatic.com/generate_204');
      yamlBuffer.writeln('    interval: 300');
      yamlBuffer.writeln('    proxies:');
      for (final n in proxyNames) {
        yamlBuffer.writeln('      - "$n"');
      }
      yamlBuffer.writeln('');

      // Basic rules
      yamlBuffer.writeln('rules:');
      yamlBuffer.writeln('  - MATCH,节点选择');

      // Save as a local Profile
      final newProfile = Profile.normal(label: newName);
      final newPath = await appPath.getProfilePath(newProfile.id.toString());
      final newFile = File(newPath);
      await newFile.writeAsString(yamlBuffer.toString());

      final validationError = await ref
          .read(coreHandlerProvider)
          .validateConfig(newPath);
      if (validationError.isNotEmpty) {
        if (mounted) {
          context.showNotifier('生成配置格式校验失败: $validationError');
        }
        return;
      }

      ref.read(profilesProvider.notifier).put(newProfile);
      if (mounted) {
        context.showNotifier(
          '🎉 聚合成功！已提取 ${mergedProxies.length} 个节点并保存为「$newName」',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showNotifier('聚合执行失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMerging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allProfiles = ref.watch(profilesProvider);

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
                      'Sub-Store 订阅聚合与管理',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '双模支持 · 手机本地原生开箱即用 + 远程 VPS 模式',
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
                _isLocalMode
                    ? '⚡ 本地原生聚合模式：直接利用本地 Clash 核心，将手机内已有的多个机场订阅智能合并、正则清洗并自动去重，生成全新的聚合配置，0 额外耗电，秒级即时完成。'
                    : '🌐 远程 VPS 模式：直连云端独立部署的 Sub-Store 官方后端，支持执行复杂自定义 JS 脚本，并可一键免配置直达 Web 管理控制台。',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ...generateSection(
        title: '运行模式',
        items: [
          ListItem(
            title: const Text('模式选择'),
            subtitle: Text(
              _isLocalMode ? '当前：本地原生聚合模式 (零门槛免配置)' : '当前：远程 VPS 模式',
            ),
            leading: Icon(_isLocalMode ? Icons.bolt : Icons.cloud),
            trailing: Switch(
              value: _isLocalMode,
              onChanged: (val) {
                setState(() {
                  _isLocalMode = val;
                });
              },
            ),
          ),
        ],
      ),
      if (_isLocalMode) ...[
        ...generateSection(
          title: '选择待聚合的配置源 (勾选 2 个及以上)',
          items: allProfiles.isEmpty
              ? [
                  const ListItem(
                    title: Text('暂无可用的订阅配置'),
                    subtitle: Text('请先在「配置」页面添加至少两个机场订阅'),
                    leading: Icon(Icons.info_outline, color: Colors.orange),
                  ),
                ]
              : allProfiles.map((p) {
                  final isSelected = _selectedProfileIds.contains(p.id);
                  return ListItem(
                    title: Text(p.label.isEmpty ? '未命名配置 (${p.id})' : p.label),
                    subtitle: Text(
                      p.url.isNotEmpty ? p.url : '本地导入文件',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedProfileIds.remove(p.id);
                        } else {
                          _selectedProfileIds.add(p.id);
                        }
                      });
                    },
                  );
                }).toList(),
        ),
        ...generateSection(
          title: '节点清洗与过滤设置',
          items: [
            ListItem(
              title: const Text('生成配置名称'),
              subtitle: Text(_profileNameController.text),
              leading: const Icon(Icons.badge),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                String val = _profileNameController.text;
                final res = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('设置新配置名称'),
                    content: TextFormField(
                      initialValue: val,
                      onChanged: (text) => val = text,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(val),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
                if (res != null && res.trim().isNotEmpty) {
                  setState(() {
                    _profileNameController.text = res.trim();
                  });
                }
              },
            ),
            ListItem(
              title: const Text('保留关键字 (正则，留空则全选)'),
              subtitle: Text(
                _includeKeywordController.text.isEmpty
                    ? '无限制 (保留所有节点)'
                    : _includeKeywordController.text,
              ),
              leading: const Icon(Icons.filter_alt),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                String val = _includeKeywordController.text;
                final res = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('保留匹配关键字'),
                    content: TextFormField(
                      initialValue: val,
                      decoration: const InputDecoration(
                        hintText: '例: 香港|日本|新加坡|美国',
                      ),
                      onChanged: (text) => val = text,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(val),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
                if (res != null) {
                  setState(() {
                    _includeKeywordController.text = res.trim();
                  });
                }
              },
            ),
            ListItem(
              title: const Text('排除关键字 (正则，剔除无效节点)'),
              subtitle: Text(
                _excludeKeywordController.text.isEmpty
                    ? '无排除'
                    : _excludeKeywordController.text,
              ),
              leading: const Icon(Icons.filter_alt_off),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                String val = _excludeKeywordController.text;
                final res = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('排除匹配关键字'),
                    content: TextFormField(
                      initialValue: val,
                      decoration: const InputDecoration(
                        hintText: '例: 官网|到期|剩余|流量|重置',
                      ),
                      onChanged: (text) => val = text,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(val),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
                if (res != null) {
                  setState(() {
                    _excludeKeywordController.text = res.trim();
                  });
                }
              },
            ),
            ListItem(
              title: Text(
                _isMerging ? '正在智能合并节点...' : '🚀 开始一键聚合生成',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '已选 ${_selectedProfileIds.length} 个配置源 · 自动去重并创建分组',
              ),
              leading: _isMerging
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.play_circle_fill,
                      color: theme.colorScheme.primary,
                    ),
              onTap: _isMerging ? null : () => _executeMerge(allProfiles),
            ),
          ],
        ),
      ] else ...[
        ...generateSection(
          title: '远程 VPS 连接设置',
          items: [
            ListItem(
              title: const Text('远程 VPS 后端地址'),
              subtitle: Text(
                _remoteUrlController.text.isEmpty
                    ? '未配置 (点击配置)'
                    : _remoteUrlController.text,
              ),
              leading: const Icon(Icons.dns),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                String tempText = _remoteUrlController.text;
                final res = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('修改远程 VPS 后端地址'),
                    content: TextFormField(
                      initialValue: tempText,
                      onChanged: (val) => tempText = val.trim(),
                      decoration: const InputDecoration(
                        hintText: '如: http://192.168.1.100:3001',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(tempText),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
                if (res != null) {
                  setState(() {
                    _remoteUrlController.text = res;
                  });
                  await preferences.saveSubStoreRemoteUrl(res);
                }
              },
            ),
            ListItem(
              title: const Text('打开 Web 管理控制台 (自动免配直连)'),
              subtitle: const Text('自动注入 API 参数唤起官方 Web 控制台'),
              leading: const Icon(
                Icons.open_in_browser,
                color: Color(0xFF6366F1),
              ),
              trailing: const Icon(Icons.launch),
              onTap: _openSubStoreWeb,
            ),
            ListItem(
              title: const Text('直连后端原生接口'),
              subtitle: Text(
                _currentBackendUrl.isEmpty ? '未配置后端地址' : _currentBackendUrl,
              ),
              leading: const Icon(Icons.link),
              trailing: const Icon(Icons.open_in_new),
              onTap: _openDirectBackend,
            ),
          ],
        ),
      ],
    ];

    return CommonScaffold(
      title: 'Sub-Store 订阅聚合',
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, index) => items[index],
      ),
    );
  }
}
