import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'main.dart';

const String backendBaseUrl = 'http://10.0.2.2:8080';

class ProfileResult {
  final String formId;
  final String fullName;
  const ProfileResult({required this.formId, required this.fullName});
}

class HealthFormPage extends StatefulWidget {
  final String mainAccountId;
  final String? firebaseUid;
  final bool goHomeAfterSave;
  const HealthFormPage({
    super.key,
    required this.mainAccountId,
    this.firebaseUid,
    required this.goHomeAfterSave,
  });

  @override
  State<HealthFormPage> createState() => _HealthFormPageState();
}

class _HealthFormPageState extends State<HealthFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Personal info
  final _fullNameController = TextEditingController();
  DateTime? _dob;
  String? _gender; // 'Male'/'Female'

  // Previous eye conditions
  bool _myopia = false;
  bool _hyperopia = false;
  bool _astigmatism = false;

  // Chronic diseases
  bool _diabetes = false;
  bool _hypertension = false;

  // Glasses / contacts
  String? _visionAid; // 'Glasses' / 'Contact Lenses' / 'None'

  // Eye surgeries
  bool _hadSurgery = false;
  final _surgeryDetailsController = TextEditingController();

  // Daily habits & lifestyle
  double _screenTimeHours = 4; // 0 - 16
  String? _lighting; // 'Bright'/'Normal'/'Dim'
  double _sleepHours = 7; // 0 - 12
  String? _diet; // 'Healthy'/'Average'/'Unhealthy'

  // Current eye symptoms
  bool _symDryness = false;
  bool _symRedness = false;
  bool _symItching = false;
  bool _symTearing = false;
  bool _symEyeStrain = false;
  bool _symBlurredVision = false;

  bool _submitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _surgeryDetailsController.dispose();
    super.dispose();
  }

  String? _requiredText(String? v, String msg) {
    if ((v ?? '').trim().isEmpty) return msg;
    return null;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    // Required: DOB + Gender
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date of birth is required')),
      );
      return;
    }
    if (_gender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gender is required')));
      return;
    }
    if (_visionAid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select glasses/contact/none')),
      );
      return;
    }

    if (_hadSurgery && _surgeryDetailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add surgery details')),
      );
      return;
    }

    if (_lighting == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lighting is required')));
      return;
    }

    if (_diet == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Diet is required')));
      return;
    }

    setState(() => _submitting = true);

    try {
      final fullName = _fullNameController.text.trim();

      // Build lists as backend expects List<String>
      final prev = <String>[];
      if (_myopia) prev.add('myopia');
      if (_hyperopia) prev.add('hyperopia');
      if (_astigmatism) prev.add('astigmatism');

      final chronic = <String>[];
      if (_diabetes) chronic.add('diabetes');
      if (_hypertension) chronic.add('hypertension');

      final symptoms = <String>[];
      if (_symDryness) symptoms.add('dryness');
      if (_symRedness) symptoms.add('redness');
      if (_symItching) symptoms.add('itching');
      if (_symTearing) symptoms.add('tearing');
      if (_symEyeStrain) symptoms.add('eye_strain');
      if (_symBlurredVision) symptoms.add('blurred_vision');

      final uri = Uri.parse('$backendBaseUrl/api/eye-health-form/add');

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'main_account_id': widget.mainAccountId,
          'full_name': fullName,
          'date_of_birth': _dob!.toIso8601String(),
          'gender': _gender!,
          'previous_eye_conditions': prev,
          'chronic_diseases': chronic,
          'uses_glasses': _visionAid == 'Glasses',
          'uses_contact_lenses': _visionAid == 'Contact Lenses',
          'eye_surgery_history': _hadSurgery
              ? _surgeryDetailsController.text.trim()
              : null,
          'screen_time_hours': _screenTimeHours.round(),
          'lighting_conditions': _lighting!,
          'sleep_hours': _sleepHours.round(),
          'diet': _diet,
          'current_eye_symptoms': symptoms,
        }),
      );

      if (res.statusCode != 200) {
        final decoded = jsonDecode(res.body);
        final msg = (decoded is Map && decoded['detail'] != null)
            ? decoded['detail'].toString()
            : 'Submit failed (code: ${res.statusCode})';
        throw msg;
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final formId = (data['id'] ?? '').toString();

      if (formId.isEmpty) throw 'Backend did not return formId';

      if (!mounted) return;

      if (widget.goHomeAfterSave) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomePage(
              mainAccountId: widget.mainAccountId,
              firebaseUid: widget.firebaseUid!, // لازم تكون موجودة هنا
            ),
          ),
        );
      } else {
        Navigator.pop(
          context,
          ProfileResult(formId: formId, fullName: fullName),
        );
      }
      return;
    } on SocketException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot connect to server. Make sure backend is running.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eye-Health Information Form')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle('Personal Information'),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _requiredText(v, 'Full name is required'),
                ),
                const SizedBox(height: 12),

                // DOB picker
                InkWell(
                  onTap: _pickDob,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _dob == null
                          ? 'Select date'
                          : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Gender
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _gender,
                      hint: const Text('Select gender'),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                _sectionTitle('Previous Eye Conditions'),
                _chipRow(
                  children: [
                    _boolChip(
                      'Myopia',
                      _myopia,
                      (v) => setState(() => _myopia = v),
                    ),
                    _boolChip(
                      'Hyperopia',
                      _hyperopia,
                      (v) => setState(() => _hyperopia = v),
                    ),
                    _boolChip(
                      'Astigmatism',
                      _astigmatism,
                      (v) => setState(() => _astigmatism = v),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                _sectionTitle('Chronic Diseases'),
                _chipRow(
                  children: [
                    _boolChip(
                      'Diabetes',
                      _diabetes,
                      (v) => setState(() => _diabetes = v),
                    ),
                    _boolChip(
                      'Hypertension',
                      _hypertension,
                      (v) => setState(() => _hypertension = v),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                _sectionTitle('Glasses / Contact Lenses'),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Do you use glasses or contact lenses?',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _visionAid,
                      hint: const Text('Select one'),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Glasses',
                          child: Text('Glasses'),
                        ),
                        DropdownMenuItem(
                          value: 'Contact Lenses',
                          child: Text('Contact Lenses'),
                        ),
                        DropdownMenuItem(value: 'None', child: Text('None')),
                      ],
                      onChanged: (v) => setState(() => _visionAid = v),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                _sectionTitle('History of Eye Surgeries'),
                SwitchListTile(
                  title: const Text('Have you had eye surgery?'),
                  value: _hadSurgery,
                  onChanged: (v) => setState(() => _hadSurgery = v),
                ),
                if (_hadSurgery) ...[
                  TextFormField(
                    controller: _surgeryDetailsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Surgery details',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                const SizedBox(height: 18),
                _sectionTitle('Daily Habits & Lifestyle'),
                _sliderCard(
                  title: 'Screen time (hours/day)',
                  valueLabel: '${_screenTimeHours.round()} h',
                  min: 0,
                  max: 16,
                  value: _screenTimeHours,
                  onChanged: (v) => setState(() => _screenTimeHours = v),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Lighting',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _lighting,
                      hint: const Text('Select lighting'),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Bright',
                          child: Text('Bright'),
                        ),
                        DropdownMenuItem(
                          value: 'Normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(value: 'Dim', child: Text('Dim')),
                      ],
                      onChanged: (v) => setState(() => _lighting = v),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _sliderCard(
                  title: 'Sleep (hours/night)',
                  valueLabel: '${_sleepHours.toStringAsFixed(0)} h',
                  min: 0,
                  max: 12,
                  value: _sleepHours,
                  onChanged: (v) => setState(() => _sleepHours = v),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Diet',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _diet,
                      hint: const Text('Select diet'),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Healthy',
                          child: Text('Healthy'),
                        ),
                        DropdownMenuItem(
                          value: 'Average',
                          child: Text('Average'),
                        ),
                        DropdownMenuItem(
                          value: 'Unhealthy',
                          child: Text('Unhealthy'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _diet = v),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                _sectionTitle('Current Eye Symptoms'),
                _chipRow(
                  children: [
                    _boolChip(
                      'Dryness',
                      _symDryness,
                      (v) => setState(() => _symDryness = v),
                    ),
                    _boolChip(
                      'Redness',
                      _symRedness,
                      (v) => setState(() => _symRedness = v),
                    ),
                    _boolChip(
                      'Itching',
                      _symItching,
                      (v) => setState(() => _symItching = v),
                    ),
                    _boolChip(
                      'Tearing',
                      _symTearing,
                      (v) => setState(() => _symTearing = v),
                    ),
                    _boolChip(
                      'Eye strain',
                      _symEyeStrain,
                      (v) => setState(() => _symEyeStrain = v),
                    ),
                    _boolChip(
                      'Blurred vision',
                      _symBlurredVision,
                      (v) => setState(() => _symBlurredVision = v),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save & Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _chipRow({required List<Widget> children}) {
    return Wrap(spacing: 10, runSpacing: 10, children: children);
  }

  Widget _boolChip(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
    );
  }

  Widget _sliderCard({
    required String title,
    required String valueLabel,
    required double min,
    required double max,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              Text(
                valueLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
