import 'package:bfclash/common/common.dart';
import 'package:bfclash/providers/config.dart';
import 'package:bfclash/views/config/network.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _QuickSwitchCard extends StatelessWidget {
  const _QuickSwitchCard({
    required this.label,
    required this.iconData,
    required this.items,
    required this.selector,
    required this.onChanged,
    required this.detail,
    this.height,
  });

  final String label;
  final IconData iconData;
  final List<Widget> items;
  final ProviderListenable<bool> selector;
  final void Function(WidgetRef ref, bool value) onChanged;
  final String Function(BuildContext context, WidgetRef ref, bool value)
  detail;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height ?? getWidgetHeight(1),
      child: CommonCard(
        radius: AppCorner.lg,
        onPressed: () {
          showSheet(
            context: context,
            builder: (_) {
              return AdaptiveSheetScaffold(
                body: generateListView(generateSection(items: items)),
                title: label,
              );
            },
          );
        },
        info: (height ?? getWidgetHeight(1)) >= 110
            ? Info(label: label, iconData: iconData)
            : null,
        child: (height ?? getWidgetHeight(1)) >= 110
            ? Container(
                padding: baseInfoEdgeInsets.copyWith(
                  top: 0,
                  bottom: 12,
                  right: 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Consumer(
                            builder: (_, ref, _) {
                              final value = ref.watch(selector);
                              return Text(
                                value
                                    ? context.appLocalizations.stateOn
                                    : context.appLocalizations.stateOff,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: value
                                      ? context.colorScheme.onSurface
                                      : context.colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          ),
                        ),
                        Consumer(
                          builder: (_, ref, _) {
                            return Switch(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              value: ref.watch(selector),
                              onChanged: (value) => onChanged(ref, value),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Consumer(
                      builder: (_, ref, _) {
                        final value = ref.watch(selector);
                        return Text(
                          detail(context, ref, value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              )
            : Container(
                padding: baseInfoEdgeInsets.copyWith(
                  top: 4,
                  bottom: 8,
                  right: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 1,
                      child: TooltipText(
                        text: Text(
                          context.appLocalizations.options,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.adjustSize(-2)
                              .toLight,
                        ),
                      ),
                    ),
                    Consumer(
                      builder: (_, ref, _) {
                        return Switch(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          value: ref.watch(selector),
                          onChanged: (value) => onChanged(ref, value),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class TUNButton extends StatelessWidget {
  const TUNButton({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    return _QuickSwitchCard(
      label: context.appLocalizations.tun,
      iconData: Icons.stacked_line_chart,
      items: [
        if (system.isDesktop) const TUNItem(),
        if (system.isMacOS) const AutoSetSystemDnsItem(),
        const TunStackItem(),
      ],
      selector: patchClashConfigProvider.select((state) => state.tun.enable),
      onChanged: (ref, value) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(enable: value));
      },
      height: height,
      detail: (context, ref, value) {
        if (!value) return context.appLocalizations.tun;
        final stack = ref.watch(
          patchClashConfigProvider.select((state) => state.tun.stack),
        );
        return 'TUN · ${stack.name}';
      },
    );
  }
}

class SystemProxyButton extends StatelessWidget {
  const SystemProxyButton({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    return _QuickSwitchCard(
      label: context.appLocalizations.systemProxy,
      iconData: Icons.shuffle,
      items: const [SystemProxyItem(), BypassDomainItem()],
      selector: networkSettingProvider.select((state) => state.systemProxy),
      onChanged: (ref, value) {
        ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(systemProxy: value));
      },
      height: height,
      detail: (context, ref, _) {
        final port = ref.watch(
          patchClashConfigProvider.select((state) => state.mixedPort),
        );
        return 'HTTP · 127.0.0.1:$port';
      },
    );
  }
}

class VpnButton extends StatelessWidget {
  const VpnButton({super.key});

  @override
  Widget build(BuildContext context) {
    return _QuickSwitchCard(
      label: 'VPN',
      iconData: Icons.stacked_line_chart,
      items: const [VPNItem(), VpnSystemProxyItem(), TunStackItem()],
      selector: vpnSettingProvider.select((state) => state.enable),
      onChanged: (ref, value) {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(enable: value));
      },
      detail: (context, ref, value) => value ? 'VPN · TUN' : 'VPN',
    );
  }
}
