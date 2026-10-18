import 'package:bfclash/common/common.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/app.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkSpeed extends StatefulWidget {
  const NetworkSpeed({super.key, this.height, this.showRates = false});

  final double? height;
  final bool showRates;

  @override
  State<NetworkSpeed> createState() => _NetworkSpeedState();
}

class _NetworkSpeedState extends State<NetworkSpeed> {
  List<Point> initPoints = const [Point(0, 0), Point(1, 0)];

  List<Point> _getPoints(List<Traffic> traffics) {
    final List<Point> trafficPoints = traffics
        .toList()
        .asMap()
        .map(
          (index, e) => MapEntry(
            index,
            Point((index + initPoints.length).toDouble(), e.speed.toDouble()),
          ),
        )
        .values
        .toList();

    return [...initPoints, ...trafficPoints];
  }

  Traffic _getLastTraffic(List<Traffic> traffics) {
    if (traffics.isEmpty) return const Traffic();
    return traffics.last;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final color = context.colorScheme.onSurfaceVariant.opacity80;
    return SizedBox(
      height: widget.height ?? getWidgetHeight(2),
      child: RepaintBoundary(
        child: CommonCard(
          radius: AppCorner.lg,
          onPressed: () {},
          child: Consumer(
            builder: (_, ref, _) {
              final traffics = ref.watch(trafficsProvider).list;
              return Column(
                children: [
                  Padding(
                    padding: baseInfoEdgeInsets.copyWith(bottom: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: InfoHeader(
                            padding: EdgeInsets.zero,
                            info: Info(
                              label: appLocalizations.networkSpeed,
                              iconData: Icons.speed_sharp,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!widget.showRates)
                          Builder(
                            builder: (context) {
                              final isDark =
                                  Theme.of(context).brightness ==
                                  Brightness.dark;
                              final isParty =
                                  isDark &&
                                  context.colorScheme.primary.toARGB32() ==
                                      0xFF818CF8;
                              final speedText = _getLastTraffic(
                                traffics,
                              ).speedText;
                              if (isParty) {
                                return GradientText(
                                  speedText,
                                  style: context.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF38BDF8),
                                      Color(0xFFC084FC),
                                    ],
                                  ),
                                );
                              }
                              return Text(
                                speedText,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: color,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  if (widget.showRates)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SpeedReadout(
                              label: appLocalizations.download,
                              icon: Icons.arrow_downward,
                              value: _getLastTraffic(traffics).down,
                              color: Color.lerp(
                                context.colorScheme.primary,
                                const Color(0xFF38BDF8),
                                0.7,
                              )!,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _SpeedReadout(
                              label: appLocalizations.upload,
                              icon: Icons.arrow_upward,
                              value: _getLastTraffic(traffics).up,
                              color: Color.lerp(
                                context.colorScheme.primary,
                                const Color(0xFFC084FC),
                                0.7,
                              )!,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        16,
                      ).copyWith(bottom: 0, left: 0, right: 0),
                      child: LineChart(
                        gradient: true,
                        color: Theme.of(context).colorScheme.primary,
                        points: _getPoints(traffics),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SpeedReadout extends StatelessWidget {
  const _SpeedReadout({
    required this.label,
    required this.icon,
    required this.value,
    required this.color,
  });

  final String label;
  final IconData icon;
  final num value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final rate = value.traffic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: rate.value,
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' ${rate.unit}/s',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
