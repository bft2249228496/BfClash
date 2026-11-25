import 'package:bfclash/common/common.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyCard extends ConsumerWidget {
  final String groupName;
  final Proxy proxy;
  final GroupType groupType;
  final ProxyCardType type;
  final String? testUrl;

  const ProxyCard({
    super.key,
    required this.groupName,
    required this.testUrl,
    required this.proxy,
    required this.groupType,
    required this.type,
  });

  Measure get measure => globalState.measure;

  void _handleTestCurrentDelay(WidgetRef ref) {
    ref.read(proxiesActionProvider.notifier).proxyDelayTest(proxy, testUrl);
  }

  Widget _buildDelayText() {
    return Consumer(
      builder: (context, ref, _) {
        final delay = ref.watch(
          delayProvider(proxyName: proxy.name, testUrl: testUrl),
        );
        final pending = ref.watch(
          delayTestPendingProvider(proxyName: proxy.name, testUrl: testUrl),
        );
        final l10n = context.appLocalizations;
        final onTap = pending ? null : () => _handleTestCurrentDelay(ref);
        if (pending) {
          return _DelayBadge(
            tooltip: l10n.delayTest,
            label: l10n.delayTesting,
            color: context.colorScheme.onSurfaceVariant,
            icon: SizedBox(
              height: 14,
              width: 14,
              child: FittedBox(
                child: CommonCircleLoading(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            onTap: onTap,
          );
        }
        if (delay == null) {
          return _DelayBadge(
            tooltip: l10n.delayTest,
            label: l10n.delayTest,
            color: context.colorScheme.onSurfaceVariant,
            icon: Icon(
              Icons.bolt,
              size: 14,
              color: context.colorScheme.onSurfaceVariant,
            ),
            onTap: onTap,
          );
        }
        final color = getDelayColor(delay, Theme.of(context).brightness);
        return _DelayBadge(
          tooltip: delay > 0 ? l10n.delayTest : l10n.retry,
          label: delay > 0 ? '$delay ms' : l10n.retry,
          color: color,
          icon: Icon(
            delay > 0 ? Icons.bolt : Icons.refresh,
            size: 14,
            color: color,
          ),
          onTap: onTap,
        );
      },
    );
  }

  Widget _buildProxyNameText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameColor = isDark ? const Color(0xFFC7D2FE) : null;
    final textStyle = context.textTheme.bodyMedium?.copyWith(
      color: nameColor,
      fontWeight: FontWeight.w600,
    );
    if (type == ProxyCardType.min) {
      return SizedBox(
        height: measure.bodyMediumHeight * 1,
        child: EmojiText(
          proxy.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        ),
      );
    } else {
      return SizedBox(
        height: measure.bodyMediumHeight * 2,
        child: EmojiText(
          proxy.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        ),
      );
    }
  }

  Future<void> _changeProxy(WidgetRef ref) async {
    final isComputedSelected = groupType.isComputedSelected;
    final isSelector = groupType == GroupType.Selector;
    if (isComputedSelected || isSelector) {
      final currentProxyName = ref.read(proxyNameProvider(groupName));
      final nextProxyName = switch (isComputedSelected) {
        true => currentProxyName == proxy.name ? '' : proxy.name,
        false => proxy.name,
      };
      ref
          .read(proxiesActionProvider.notifier)
          .changeProxyDebounce(groupName, nextProxyName);
      return;
    }
    dialogs.showNotifier(
      currentAppLocalizations.notSelectedTip,
      level: MessageLevel.warning,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measure = globalState.measure;
    final delayText = _buildDelayText();
    final proxyNameText = _buildProxyNameText(context);
    return Stack(
      children: [
        Consumer(
          builder: (_, ref, child) {
            final selectedProxyName = ref.watch(
              selectedProxyNameProvider(groupName),
            );
            return CommonCard(
              radius: AppCorner.lg,
              key: key,
              onPressed: () {
                _changeProxy(ref);
              },
              isSelected: selectedProxyName == proxy.name,
              child: child!,
            );
          },
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                proxyNameText,
                const SizedBox(height: 8),
                if (type == ProxyCardType.expand) ...[
                  SizedBox(
                    height: measure.bodySmallHeight,
                    child: _ProxyDesc(proxy: proxy),
                  ),
                  const SizedBox(height: 6),
                  delayText,
                ] else
                  SizedBox(
                    height: measure.bodySmallHeight < 26.0
                        ? 26.0
                        : measure.bodySmallHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          flex: 1,
                          child: TooltipText(
                            text: Text(
                              proxy.type,
                              maxLines: 1,
                              style: context.textTheme.bodySmall?.copyWith(
                                overflow: TextOverflow.ellipsis,
                                color: context
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.opacity80,
                              ),
                            ),
                          ),
                        ),
                        delayText,
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (groupType.isComputedSelected)
          Positioned(
            top: 0,
            right: 0,
            child: _ProxyComputedMark(groupName: groupName, proxy: proxy),
          ),
      ],
    );
  }
}

class _ProxyDesc extends ConsumerWidget {
  final Proxy proxy;

  const _ProxyDesc({required this.proxy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desc = ref.watch(proxyDescProvider(proxy));
    return EmojiText(
      desc,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodySmall?.copyWith(
        color: context.textTheme.bodySmall?.color?.opacity80,
      ),
    );
  }
}

class _ProxyComputedMark extends ConsumerWidget {
  final String groupName;
  final Proxy proxy;

  const _ProxyComputedMark({required this.groupName, required this.proxy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyName = ref.watch(proxyNameProvider(groupName));
    if (proxyName != proxy.name) {
      return const SizedBox();
    }
    return Container(
      alignment: Alignment.topRight,
      margin: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.secondaryContainer,
        ),
        child: const SelectIcon(),
      ),
    );
  }
}

class _DelayBadge extends StatefulWidget {
  const _DelayBadge({
    required this.tooltip,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final String label;
  final Color color;
  final Widget icon;
  final VoidCallback? onTap;

  @override
  State<_DelayBadge> createState() => _DelayBadgeState();
}

class _DelayBadgeState extends State<_DelayBadge> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    final hovered = _hovering && active;
    final surface = Color.alphaBlend(
      widget.color.withValues(alpha: hovered ? 0.16 : 0.1),
      context.colorScheme.surfaceContainerHigh,
    );
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: active
            ? (_) {
                setState(() => _hovering = true);
              }
            : null,
        onExit: active
            ? (_) {
                setState(() => _hovering = false);
              }
            : null,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 26,
            padding: const EdgeInsets.only(left: 8, right: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: widget.color.withValues(alpha: hovered ? 0.7 : 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.icon,
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: widget.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
