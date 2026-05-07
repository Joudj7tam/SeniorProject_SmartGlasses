import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'pdf_report_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'smart_bottom_nav.dart';
import 'main.dart';
import 'notifications_page.dart';
import 'tips_page.dart';
import 'settings_page.dart';

const String backendBaseUrl = 'http://10.0.2.2:8080';

enum ProgressChartType { blinkByTime, alerts, blueLightScatter }

enum TimeRange { daily, weekly, monthly, yearly }

const Color _pageTop = Color(0xFF8ED8D2);
const Color _pageBottom = Color(0xFFF3D6AF);
const Color _cardBg = Color(0xFFFFFCF8);
const Color _softBorder = Color(0xFFE9E4DC);
const Color _textPrimary = Color(0xFF5B4636);
const Color _textSecondary = Color(0xFF8A7667);
const Color _mint = Color(0xFF2EC4B6);
const Color _orange = Color(0xFFF6A63A);

BoxDecoration _softCardDecoration({Color? color}) {
  return BoxDecoration(
    color: color ?? _cardBg,
    borderRadius: BorderRadius.circular(26),
    border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.2),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFB88956).withOpacity(0.12),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

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
  final String userId;
  final String firebaseUid;
  final String formId;
  final VoidCallback? onBackRequested;

  const ProgressPage({
    super.key,
    required this.userId,
    required this.firebaseUid,
    required this.formId,
    this.onBackRequested,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  TimeRange _range = TimeRange.daily;
  ProgressChartType _active = ProgressChartType.blinkByTime;
  DateTime _selectedDate = DateTime.now();
  bool _isGeneratingPdf = false;

  final Set<ProgressChartType> _selectedForHome = {};
bool _isUpdatingHomeCharts = false;

String _chartTypeToString(ProgressChartType type) {
  switch (type) {
    case ProgressChartType.blinkByTime:
      return 'blinkByTime';
    case ProgressChartType.alerts:
      return 'alerts';
    case ProgressChartType.blueLightScatter:
      return 'blueLightScatter';
  }
}

ProgressChartType? _chartTypeFromString(String value) {
  switch (value) {
    case 'blinkByTime':
      return ProgressChartType.blinkByTime;
    case 'alerts':
      return ProgressChartType.alerts;
    case 'blueLightScatter':
      return ProgressChartType.blueLightScatter;
    default:
      return null;
  }
}

@override
void initState() {
  super.initState();
  _loadHomeSelectedCharts();
}

Future<void> _loadHomeSelectedCharts() async {
  if (widget.formId.isEmpty) return;

  try {
    final uri = Uri.parse(
      '$backendBaseUrl/api/eye-health-form/get-home-selected-charts',
    ).replace(
      queryParameters: {
        'form_id': widget.formId,
        'main_account_id': widget.userId,
      },
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw 'Failed to load home charts (code: ${res.statusCode})';
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final charts = (data['home_selected_charts'] as List?) ?? [];

    final loadedCharts = charts
        .map((e) => _chartTypeFromString(e.toString()))
        .whereType<ProgressChartType>()
        .toSet();

    if (!mounted) return;

    setState(() {
      _selectedForHome
        ..clear()
        ..addAll(loadedCharts);
    });
  } catch (e) {
    debugPrint('Load home charts error: $e');
  }
}

Future<void> _updateHomeSelectedChartsInBackend() async {
  if (widget.formId.isEmpty) return;

  final chartStrings = _selectedForHome.map(_chartTypeToString).toList();

  final uri = Uri.parse(
    '$backendBaseUrl/api/eye-health-form/update-home-selected-charts/${widget.formId}',
  ).replace(
    queryParameters: {
      'main_account_id': widget.userId,
    },
  );

  final res = await http.put(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(chartStrings),
  );

  if (res.statusCode != 200) {
    throw 'Failed to update home charts (code: ${res.statusCode}) ${res.body}';
  }
}

Future<void> _toggleChartForHome(ProgressChartType chart) async {
  if (_isUpdatingHomeCharts) return;

  final previousCharts = Set<ProgressChartType>.from(_selectedForHome);

  setState(() {
    _isUpdatingHomeCharts = true;

    if (_selectedForHome.contains(chart)) {
      _selectedForHome.remove(chart);
    } else {
      _selectedForHome.add(chart);
    }
  });

  try {
    await _updateHomeSelectedChartsInBackend();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedForHome.contains(chart)
              ? 'Added to Home'
              : 'Removed from Home',
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _selectedForHome
        ..clear()
        ..addAll(previousCharts);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to update home charts: $e')),
    );
  } finally {
    if (!mounted) return;

    setState(() {
      _isUpdatingHomeCharts = false;
    });
  }
}

void _goHome() {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => HomePage(
        mainAccountId: widget.userId,
        firebaseUid: widget.firebaseUid,
      ),
    ),
  );
}

