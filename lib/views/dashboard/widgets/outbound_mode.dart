import 'dart:math';

import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/desktop_style.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OutboundMode extends ConsumerWidget {
  const OutboundMode({super.key});

  void _handleChangeMode(Mode mode, WidgetRef ref) {
    ref.read(setupActionProvider.notifier).changeMode(mode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final height = getWidgetHeight(2);
    return SizedBox(
      height: height,
      child: Consumer(
        builder: (_, ref, _) {
          final mode = ref.watch(
            patchClashConfigProvider.select((state) => state.mode),
          );
          return Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
            child: CommonCard(
              radius: AppCorner.lg,
              onPressed: () {},
              skipTraversal: true,
              info: Info(
                label: appLocalizations.outboundMode,
                iconData: Icons.call_split_sharp,
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 12),
                child: RadioGroup<Mode>(
                  groupValue: mode,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _handleChangeMode(value, ref);
                  },
                  child: _ModeRadioList(
                    mode: mode,
                    onSelect: (item) {
                      _handleChangeMode(item, ref);
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModeRadioList extends StatelessWidget {
  const _ModeRadioList({required this.mode, required this.onSelect});

  final Mode mode;
  final void Function(Mode mode) onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final minTileHeight = min(
          constraints.maxHeight / 3,
          globalState.measure.bodyMediumHeight + 16,
        );
        return Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            for (final item in Mode.values)
              ListItem.radio(
                horizontalTitleGap: 8,
                tileTitleAlignment: ListTileTitleAlignment.center,
                minTileHeight: minTileHeight,
                minVerticalPadding: 0,
                padding: EdgeInsets.only(left: 12.ap, right: 16.ap),
                onTap: () {
                  onSelect(item);
                },
                value: item,
                title: Builder(
                  builder: (context) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final isSelected = item == mode;
                    final textColor = isDark
                        ? (isSelected
                              ? const Color(0xFFC7D2FE)
                              : const Color(0xFFA5B4FC))
                        : null;
                    return Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class OutboundModeV2 extends StatelessWidget {
  const OutboundModeV2({super.key, this.height});

  final double? height;

  void _handleChangeMode(Mode mode, WidgetRef ref) {
    ref.read(setupActionProvider.notifier).changeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final cardHeight = height ?? getWidgetHeight(1);
    return SizedBox(
      height: cardHeight,
      child: CommonCard(
        radius: AppCorner.lg,
        info: cardHeight >= 110
            ? Info(
                label: context.appLocalizations.outboundMode,
                iconData: Icons.call_split_sharp,
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(
            alignment: Alignment.center,
            child: Consumer(
              builder: (context, ref, _) {
                final mode = ref.watch(
                  patchClashConfigProvider.select((state) => state.mode),
                );
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerLowest,
                    borderRadius: AppRadius.sm,
                    border: Border.all(
                      color: context.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        for (final item in Mode.values)
                          Expanded(
                            child: Semantics(
                              selected: item == mode,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: item == mode
                                      ? desktopAccentGradient(context)
                                      : null,
                                  borderRadius: AppRadius.sm,
                                ),
                                child: TextButton(
                                  key: ValueKey('outbound-${item.name}'),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 8,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: item == mode
                                        ? const Color(0xFF10101A)
                                        : context.colorScheme.onSurfaceVariant,
                                    shape: AppShape.sm,
                                  ),
                                  onPressed: () => _handleChangeMode(item, ref),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      item.label,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
