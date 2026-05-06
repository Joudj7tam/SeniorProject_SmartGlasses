import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const String backendBaseUrl = 'http://10.0.2.2:8080';

class PdfChartPoint {
  final String label;
  final double value;

  PdfChartPoint({
    required this.label,
    required this.value,
  });

  factory PdfChartPoint.fromJson(Map<String, dynamic> json) {
    return PdfChartPoint(
      label: (json['label'] ?? '').toString(),
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PdfScatterPoint {
  final double x;
  final double y;
  final String label;

  PdfScatterPoint({
    required this.x,
    required this.y,
    required this.label,
  });

  factory PdfScatterPoint.fromJson(Map<String, dynamic> json) {
    return PdfScatterPoint(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      label: (json['label'] ?? '').toString(),
    );
  }
}

class _ReportUser {
  final String phone;

  _ReportUser({required this.phone});

  factory _ReportUser.fromJson(Map<String, dynamic> json) {
    return _ReportUser(
      phone: (json['phone'] ?? '').toString(),
    );
  }
}

class _ReportForm {
  final String fullName;
  final DateTime dateOfBirth;
  final String gender;
  final List<String> previousEyeConditions;
  final List<String> chronicDiseases;
  final bool usesGlasses;
  final bool usesContactLenses;
  final String? eyeSurgeryHistory;
  final int screenTimeHours;
  final String lightingConditions;
  final int sleepHours;
  final String? diet;
  final List<String> currentEyeSymptoms;
  final bool smartLightEnabled;

  _ReportForm({
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.previousEyeConditions,
    required this.chronicDiseases,
    required this.usesGlasses,
    required this.usesContactLenses,
    required this.eyeSurgeryHistory,
    required this.screenTimeHours,
    required this.lightingConditions,
    required this.sleepHours,
    required this.diet,
    required this.currentEyeSymptoms,
    required this.smartLightEnabled,
  });

  factory _ReportForm.fromJson(Map<String, dynamic> json) {
    return _ReportForm(
      fullName: (json['full_name'] ?? '').toString(),
      dateOfBirth: DateTime.tryParse((json['date_of_birth'] ?? '').toString()) ??
          DateTime.now(),
      gender: (json['gender'] ?? '').toString(),
      previousEyeConditions: _list(json['previous_eye_conditions']),
      chronicDiseases: _list(json['chronic_diseases']),
      usesGlasses: json['uses_glasses'] == true,
      usesContactLenses: json['uses_contact_lenses'] == true,
      eyeSurgeryHistory: json['eye_surgery_history']?.toString(),
      screenTimeHours: _int(json['screen_time_hours']),
      lightingConditions: (json['lighting_conditions'] ?? '').toString(),
      sleepHours: _int(json['sleep_hours']),
      diet: json['diet']?.toString(),
      currentEyeSymptoms: _list(json['current_eye_symptoms']),
      smartLightEnabled: json['smart_light_enabled'] == true,
    );
  }

  static List<String> _list(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class PdfReportService {
  static Future<String> generateAndSaveReport({
    required String userId,
    required String firebaseUid,
    required String formId,
    required String selectedDate,
    required String rangeType,
  }) async {
    if (userId.isEmpty || firebaseUid.isEmpty || formId.isEmpty) {
      throw Exception('Missing user or profile information');
    }

    final user = await _fetchUser(firebaseUid);
    final form = await _fetchForm(formId: formId, userId: userId);

    final blinkData = await _fetchBlinkByTime(
      userId: userId,
      formId: formId,
      selectedDate: selectedDate,
    );

    final alertsData = await _fetchAlerts(
      userId: userId,
      formId: formId,
      selectedDate: selectedDate,
      rangeType: rangeType,
    );

    final blueLightData = await _fetchBlueLight(
      userId: userId,
      formId: formId,
      selectedDate: selectedDate,
      rangeType: rangeType,
    );

    final pdfBytes = await _buildPdf(
      user: user,
      form: form,
      selectedDate: selectedDate,
      rangeType: rangeType,
      blinkData: blinkData,
      alertsData: alertsData,
      blueLightData: blueLightData,
    );

    final safeName = form.fullName.trim().isEmpty
        ? 'clipview_report'
        : form.fullName.trim().replaceAll(RegExp(r'[^A-Za-z0-9_ -]'), '_');

    final fileName = 'CLIPVIEW_${safeName}_$selectedDate';

    final savedPath = await _savePdfToDownloads(
      fileName: '$fileName.pdf',
      bytes: pdfBytes,
    );

    return savedPath;

    return savedPath;
  }

  static Future<_ReportUser> _fetchUser(String firebaseUid) async {
    final uri = Uri.parse('$backendBaseUrl/api/users/$firebaseUid');

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load user data (${res.statusCode})');
    }

    return _ReportUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<_ReportForm> _fetchForm({
    required String formId,
    required String userId,
  }) async {
    final uri = Uri.parse(
      '$backendBaseUrl/api/eye-health-form/get/$formId',
    ).replace(
      queryParameters: {
        'main_account_id': userId,
      },
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load profile form (${res.statusCode})');
    }

    return _ReportForm.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<List<PdfChartPoint>> _fetchBlinkByTime({
    required String userId,
    required String formId,
    required String selectedDate,
  }) async {
    final uri = Uri.parse(
      '$backendBaseUrl/api/chart-metrics/blink-by-time',
    ).replace(
      queryParameters: {
        'user_id': userId,
        'form_id': formId,
        'selected_date': selectedDate,
      },
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load blink chart (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rawData = decoded['data'] as List? ?? [];

    return rawData
        .map((e) => PdfChartPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<PdfChartPoint>> _fetchAlerts({
    required String userId,
    required String formId,
    required String selectedDate,
    required String rangeType,
  }) async {
    final uri = Uri.parse(
      '$backendBaseUrl/api/notifications/alert-count',
    ).replace(
      queryParameters: {
        'user_id': userId,
        'form_id': formId,
        'range_type': rangeType,
        'selected_date': selectedDate,
      },
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load alerts chart (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rawData = decoded['data'] as List? ?? [];

    return rawData
        .map((e) => PdfChartPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<PdfScatterPoint>> _fetchBlueLight({
    required String userId,
    required String formId,
    required String selectedDate,
    required String rangeType,
  }) async {
    final uri = Uri.parse(
      '$backendBaseUrl/api/chart-metrics/blue-light-scatter',
    ).replace(
      queryParameters: {
        'user_id': userId,
        'form_id': formId,
        'range_type': rangeType,
        'selected_date': selectedDate,
      },
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load blue light chart (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rawData = decoded['data'] as List? ?? [];

    return rawData
        .map((e) => PdfScatterPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<int>> _buildPdf({
    required _ReportUser user,
    required _ReportForm form,
    required String selectedDate,
    required String rangeType,
    required List<PdfChartPoint> blinkData,
    required List<PdfChartPoint> alertsData,
    required List<PdfScatterPoint> blueLightData,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            _coverHeader(form.fullName, selectedDate),
            pw.SizedBox(height: 18),

            _sectionTitle('User Summary'),
            _infoGrid([
              _InfoPair('Full Name', form.fullName),
              _InfoPair('Phone Number', user.phone.isEmpty ? '-' : user.phone),
              _InfoPair('Date of Birth', _date(form.dateOfBirth)),
              _InfoPair('Gender', form.gender),
            ]),

            pw.SizedBox(height: 16),
            _sectionTitle('Eye-Health Form Details'),
            _infoGrid([
              _InfoPair(
                'Previous Eye Conditions',
                form.previousEyeConditions.isEmpty
                    ? 'None'
                    : form.previousEyeConditions.map(_humanize).join(', '),
              ),
              _InfoPair(
                'Chronic Diseases',
                form.chronicDiseases.isEmpty
                    ? 'None'
                    : form.chronicDiseases.map(_humanize).join(', '),
              ),
              _InfoPair('Uses Glasses', form.usesGlasses ? 'Yes' : 'No'),
              _InfoPair(
                'Uses Contact Lenses',
                form.usesContactLenses ? 'Yes' : 'No',
              ),
              _InfoPair(
                'Eye Surgery History',
                (form.eyeSurgeryHistory == null ||
                        form.eyeSurgeryHistory!.trim().isEmpty)
                    ? 'No surgeries reported'
                    : form.eyeSurgeryHistory!.trim(),
              ),
              _InfoPair('Screen Time', '${form.screenTimeHours} h/day'),
              _InfoPair('Lighting Conditions', form.lightingConditions),
              _InfoPair('Sleep Hours', '${form.sleepHours} h/night'),
              _InfoPair('Diet', form.diet ?? '-'),
              _InfoPair(
                'Current Eye Symptoms',
                form.currentEyeSymptoms.isEmpty
                    ? 'None'
                    : form.currentEyeSymptoms.map(_humanize).join(', '),
              ),
              _InfoPair(
                'Smart Light',
                form.smartLightEnabled ? 'Enabled' : 'Disabled',
              ),
            ]),

            pw.SizedBox(height: 18),
            _sectionTitle('Charts Snapshot'),
            pw.Text(
              'Selected date: $selectedDate | Range for alerts and blue light: ${_humanize(rangeType)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),

            pw.SizedBox(height: 12),
            _chartCard(
              title: 'Blink by Time Chart',
              subtitle: 'Average blink rate grouped into 3-hour buckets.',
              child: _barChart(
                data: blinkData,
                color: PdfColor.fromHex('#2EC4B6'),
                emptyMessage: 'No blink data available for this date.',
              ),
            ),

            pw.SizedBox(height: 14),
            _chartCard(
              title: 'Alerts Chart',
              subtitle: 'Alert counts grouped by alert type.',
              child: _barChart(
                data: alertsData,
                color: PdfColor.fromHex('#FF9F1C'),
                emptyMessage: 'No alerts available for this selected period.',
              ),
            ),

            pw.SizedBox(height: 14),
            _chartCard(
              title: 'Blue Light Scatter Chart',
              subtitle: 'Relationship between lux and blue light ratio.',
              child: _scatterChart(
                data: blueLightData,
                emptyMessage: 'No blue light data available for this period.',
              ),
            ),

            pw.SizedBox(height: 18),
            _footerNote(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _coverHeader(String name, String selectedDate) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(18),
        gradient: pw.LinearGradient(
          colors: [
            PdfColor.fromHex('#FF9F1C'),
            PdfColor.fromHex('#2EC4B6'),
          ],
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CLIPVIEW Eye-Health Report',
            style: pw.TextStyle(
              fontSize: 24,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            name,
            style: const pw.TextStyle(
              fontSize: 13,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated for selected date: $selectedDate',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.Container(
            width: 6,
            height: 18,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#2EC4B6'),
              borderRadius: pw.BorderRadius.circular(4),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoGrid(List<_InfoPair> items) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FFF7EE'),
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: PdfColor.fromHex('#F1E4D3')),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                item.label,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                item.value,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _chartCard({
    required String title,
    required String subtitle,
    required pw.Widget child,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: PdfColor.fromHex('#E9E2DA')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  static pw.Widget _barChart({
    required List<PdfChartPoint> data,
    required PdfColor color,
    required String emptyMessage,
  }) {
    if (data.isEmpty) {
      return pw.Container(
        height: 90,
        alignment: pw.Alignment.center,
        child: pw.Text(
          emptyMessage,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      );
    }

    final maxValue = data
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, double.infinity)
        .toDouble();

    return pw.Column(
      children: [
        pw.Container(
          height: 130,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: data.map((point) {
              final height = (point.value / maxValue) * 110;
              return pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 3),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        point.value.toStringAsFixed(
                          point.value % 1 == 0 ? 0 : 1,
                        ),
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Container(
                        height: height,
                        decoration: pw.BoxDecoration(
                          color: color,
                          borderRadius: pw.BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: data.take(8).map((point) {
            return pw.Expanded(
              child: pw.Text(
                point.label,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 6),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _scatterChart({
    required List<PdfScatterPoint> data,
    required String emptyMessage,
  }) {
    if (data.isEmpty) {
      return pw.Container(
        height: 120,
        alignment: pw.Alignment.center,
        child: pw.Text(
          emptyMessage,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      );
    }

    final maxX = data.map((e) => e.x).reduce((a, b) => a > b ? a : b);
    final maxY = data.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    const chartWidth = 460.0;
    const chartHeight = 150.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: chartWidth,
          height: chartHeight,
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8FBFB'),
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: PdfColor.fromHex('#D9EDEC')),
          ),
          child: pw.Stack(
            children: [
              ...data.take(40).map((point) {
                final left = maxX <= 0 ? 0.0 : (point.x / maxX) * 430;
                final bottom = maxY <= 0 ? 0.0 : (point.y / maxY) * 125;

                return pw.Positioned(
                  left: left,
                  bottom: bottom,
                  child: pw.Container(
                    width: 7,
                    height: 7,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#2EC4B6'),
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'X-axis: Lux | Y-axis: Blue light ratio',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _footerNote() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#CBF3F0'),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Text(
        'This report summarizes selected eye-health profile information and progress charts generated from CLIPVIEW monitoring data.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
      ),
    );
  }

  static String _date(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _humanize(String value) {
    final cleaned = value.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return value;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  static Future<String> _savePdfToDownloads({
    required String fileName,
    required List<int> bytes,
  }) async {
    if (!Platform.isAndroid) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }

    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'CLIPVIEW';

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');

    await tempFile.writeAsBytes(bytes, flush: true);

    final mediaStore = MediaStore();

    final saveInfo = await mediaStore.saveFile(
      tempFilePath: tempFile.path,
      dirType: DirType.download,
      dirName: DirName.download,
    );

    if (saveInfo == null) {
      throw Exception('Failed to save PDF to Downloads');
    }

    return 'Downloads/CLIPVIEW/$fileName';
  }

}

class _InfoPair {
  final String label;
  final String value;

  _InfoPair(this.label, this.value);
}