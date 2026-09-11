import 'package:flutter/material.dart';

void main() => runApp(const LanswayApp());

class LanswayApp extends StatelessWidget {
  const LanswayApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '澜序 · Lansway',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xff6577bd)),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xffa7baf2),
      scaffoldBackgroundColor: const Color(0xff18191e),
    ),
    themeMode: ThemeMode.dark,
    home: const ClientShell(),
  );
}

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int selected = 0;
  static const labels = ['概览', '代理', '订阅', '工具', '设置'];
  static const icons = [Icons.home_outlined, Icons.route_outlined,
    Icons.folder_outlined, Icons.grid_view_outlined, Icons.settings_outlined];
  static const descriptions = [
    '代理服务尚未接入。完成 Android 内核验证后开放连接。',
    '导入真实配置后，在这里管理代理组与节点。',
    '订阅导入与配置持久化将在后续阶段接入。',
    'WebDAV、Sub-Store、覆写和日志将按阶段实现。',
    '主题、图标与 Android 系统设置将从设计原型迁移。',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('澜序 · Lansway')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(labels[selected], style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        Card(child: Padding(padding: const EdgeInsets.all(24),
          child: Text(descriptions[selected]))),
      ]),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (value) => setState(() => selected = value),
      destinations: List.generate(labels.length, (index) => NavigationDestination(
        icon: Icon(icons[index]), label: labels[index])),
    ),
  );
}
