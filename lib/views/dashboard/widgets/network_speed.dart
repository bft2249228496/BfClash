import 'dart:io';
import 'dart:ui' as ui;

import 'package:bfclash/common/common.dart';
import 'package:bfclash/core/controller.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/app.dart';
import 'package:bfclash/providers/core.dart';
import 'package:bfclash/providers/state.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tints shared by the legend, the readouts and the chart lines so the
/// download/upload series stay recognizable across the card.
const Color kDashboardDownTint = Color(0xFF38BDF8);
const Color kDashboardUpTint = Color(0xFFC084FC);

/// Gates the connection/memory polling so fixtures without a live core can
/// render the card statically instead of waiting on the core transport.
@visibleForTesting
final dashboardCoreStatsProvider = Provider<bool>((_) => true);

class NetworkSpeed extends ConsumerWidget {
  const NetworkSpeed({super.key, this.height, this.showRates = false});

  final double? height;
  final bool showRates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final traffics = ref.watch(trafficsProvider).list;
    final totalTraffic = ref.watch(totalTrafficProvider);
    final last = traffics.isEmpty ? const Traffic() : traffics.last;
    return SizedBox(
      height: height ?? getWidgetHeight(2),
      child: RepaintBoundary(
        child: CommonCard(
          radius: AppCorner.lg,
          onPressed: () {},
          child: Column(
            children: [
              Padding(
                padding: baseInfoEdgeInsets.copyWith(bottom: 0),
                child: Row(
                  children: [
                    Expanded(
                      child: InfoHeader(
                        padding: EdgeInsets.zero,
                        info: Info(
                          label: appLocalizations.realtimeRate,
                          iconData: Icons.speed_sharp,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LegendDot(
                      color: kDashboardDownTint,
                      label: appLocalizations.download,
                    ),
                    const SizedBox(width: 12),
                    _LegendDot(
                      color: kDashboardUpTint,
                      label: appLocalizations.upload,
                    ),
                  ],
                ),
              ),
              if (showRates)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SpeedReadout(
                          label: appLocalizations.download,
                          icon: Icons.south_rounded,
                          value: last.down,
                          color: kDashboardDownTint,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _SpeedReadout(
                          label: appLocalizations.upload,
                          icon: Icons.north_rounded,
                          value: last.up,
                          color: kDashboardUpTint,
                        ),
                      ),
                    ],
                  ),
                ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: _DualLineChart(
                    down: traffics.map((e) => e.down.toDouble()).toList(),
                    up: traffics.map((e) => e.up.toDouble()).toList(),
                  ),
                ),
              ),
              if (showRates) ...[
                const SizedBox(height: 4),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TotalStat(
                          icon: Icons.south_rounded,
                          color: kDashboardDownTint,
                          label: appLocalizations.download,
                          value: totalTraffic.down,
                        ),
                      ),
                      const _StatDivider(),
                      Expanded(
                        child: _TotalStat(
                          icon: Icons.north_rounded,
                          color: kDashboardUpTint,
                          label: appLocalizations.upload,
                          value: totalTraffic.up,
                        ),
                      ),
                      const _StatDivider(),
                      const Expanded(child: _ConnectionsStat()),
                      const _StatDivider(),
                      const Expanded(child: _MemoryStat()),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 5,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
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
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

class _TotalStat extends StatelessWidget {
  const _TotalStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final num value;

  @override
  Widget build(BuildContext context) {
    final traffic = value.traffic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: traffic.value,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              TextSpan(
                text: ' ${traffic.unit}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ConnectionsStat extends ConsumerStatefulWidget {
  const _ConnectionsStat();

  @override
  ConsumerState<_ConnectionsStat> createState() => _ConnectionsStatState();
}

class _ConnectionsStatState extends ConsumerState<_ConnectionsStat>
    with WidgetsBindingObserver, ActivePollingMixin<_ConnectionsStat> {
  final _count = ValueNotifier<int?>(null);

  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    if (!ref.read(dashboardCoreStatsProvider) ||
        !ref.read(isStartProvider) ||
        ref.read(coreStatusProvider) != CoreStatus.connected) {
      _count.value = null;
      return;
    }
    try {
      final connections = await _core.getConnections();
      if (!isCurrent()) return;
      _count.value = connections.length;
    } catch (_) {
      if (isCurrent()) _count.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ValueListenableBuilder(
      valueListenable: _count,
      builder: (context, count, _) => _PlainStat(
        label: appLocalizations.activeConnections,
        value: count == null ? '—' : '$count',
        unit: count == null ? '' : appLocalizations.connections,
      ),
    );
  }
}

class _MemoryStat extends ConsumerStatefulWidget {
  const _MemoryStat();

  @override
  ConsumerState<_MemoryStat> createState() => _MemoryStatState();
}

class _MemoryStatState extends ConsumerState<_MemoryStat>
    with WidgetsBindingObserver, ActivePollingMixin<_MemoryStat> {
  final _memory = ValueNotifier<num?>(null);

  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  void dispose() {
    _memory.dispose();
    super.dispose();
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    if (!ref.read(dashboardCoreStatsProvider) || !ref.read(isStartProvider)) {
      return;
    }
    try {
      final rss = ProcessInfo.currentRss;
      final coreConnected =
          ref.read(coreStatusProvider) == CoreStatus.connected;
      final total = coreConnected ? await _core.getMemory() + rss : rss;
      if (!isCurrent()) return;
      _memory.value = total;
    } catch (_) {
      if (isCurrent()) _memory.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ValueListenableBuilder(
      valueListenable: _memory,
      builder: (context, memory, _) {
        final traffic = (memory ?? 0).traffic;
        return _PlainStat(
          label: appLocalizations.memoryUsage,
          value: memory == null ? '—' : traffic.value,
          unit: memory == null ? '' : traffic.unit,
        );
      },
    );
  }
}

class _PlainStat extends StatelessWidget {
  const _PlainStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Dual-series smoothed line chart (download in cyan, upload in purple)
/// drawn on a shared scale, matching the prototype's two-line look.
class _DualLineChart extends StatelessWidget {
  const _DualLineChart({required this.down, required this.up});

  final List<double> down;
  final List<double> up;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DualLineChartPainter(
        down: down,
        up: up,
        downColor: kDashboardDownTint,
        upColor: kDashboardUpTint,
        lineColor: context.colorScheme.outlineVariant,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _DualLineChartPainter extends CustomPainter {
  _DualLineChartPainter({
    required this.down,
    required this.up,
    required this.downColor,
    required this.upColor,
    required this.lineColor,
  });

  final List<double> down;
  final List<double> up;
  final Color downColor;
  final Color upColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final gridPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (final fraction in [0.25, 0.5, 0.75]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    _paintSeries(canvas, size, up, upColor);
    _paintSeries(canvas, size, down, downColor);
  }

  void _paintSeries(
    Canvas canvas,
    Size size,
    List<double> values,
    Color color,
  ) {
    if (values.isEmpty) return;
    var maxValue = 1.0;
    for (final value in values) {
      if (value > maxValue) maxValue = value;
    }
    Offset pointAt(int index) {
      final x = values.length == 1
          ? size.width
          : index * size.width / (values.length - 1);
      final y = size.height * (1 - values[index] / maxValue);
      return Offset(x, y);
    }

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
      )
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final first = pointAt(0);
    final path = Path()..moveTo(first.dx, first.dy);
    for (var i = 1; i < values.length; i++) {
      final prev = pointAt(i - 1);
      final current = pointAt(i);
      final midX = (prev.dx + current.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, current.dy, current.dx, current.dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final last = pointAt(values.length - 1);
    canvas.drawCircle(last, 4, Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawCircle(last, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DualLineChartPainter oldDelegate) {
    return oldDelegate.down != down ||
        oldDelegate.up != up ||
        oldDelegate.downColor != downColor ||
        oldDelegate.upColor != upColor;
  }
}
