import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

enum ProgressChartType { blinkTrend, blinkByTime, alerts, blueLightScatter }

enum TimeRange { daily, weekly, monthly, yearly }

class ProgressPage extends StatefulWidget {
  final Set<ProgressChartType> selectedForHome;
  final ValueChanged<ProgressChartType> onToggleForHome;

  const ProgressPage({
    super.key,
    required this.selectedForHome,
    required this.onToggleForHome,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  TimeRange _range = TimeRange.daily;
  ProgressChartType _active = ProgressChartType.blinkTrend;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.selectedForHome.contains(_active);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Charts preview .',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 14),

            // Chart picker
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _chip('Blink Trend', ProgressChartType.blinkTrend),
                _chip('Blink by Time', ProgressChartType.blinkByTime),
                _chip('Alerts', ProgressChartType.alerts),
                _chip('Blue Light', ProgressChartType.blueLightScatter),
              ],
            ),

            const SizedBox(height: 14),

            // Time filter only for the line chart
            if (_active == ProgressChartType.blinkTrend)
              Row(
                children: [
                  const Text(
                    'Time Range:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<TimeRange>(
                    value: _range,
                    items: const [
                      DropdownMenuItem(
                        value: TimeRange.daily,
                        child: Text('Daily'),
                      ),
                      DropdownMenuItem(
                        value: TimeRange.weekly,
                        child: Text('Weekly'),
                      ),
                      DropdownMenuItem(
                        value: TimeRange.monthly,
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(
                        value: TimeRange.yearly,
                        child: Text('Yearly'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _range = v!),
                  ),
                ],
              ),

            const SizedBox(height: 10),

            // Chart card
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _buildActiveChart(),
              ),
            ),

            const SizedBox(height: 12),

            // Select for home (Toggle)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? Colors.grey.shade700
                      : const Color(0xFFFF9F1C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => widget.onToggleForHome(_active),
                icon: Icon(
                  isSelected
                      ? Icons.remove_circle_outline
                      : Icons.home_outlined,
                ),
                label: Text(
                  isSelected ? 'Remove from Home' : 'Add to Home',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, ProgressChartType type) {
    final selected = _active == type;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFCBF3F0),
      onSelected: (_) => setState(() => _active = type),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? const Color(0xFF2EC4B6) : Colors.black87,
      ),
    );
  }

  Widget _buildActiveChart() {
    switch (_active) {
      case ProgressChartType.blinkTrend:
        return BlinkTrendLineChart(range: _range);
      case ProgressChartType.blinkByTime:
        return BlinkByTimeBarChart();
      case ProgressChartType.alerts:
        return AlertsBarChart();
      case ProgressChartType.blueLightScatter:
        return const BlueLightScatterChart();
    }
  }
}

/* =========================
   Chart 1: Line chart
   Blink rate vs time (3 levels)
   ========================= */

class BlinkTrendLineChart extends StatelessWidget {
  final TimeRange range;
  const BlinkTrendLineChart({super.key, required this.range});

