import 'package:bfclash/common/common.dart';
import 'package:bfclash/providers/app.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IntranetIP extends StatelessWidget {
  const IntranetIP({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: height ?? getWidgetHeight(1),
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
                                final accent = BfClashAccent.of(context);
                                final ipString = localIp.isNotEmpty
                                    ? localIp
                                    : appLocalizations.noNetwork;
                                if (accent.enabled) {
                                  return TooltipText(
                                    text: GradientText(
                                      ipString,
                                      style: context.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          )
                                          .adjustSize(1),
                                      gradient: LinearGradient(
                                        colors: accent.accent!,
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