void _goSettings() {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => SettingsPage(
        mainAccountId: widget.userId,
        firebaseUid: widget.firebaseUid,

        smartLightEnabled: true,
        smartLightIntensity: 0.95,
        smartLightColor: const Color(0xFF06D6A0),
        onSmartLightToggle: (_) {},
        glassesLink: ValueNotifier({
          'user_id': null,
          'form_id': null,
          'name': null,
          'deviceId': null,
        }),
        onRequestLink: () {},
        activeFormId: widget.formId,
      ),
    ),
  );
}

void _goProgress() {
  // Already on Progress page
}

void _goAlerts() {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => NotificationsPage(
        userId: widget.userId,
        firebaseUid: widget.firebaseUid,
        formId: widget.formId,
      ),
    ),
  );
}

void _goTips() {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => TipsPage(
        mainAccountId: widget.userId,
        firebaseUid: widget.firebaseUid,
        formId: widget.formId,
      ),
    ),
  );
}

  Future<void> _pickFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDatePickerMode: _range == TimeRange.yearly
          ? DatePickerMode.year
          : DatePickerMode.day,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _orange,
              onPrimary: Colors.white,
              surface: _cardBg,
              onSurface: _textPrimary,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _orange,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          child: child!,
        );
      },
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

  Future<void> _generatePdfReport() async {
    if (widget.formId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active profile found')),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final path = await PdfReportService.generateAndSaveReport(
        userId: widget.userId,
        firebaseUid: widget.firebaseUid,
        formId: widget.formId,
        selectedDate: _selectedDateToApi(),
        rangeType: _rangeTypeToApi(_range),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF report saved successfully: $path'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
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
    final bool isSelected = _selectedForHome.contains(_active);

    final double chartCardHeight = _active == ProgressChartType.blinkByTime
        ? 520
        : 500;

    return Scaffold(
  backgroundColor: const Color(0xFFF6F3EE),
  extendBody: true,

  floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
  floatingActionButton: SmartProgressFab(
    selectedIndex: 2,
    onTap: _goProgress,
  ),

  bottomNavigationBar: SmartBottomNav(
    selectedIndex: 2,
    onHomeTap: _goHome,
    onSettingsTap: _goSettings,
    onProgressTap: _goProgress,
    onAlertsTap: _goAlerts,
    onTipsTap: _goTips,
  ),

  body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _pageTop,
            Color(0xFFF6F3EE),
            _pageBottom,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 125),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
  height: 46,
  child: Stack(
    alignment: Alignment.center,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: widget.onBackRequested,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.28),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.45),
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 21,
              color: _textPrimary,
            ),
          ),
        ),
      ),

      const Center(
        child: Text(
          'Progress',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: _textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
    ],
  ),
),
const SizedBox(height: 0),
const Center(
  child: Text(
    'Charts preview ',
    style: TextStyle(
      fontSize: 14,
      color: _textSecondary,
      fontWeight: FontWeight.w600,
    ),
  ),
),
              const SizedBox(height: 16),

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

              const SizedBox(height: 16),

              InkWell(
                onTap: _pickFilterDate,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: _softCardDecoration(),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _mint.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: _mint,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date Filter',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedDateLabel(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: _textSecondary,
                                fontWeight: FontWeight.w600,
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
                                fontSize: 11.5,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _textPrimary,
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),

              if (_active != ProgressChartType.blinkByTime) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _softBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Time Range:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<TimeRange>(
                          value: _range,
                          dropdownColor: _cardBg,
                          borderRadius: BorderRadius.circular(18),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _textSecondary,
                          ),
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
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
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              SizedBox(
                height: chartCardHeight,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  decoration: _softCardDecoration(),
                  child: _buildActiveChart(),
                ),
              ),

              const SizedBox(height: 18),

              // Select for home (Toggle)
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: (isSelected
                                ? Colors.grey.shade700
                                : _orange)
                            .withOpacity(0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: isSelected
                          ? Colors.grey.shade700
                          : _orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _isUpdatingHomeCharts ? null : () => _toggleChartForHome(_active),
                    icon: Icon(
                      isSelected
                          ? Icons.remove_circle_outline
                          : Icons.home_outlined,
                    ),
                    label: Text(
                      isSelected ? 'Remove from Home' : 'Add to Home',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white, width: 4),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFFFB25E),
                      Color(0xFF6FD3C8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _mint.withOpacity(0.25),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: _isGeneratingPdf ? null : _generatePdfReport,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.32),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.45),
                              ),
                            ),
                            child: _isGeneratingPdf
                                ? const Padding(
                                    padding: EdgeInsets.all(13),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isGeneratingPdf
                                      ? 'Generating PDF...'
                                      : 'Download PDF Report',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Create a summary based on your progress charts.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    height: 1.25,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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

    Widget _chip(String label, ProgressChartType type) {
    final selected = _active == type;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _active = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD0F2EE) : _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFB8E7E1) : _softBorder,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _mint.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 16, color: _mint),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? _mint : _textPrimary,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
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

