import 'package:bfclash/common/common.dart';
import 'package:bfclash/views/proxies/proxies.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class DesktopProxiesView extends ConsumerWidget {
  const DesktopProxiesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;

    return CommonScaffold(
      title: appLocalizations.proxies,
      body: const ProxiesView(),
    );
  }
}