  @override
  Widget build(BuildContext context) {
    // Dummy points by time range
    final labels = _xLabels(range);
    final normal = _spots([18, 17, 19, 20, 18, 17, 18]);
    final moderate = _spots([12, 11, 12, 13, 12, 11, 12]);
    final danger = _spots([7, 6, 7, 8, 7, 6, 5]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Blink Rate (blink/min)',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tracks your blinking trend over time to spot dryness risk early.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (labels.length - 1).toDouble(),
              minY: 0,
              maxY: 25,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 36),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= labels.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[i],
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                _line(normal, const Color(0xFF2EC4B6), 'Normal'),
                _line(moderate, const Color(0xFFFF9F1C), 'Moderate'),
                _line(danger, const Color(0xFFE63946), 'Danger'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          children: const [
            _LegendDot(color: Color(0xFF2EC4B6), text: 'Normal'),
            _LegendDot(color: Color(0xFFFF9F1C), text: 'Moderate'),
            _LegendDot(color: Color(0xFFE63946), text: 'Danger'),
          ],
        ),
      ],
    );
  }

  List<String> _xLabels(TimeRange r) {
    switch (r) {
      case TimeRange.daily:
        return const ['1', '2', '3', '4', '5', '6', '7'];
      case TimeRange.weekly:
        return const ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];
      case TimeRange.monthly:
        return const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
      case TimeRange.yearly:
        return const ['2019', '20', '21', '22', '23', '24', '25'];
    }
  }

  List<FlSpot> _spots(List<double> ys) {
    return List.generate(ys.length, (i) => FlSpot(i.toDouble(), ys[i]));
  }

  LineChartBarData _line(List<FlSpot> spots, Color c, String name) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: c,
      barWidth: 3,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendDot({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/* =========================
   Chart 2: Bar chart
   Blink rate per 4 hours (colored by status)
   ========================= */

class BlinkByTimeBarChart extends StatelessWidget {
  BlinkByTimeBarChart({super.key});

  final List<_BlinkBucket> buckets = [
    _BlinkBucket('12-4', 6),
    _BlinkBucket('4-8', 10),
    _BlinkBucket('8-12', 16),
    _BlinkBucket('12-4p', 18),
    _BlinkBucket('4-8p', 12),
    _BlinkBucket('8-12p', 7),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Blink Rate by Time',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Compares blink rate across the day to find low-blink periods.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: BarChart(
            BarChartData(
              maxY: 25,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 36),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= buckets.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          buckets[i].label,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(buckets.length, (i) {
                final b = buckets[i];
                final color = _statusColor(b.value);
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: b.value.toDouble(),
                      color: color,
                      width: 18,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),

        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          children: const [
            _LegendDot(color: Color(0xFF2EC4B6), text: 'Normal'),
            _LegendDot(color: Color(0xFFFF9F1C), text: 'Moderate'),
            _LegendDot(color: Color(0xFFE63946), text: 'Danger'),
          ],
        ),
      ],
    );
  }

  Color _statusColor(int blinkPerMin) {
    // مثال منطقي بسيط (عدّليه لاحقًا حسب قياسكم)
    if (blinkPerMin >= 15) return const Color(0xFF2EC4B6); // طبيعي
    if (blinkPerMin >= 10) return const Color(0xFFFF9F1C); // متوسط
    return const Color(0xFFE63946); // خطر
  }
}

class _BlinkBucket {
  final String label;
  final int value;
  _BlinkBucket(this.label, this.value);
}

/* =========================
   Chart 3: Bar chart
   Alerts count by type (3 types dummy)
   ========================= */

class AlertsBarChart extends StatelessWidget {
  AlertsBarChart({super.key});

  final List<_AlertBucket> alerts = [
    _AlertBucket('Incorrect\nsensor', 4),
    _AlertBucket('Low\nlight', 7),
    _AlertBucket('Low\nblink', 5),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alerts by Type',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Summarizes alert counts to highlight the most common issues.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: BarChart(
            BarChartData(
              maxY: 10,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 36),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= alerts.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          alerts[i].label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(alerts.length, (i) {
                final a = alerts[i];
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: a.count.toDouble(),
                      color: const Color(0xFF2EC4B6),
                      width: 18,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),

        const SizedBox(height: 6),
        const Text(
          'Dummy counts .',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class _AlertBucket {
  final String label;
  final int count;
  _AlertBucket(this.label, this.count);
}

/* =========================
   Chart 4: scatterplot chart
   BlueLight 
   ========================= */

class BlueLightScatterChart extends StatelessWidget {
  const BlueLightScatterChart({super.key});

  List<ScatterSpot> _spots() {
    final data = [
      [2, 1],
      [4, 1.5],
      [6, 2],
      [8, 2.5],
      [10, 3],
      [12, 3.5],
      [14, 4],
      [16, 4.5],
      [18, 5],
    ];

    return data
        .map(
          (e) => ScatterSpot(
            e[0].toDouble(),
            e[1].toDouble(),
            dotPainter: FlDotCirclePainter(
              color: const Color(0xFF2EC4B6),
              radius: 6,
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Blue Light Exposure',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Shows how blue-light exposure changes across the day.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: ScatterChart(
            ScatterChartData(
              minX: 0,
              maxX: 24,
              minY: 0,
              maxY: 5,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),

              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),

                leftTitles: AxisTitles(
                  axisNameWidget: const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Blue Light (0–5)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  axisNameSize: 22,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value % 1 != 0) return const SizedBox();
                      if (value < 0 || value > 5) return const SizedBox();
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 11),
                      );
                    },
                  ),
                ),

                bottomTitles: AxisTitles(
                  axisNameWidget: const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Time (0–24)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  axisNameSize: 24,
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 4,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value % 4 != 0) return const SizedBox();
                      if (value < 0 || value > 24) return const SizedBox();
                      return Text(
                        '${value.toInt()}h',
                        style: const TextStyle(fontSize: 11),
                      );
                    },
                  ),
                ),
              ),

              scatterSpots: _spots(),
            ),
          ),
        ),
      ],
    );
  }
}
