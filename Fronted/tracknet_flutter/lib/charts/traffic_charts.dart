import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/domain.dart';
import '../theme/app_theme.dart';
import '../shared_widgets/widgets.dart';

class TrafficChart extends StatelessWidget {
  const TrafficChart({
    super.key,
    required this.title,
    required this.values,
    required this.labels,
    this.line = false,
    this.selected,
    this.onSelect,
    this.unit = '',
  });
  final String title, unit;
  final List<double> values;
  final List<String> labels;
  final bool line;
  final int? selected;
  final ValueChanged<int>? onSelect;
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Panel(title: title, child: const EmptyState('No chart data'));
    }
    final titles = FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (v, m) => Text(
            v >= 1000
                ? '${(v / 1000).toStringAsFixed(1)}k'
                : v.toInt().toString(),
            style: const TextStyle(fontSize: 9, color: mutedInk),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: values.length > 10 ? 3 : 1,
          reservedSize: 30,
          getTitlesWidget: (v, m) {
            final i = v.round();
            if (i < 0 || i >= labels.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                labels[i],
                style: const TextStyle(fontSize: 8, color: mutedInk),
              ),
            );
          },
        ),
      ),
    );
    return Panel(
      title: title,
      action: Text(unit, style: const TextStyle(fontSize: 10, color: mutedInk)),
      child: SizedBox(
        height: 225,
        child: line
            ? LineChart(
                LineChartData(
                  minY: 0,
                  titlesData: titles,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: values.indexed
                          .map((e) => FlSpot(e.$1.toDouble(), e.$2))
                          .toList(),
                      color: primaryInk,
                      barWidth: 2.5,
                      isCurved: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: primaryInk.withValues(alpha: .08),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent &&
                          response?.lineBarSpots?.isNotEmpty == true) {
                        onSelect?.call(response!.lineBarSpots!.first.spotIndex);
                      }
                    },
                  ),
                ),
                duration: Duration(
                  milliseconds: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : 600,
                ),
              )
            : BarChart(
                BarChartData(
                  minY: 0,
                  titlesData: titles,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  barGroups: values.indexed
                      .map(
                        (e) => BarChartGroupData(
                          x: e.$1,
                          barRods: [
                            BarChartRodData(
                              toY: e.$2,
                              color: selected == e.$1
                                  ? primaryInk
                                  : neutralFill,
                              width: values.length > 10 ? 9 : 18,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                  barTouchData: BarTouchData(
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent && response?.spot != null) {
                        onSelect?.call(response!.spot!.touchedBarGroupIndex);
                      }
                    },
                  ),
                ),
                duration: Duration(
                  milliseconds: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : 600,
                ),
              ),
      ),
    );
  }
}

class TypeChart extends StatelessWidget {
  const TypeChart({super.key, required this.counts});
  final Map<String, int> counts;
  @override
  Widget build(BuildContext context) {
    final colors = [
          primaryInk,
          mutedInk,
          neutralFill,
          const Color(0xffd4d4d8),
          const Color(0xff52525b),
          const Color(0xffa1a1aa),
        ],
        total = counts.values.fold<int>(0, (a, b) => a + b);
    return Panel(
      title: 'Vehicle type split',
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: total == 0
                ? const EmptyState('No classified detections')
                : PieChart(
                    PieChartData(
                      centerSpaceRadius: 52,
                      sectionsSpace: 3,
                      sections: counts.entries.indexed
                          .map(
                            (e) => PieChartSectionData(
                              value: e.$2.value.toDouble(),
                              color: colors[e.$1 % colors.length],
                              radius: 35,
                              title: '${(e.$2.value / total * 100).round()}%',
                              titleStyle: TextStyle(
                                color:
                                    colors[e.$1 % colors.length]
                                            .computeLuminance() <
                                        .3
                                    ? Colors.white
                                    : primaryInk,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    duration: Duration(
                      milliseconds: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 600,
                    ),
                  ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: counts.entries.indexed
                .map(
                  (e) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 9,
                        color: colors[e.$1 % colors.length],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${e.$2.key} ${e.$2.value}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class FlowDiagram extends StatelessWidget {
  const FlowDiagram({
    super.key,
    required this.flows,
    required this.zones,
    required this.onSelect,
    this.selected,
  });
  final List<OdFlow> flows;
  final List<Zone> zones;
  final ValueChanged<OdFlow> onSelect;
  final OdFlow? selected;
  @override
  Widget build(BuildContext context) => Panel(
    title: 'Origin → Destination flow',
    child: Column(
      children: [
        SizedBox(
          height: 200,
          child: CustomPaint(
            painter: _FlowPainter(flows, zones, selected),
            size: const Size(double.infinity, 200),
          ),
        ),
        for (final f in flows)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            selected: selected?.id == f.id,
            title: Text(
              '${zones.where((z) => z.id == f.origin).firstOrNull?.name ?? f.origin} → ${zones.where((z) => z.id == f.destination).firstOrNull?.name ?? f.destination}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Text(
              number(f.count),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            onTap: () => onSelect(f),
          ),
      ],
    ),
  );
}

class _FlowPainter extends CustomPainter {
  _FlowPainter(this.flows, this.zones, this.selected);
  final List<OdFlow> flows;
  final List<Zone> zones;
  final OdFlow? selected;
  @override
  void paint(Canvas canvas, Size size) {
    final nodes = <String, Offset>{};
    for (var i = 0; i < zones.length; i++) {
      nodes[zones[i].id] = Offset(
        40 + (i % 3) * (size.width - 80) / 2,
        28 + (i ~/ 3) * 65,
      );
    }
    for (final f in flows) {
      final a = nodes[f.origin], b = nodes[f.destination];
      if (a == null || b == null) continue;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(
          (a.dx + b.dx) / 2,
          (a.dy + b.dy) / 2 - 20,
          b.dx,
          b.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + f.count / 2000
          ..color =
              (selected?.id == f.id ? primaryInk : const Color(0xffd4d4d8))
                  .withValues(
                    alpha: selected == null || selected?.id == f.id ? 0.8 : .2,
                  ),
      );
    }
    for (final z in zones) {
      final p = nodes[z.id]!;
      canvas.drawCircle(p, 5, Paint()..color = primaryInk);
      final text = TextPainter(
        text: TextSpan(
          text: z.name,
          style: const TextStyle(fontSize: 9, color: mutedInk),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 100);
      text.paint(
        canvas,
        Offset(
          (p.dx - text.width / 2).clamp(0, size.width - text.width),
          p.dy + 10,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_FlowPainter old) =>
      old.selected != selected || old.flows != flows;
}