class _EmptyChartState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accentColor;

  const _EmptyChartState({
    required this.icon,
    required this.title,
    required this.message,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.90)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB88956).withOpacity(0.10),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.38,
              child: Image.asset(
                'assets/images/home_chart.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    icon,
                    color: accentColor,
                    size: 58,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _textSecondary,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
  return const _EmptyChartState(
    icon: Icons.show_chart_rounded,
    title: 'No blink data yet',
    message:
        'Blink rate data will appear here once readings are available for the selected day.',
    accentColor: _mint,
  );
}

        final maxY = _calculateMaxY(data);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Blink Rate by Time',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Color(0xFF5B4636),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Shows average blink rate for each 3-hour period of the day.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF8A7667),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4, top: 4),
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: maxY <= 10 ? 2 : (maxY / 5),
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: const Color(0xFFE7DBCF),
                          strokeWidth: 1,
                          dashArray: [6, 4],
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: const Color(0xFFEEE3D8),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
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
                          reservedSize: 34,
                          interval: 2,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 46,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= data.length) {
                              return const SizedBox();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                data[i].label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  color: Color(0xFF8A7667),
                                  fontWeight: FontWeight.w600,
                                ),
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
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 10,
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
          return const _EmptyChartState(
            icon: Icons.notifications_none_rounded,
            title: 'No alerts yet',
            message:
                'No alerts were recorded for the selected time range. Your alert summary will appear here once data is available.',
            accentColor: _orange,
          );
        }

        final maxY = _calculateMaxY(alerts);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alerts by Type',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Color(0xFF5B4636),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Summarizes alert counts to highlight the most common issues.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF8A7667),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4, top: 4),
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: maxY <= 5 ? 1 : (maxY / 5),
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: const Color(0xFFE7DBCF),
                          strokeWidth: 1,
                          dashArray: [6, 4],
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: const Color(0xFFEEE3D8),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
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
                          reservedSize: 34,
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

                            final displayLabel = alerts[i].label.replaceAll('_', '\n');

                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                width: 70,
                                child: Text(
                                  displayLabel,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    height: 1.1,
                                    color: Color(0xFF8A7667),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Loaded from database.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8A7667),
              ),
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
          return const _EmptyChartState(
            icon: Icons.light_mode_outlined,
            title: 'No blue light data yet',
            message:
                'Blue light exposure points will appear here when readings are available for the selected range.',
            accentColor: _mint,
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
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Color(0xFF5B4636),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Shows the relationship between lux and blue light ratio for the selected ${_rangeLabel(widget.range)} range.',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF8A7667),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4, top: 4),
                child: ScatterChart(
                  ScatterChartData(
                    minX: 0,
                    maxX: maxX,
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: maxY > 1 ? (maxY / 5) : 0.2,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: const Color(0xFFE7DBCF),
                          strokeWidth: 1,
                          dashArray: [6, 4],
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: const Color(0xFFEEE3D8),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
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
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Color(0xFF5B4636),
                            ),
                          ),
                        ),
                        axisNameSize: 22,
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          interval: maxY > 1 ? (maxY / 5) : 0.2,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8A7667),
                                fontWeight: FontWeight.w600,
                              ),
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
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Color(0xFF5B4636),
                            ),
                          ),
                        ),
                        axisNameSize: 24,
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          interval: maxX > 100 ? (maxX / 5) : 20,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(0),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8A7667),
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Each dot represents one ${_rangeLabel(widget.range)} time bucket.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8A7667),
              ),
            ),
          ],
        );
      },
    );
  }
}
