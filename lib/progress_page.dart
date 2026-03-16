import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String backendBaseUrl = 'http://10.0.2.2:8080';

enum ProgressChartType { blinkByTime, alerts, blueLightScatter }

enum TimeRange { daily, weekly, monthly, yearly }

class ChartPoint {
  final String label;
  final double value;

  ChartPoint({required this.label, required this.value});

  factory ChartPoint.fromJson(Map<String, dynamic> json) {
    return ChartPoint(
      label: (json['label'] ?? '').toString(),
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ScatterChartPoint {
  final double x;
  final double y;
  final String label;

  ScatterChartPoint({required this.x, required this.y, required this.label});

  factory ScatterChartPoint.fromJson(Map<String, dynamic> json) {
    return ScatterChartPoint(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      label: (json['label'] ?? '').toString(),
    );
  }
}

class ProgressPage extends StatefulWidget {
  final Set<ProgressChartType> selectedForHome;
  final ValueChanged<ProgressChartType> onToggleForHome;
  final String userId;
  final String formId;

  const ProgressPage({
    super.key,
    required this.selectedForHome,
    required this.onToggleForHome,
    required this.userId,
    required this.formId,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  TimeRange _range = TimeRange.daily;
  ProgressChartType _active = ProgressChartType.blinkByTime;
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDatePickerMode: _range == TimeRange.yearly
          ? DatePickerMode.year
          : DatePickerMode.day,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _selectedDateToApi() {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _selectedDateLabel() {
    if (_active == ProgressChartType.blinkByTime) {
      return _formatDate(_selectedDate);
    }

    switch (_range) {
      case TimeRange.daily:
        return _formatDate(_selectedDate);
      case TimeRange.weekly:
        return 'Week of ${_formatDate(_selectedDate)}';
      case TimeRange.monthly:
        return '${_monthName(_selectedDate.month)} ${_selectedDate.year}';
      case TimeRange.yearly:
        return '${_selectedDate.year}';
    }
  }

  String _rangeTypeToApi(TimeRange range) {
    switch (range) {
      case TimeRange.daily:
        return 'day';
      case TimeRange.weekly:
        return 'week';
      case TimeRange.monthly:
        return 'month';
      case TimeRange.yearly:
        return 'year';
    }
  }

  Future<List<ChartPoint>> _fetchAlertCount() async {
    final uri = Uri.parse('$backendBaseUrl/api/notifications/alert-count')
        .replace(
          queryParameters: {
            'user_id': widget.userId,
            'form_id': widget.formId,
            'range_type': _rangeTypeToApi(_range),
          },
        );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load alert count: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (decoded['data'] as List? ?? [])
        .map((e) => ChartPoint.fromJson(e as Map<String, dynamic>))
        .toList();

    return data;
  }

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
                _chip('Blink by Time', ProgressChartType.blinkByTime),
                _chip('Alerts', ProgressChartType.alerts),
                _chip('Blue Light', ProgressChartType.blueLightScatter),
              ],
            ),

            const SizedBox(height: 14),

            InkWell(
              onTap: _pickFilterDate,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Color(0xFF2EC4B6)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date Filter',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedDateLabel(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _active == ProgressChartType.blinkByTime
                                ? 'Selected day'
                                : _range == TimeRange.daily
                                ? 'Selected day'
                                : _range == TimeRange.weekly
                                ? 'Selected week anchor date'
                                : _range == TimeRange.monthly
                                ? 'Selected month'
                                : 'Selected year',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
            ),

            if (_active != ProgressChartType.blinkByTime) ...[
              const SizedBox(height: 12),

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
            ],

            const SizedBox(height: 10),

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
      case ProgressChartType.blinkByTime:
        return BlinkByTimeBarChart(
          userId: widget.userId,
          formId: widget.formId,
          selectedDate: _selectedDateToApi(),
        );
      case ProgressChartType.alerts:
        return AlertsBarChart(
          range: _range,
          userId: widget.userId,
          formId: widget.formId,
          selectedDate: _selectedDateToApi(),
        );
      case ProgressChartType.blueLightScatter:
        return BlueLightScatterChart(
          range: _range,
          userId: widget.userId,
          formId: widget.formId,
          selectedDate: _selectedDateToApi(),
        );
    }
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
   Chart 1: Bar chart
   Blink rate per 4 hours (colored by status)
   ========================= */

class BlinkByTimeBarChart extends StatefulWidget {
  final String userId;
  final String formId;
  final String selectedDate;

  const BlinkByTimeBarChart({
    super.key,
    required this.userId,
    required this.formId,
    required this.selectedDate,
  });

  @override
  State<BlinkByTimeBarChart> createState() => _BlinkByTimeBarChartState();
}

class _BlinkByTimeBarChartState extends State<BlinkByTimeBarChart> {
  late Future<List<ChartPoint>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchBlinkByTime();
  }

  @override
  void didUpdateWidget(covariant BlinkByTimeBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId ||
        oldWidget.formId != widget.formId ||
        oldWidget.selectedDate != widget.selectedDate) {
      _future = _fetchBlinkByTime();
    }
  }

  Future<List<ChartPoint>> _fetchBlinkByTime() async {
    final uri = Uri.parse('$backendBaseUrl/api/chart-metrics/blink-by-time')
        .replace(
          queryParameters: {
            'user_id': widget.userId,
            'form_id': widget.formId,
            'selected_date': widget.selectedDate,
          },
        );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load blink by time: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rawData = (decoded['data'] as List? ?? []);

    return rawData
        .map((e) => ChartPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  double _calculateMaxY(List<ChartPoint> data) {
    if (data.isEmpty) return 10;
    final maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return maxValue < 10 ? 10 : maxValue + 2;
  }

  Color _statusColor(double blinkPerMin) {
    if (blinkPerMin >= 15) return const Color(0xFF2EC4B6);
    if (blinkPerMin >= 10) return const Color(0xFFFF9F1C);
    return const Color(0xFFE63946);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChartPoint>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Failed to load blink by time data',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }

        final data = snapshot.data ?? [];

        if (data.isEmpty) {
          return const Center(
            child: Text(
              'No blink by time data available',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        final maxY = _calculateMaxY(data);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Blink Rate by Time',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Shows average blink rate for each 3-hour period of the day.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
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
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= data.length) {
                            return const SizedBox();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              data[i].label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(data.length, (i) {
                    final item = data[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: item.value,
                          color: _statusColor(item.value),
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
      },
    );
  }
}

Color _statusColor(int blinkPerMin) {
  // مثال منطقي بسيط (عدّليه لاحقًا حسب قياسكم)
  if (blinkPerMin >= 15) return const Color(0xFF2EC4B6); // طبيعي
  if (blinkPerMin >= 10) return const Color(0xFFFF9F1C); // متوسط
  return const Color(0xFFE63946); // خطر
}

/* =========================
   Chart 2: Bar chart
   Alerts count by type (3 types dummy)
   ========================= */

class AlertsBarChart extends StatefulWidget {
  final TimeRange range;
  final String userId;
  final String formId;
  final String selectedDate;

  const AlertsBarChart({
    super.key,
    required this.range,
    required this.userId,
    required this.formId,
    required this.selectedDate,
  });

  @override
  State<AlertsBarChart> createState() => _AlertsBarChartState();
}

class _AlertsBarChartState extends State<AlertsBarChart> {
  late Future<List<ChartPoint>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchAlertCounts();
  }

  @override
  void didUpdateWidget(covariant AlertsBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId ||
        oldWidget.formId != widget.formId ||
        oldWidget.range != widget.range ||
        oldWidget.selectedDate != widget.selectedDate) {
      _future = _fetchAlertCounts();
    }
  }

  String _rangeTypeToApi(TimeRange range) {
    switch (range) {
      case TimeRange.daily:
        return 'day';
      case TimeRange.weekly:
        return 'week';
      case TimeRange.monthly:
        return 'month';
      case TimeRange.yearly:
        return 'year';
    }
  }

  Future<List<ChartPoint>> _fetchAlertCounts() async {
    final uri = Uri.parse('$backendBaseUrl/api/notifications/alert-count')
        .replace(
          queryParameters: {
            'user_id': widget.userId,
            'form_id': widget.formId,
            'range_type': _rangeTypeToApi(widget.range),
            'selected_date': widget.selectedDate,
          },
        );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load alerts chart: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rawData = (decoded['data'] as List? ?? []);

    return rawData
        .map((e) => ChartPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  double _calculateMaxY(List<ChartPoint> data) {
    if (data.isEmpty) return 5;
    final maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return maxValue < 5 ? 5 : maxValue + 1;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChartPoint>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Failed to load alerts data',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }

        final alerts = snapshot.data ?? [];

        if (alerts.isEmpty) {
          return const Center(
            child: Text(
              'No alert data available',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        final maxY = _calculateMaxY(alerts);

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
                  maxY: maxY,
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
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= alerts.length) {
                            return const SizedBox();
                          }

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
                    final item = alerts[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: item.value,
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
              'Loaded from database.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        );
      },
    );
  }
}

class _AlertBucket {
  final String label;
  final int count;
  _AlertBucket(this.label, this.count);
}

/* =========================
   Chart 3: scatterplot chart
   BlueLight 
   ========================= */

class BlueLightScatterChart extends StatefulWidget {
  final TimeRange range;
  final String userId;
  final String formId;
  final String selectedDate;

  const BlueLightScatterChart({
    super.key,
    required this.range,
    required this.userId,
    required this.formId,
    required this.selectedDate,
  });

  @override
  State<BlueLightScatterChart> createState() => _BlueLightScatterChartState();
}

class _BlueLightScatterChartState extends State<BlueLightScatterChart> {
  late Future<List<ScatterChartPoint>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchBlueLightScatter();
  }

  @override
  void didUpdateWidget(covariant BlueLightScatterChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId ||
        oldWidget.formId != widget.formId ||
        oldWidget.range != widget.range ||
        oldWidget.selectedDate != widget.selectedDate) {
      _future = _fetchBlueLightScatter();
    }
  }

  String _rangeTypeToApi(TimeRange range) {
    switch (range) {
      case TimeRange.daily:
        return 'day';
      case TimeRange.weekly:
        return 'week';
      case TimeRange.monthly:
        return 'month';
      case TimeRange.yearly:
        return 'year';
    }
  }

  Future<List<ScatterChartPoint>> _fetchBlueLightScatter() async {
    final uri =
        Uri.parse(
          '$backendBaseUrl/api/chart-metrics/blue-light-scatter',
        ).replace(
          queryParameters: {
            'user_id': widget.userId,
            'form_id': widget.formId,
            'range_type': _rangeTypeToApi(widget.range),
            'selected_date': widget.selectedDate,
          },
        );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load blue light scatter: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rawData = (decoded['data'] as List? ?? []);

    return rawData
        .map((e) => ScatterChartPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<ScatterSpot> _buildScatterSpots(List<ScatterChartPoint> data) {
    return data
        .map(
          (point) => ScatterSpot(
            point.x,
            point.y,
            dotPainter: FlDotCirclePainter(
              color: const Color(0xFF2EC4B6),
              radius: 6,
            ),
          ),
        )
        .toList();
  }

  double _maxX(List<ScatterChartPoint> data) {
    if (data.isEmpty) return 100;
    final maxValue = data.map((e) => e.x).reduce((a, b) => a > b ? a : b);
    return maxValue <= 0 ? 100 : maxValue + 20;
  }

  double _maxY(List<ScatterChartPoint> data) {
    if (data.isEmpty) return 1;
    final maxValue = data.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    return maxValue <= 0 ? 1 : maxValue + 0.1;
  }

  String _rangeLabel(TimeRange range) {
    switch (range) {
      case TimeRange.daily:
        return 'daily';
      case TimeRange.weekly:
        return 'weekly';
      case TimeRange.monthly:
        return 'monthly';
      case TimeRange.yearly:
        return 'yearly';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ScatterChartPoint>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Failed to load blue light data',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }

        final data = snapshot.data ?? [];

        if (data.isEmpty) {
          return const Center(
            child: Text(
              'No blue light data available',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        final spots = _buildScatterSpots(data);
        final maxX = _maxX(data);
        final maxY = _maxY(data);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Blue Light Exposure',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Shows the relationship between lux and blue light ratio for the selected ${_rangeLabel(widget.range)} range.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ScatterChart(
                ScatterChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: 0,
                  maxY: maxY,
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  scatterSpots: spots,
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
                          'Blue Ratio',
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
                        interval: maxY > 1 ? (maxY / 5) : 0.2,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Lux',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      axisNameSize: 24,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: maxX > 100 ? (maxX / 5) : 20,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Each dot represents one ${_rangeLabel(widget.range)} time bucket.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        );
      },
    );
  }
}
