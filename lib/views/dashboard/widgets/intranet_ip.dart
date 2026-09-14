import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IntranetIP extends StatelessWidget {
  const IntranetIP({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        radius: AppCorner.lg,
        info: Info(label: appLocalizations.intranetIP, iconData: Icons.devices),
        onPressed: () {},
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: globalState.measure.bodyMediumHeight + 2,
                child: Consumer(
                  builder: (_, ref, _) {
                    final localIp = ref.watch(localIpProvider);
                    return FadeThroughBox(
                      child: localIp != null
                          ? Builder(
                              builder: (context) {
                                final isDark =
                                    Theme.of(context).brightness ==
                                    Brightness.dark;
                                final isParty =
                                    isDark &&
                                    context.colorScheme.primary.toARGB32() ==
                                        0xFF818CF8;
                                final ipString = localIp.isNotEmpty
                                    ? localIp
                                    : appLocalizations.noNetwork;
                                if (isParty) {
                                  return TooltipText(
                                    text: GradientText(
                                      ipString,
                                      style: context.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          )
                                          .adjustSize(1),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF38BDF8),
                                          Color(0xFF818CF8),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }
                                return TooltipText(
                                  text: Text(
                                    ipString,
                                    style: context.textTheme.bodyMedium?.toLight
                                        .adjustSize(1),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            )
                          : Container(
                              padding: const EdgeInsets.all(2),
                              child: const AspectRatio(
                                aspectRatio: 1,
                                child: CommonCircleLoading(),
                              ),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
