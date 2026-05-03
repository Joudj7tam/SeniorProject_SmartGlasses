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
    backgroundColor: const Color(0xFFF8EFE5),
    body: Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFBF6),
                Color(0xFFF8EFE5),
                Color(0xFFFFE7BF),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),

        Positioned(
          top: -90,
          right: -80,
          child: _softCircle(210, const Color(0xFF2E9EA0), 0.08),
        ),
        Positioned(
          top: 170,
          left: -120,
          child: _softCircle(260, const Color(0xFFEFAA4B), 0.10),
        ),
        Positioned(
          bottom: -80,
          right: -60,
          child: _softCircle(220, const Color(0xFFEFAA4B), 0.14),
        ),

        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 36),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),

                  const SizedBox(height: 24),

                  _heroCard(),

                  const SizedBox(height: 22),

                  _sectionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Information',
                    children: [
                      _roundedTextField(
                        controller: _fullNameController,
                        hint: 'Full Name',
                        icon: Icons.badge_outlined,
                        validator: (v) =>
                            _requiredText(v, 'Full name is required'),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _pickDob,
                        borderRadius: BorderRadius.circular(22),
                        child: InputDecorator(
                          decoration: _roundedDecoration(
                            label: 'Date of Birth',
                            icon: Icons.calendar_month_outlined,
                          ),
                          child: Text(
                            _dob == null
                                ? 'Select date'
                                : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Color(0xFF8F8880),
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _dropdownField(
                        label: 'Gender',
                        value: _gender,
                        hint: 'Select gender',
                        icon: Icons.wc_rounded,
                        items: const ['Male', 'Female'],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                    ],
                  ),

                  _sectionCard(
                    icon: Icons.remove_red_eye_outlined,
                    title: 'Eye Conditions',
                    children: [
                      _chipRow(
                        children: [
                          _boolChip('Myopia', _myopia,
                              (v) => setState(() => _myopia = v)),
                          _boolChip('Hyperopia', _hyperopia,
                              (v) => setState(() => _hyperopia = v)),
                          _boolChip('Astigmatism', _astigmatism,
                              (v) => setState(() => _astigmatism = v)),
                        ],
                      ),
                    ],
                  ),

                  _sectionCard(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Chronic Diseases',
                    children: [
                      _chipRow(
                        children: [
                          _boolChip('Diabetes', _diabetes,
                              (v) => setState(() => _diabetes = v)),
                          _boolChip('Hypertension', _hypertension,
                              (v) => setState(() => _hypertension = v)),
                        ],
                      ),
                    ],
                  ),

                  _sectionCard(
                    icon: Icons.visibility_outlined,
                    title: 'Vision Aid',
                    children: [
                      _dropdownField(
                        label: 'Glasses / Contact Lenses',
                        value: _visionAid,
                        hint: 'Select one',
                        icon: Icons.remove_red_eye_outlined,
                        items: const ['Glasses', 'Contact Lenses', 'None'],
                        onChanged: (v) => setState(() => _visionAid = v),
                      ),
                    ],
                  ),

                  _sectionCard(
                    icon: Icons.medical_services_outlined,
                    title: 'Eye Surgeries',
                    children: [
                      _switchCard(
                        title: 'Have you had eye surgery?',
                        value: _hadSurgery,
                        onChanged: (v) => setState(() => _hadSurgery = v),
                      ),
                      const SizedBox(height: 14),
                      _roundedTextField(
                        controller: _surgeryDetailsController,
                        hint: 'Surgery Details',
                        icon: Icons.edit_note_rounded,
                        enabled: _hadSurgery,
                      ),
                    ],
                  ),

                  _sectionCard(
                    icon: Icons.light_mode_outlined,
                    title: 'Daily Habits & Lifestyle',
                    children: [
                      _sliderCard(
                        title: 'Screen time',
                        subtitle: 'hours/day',
                        valueLabel: '${_screenTimeHours.round()} h',
                        min: 0,
                        max: 16,
                        value: _screenTimeHours,
                        onChanged: (v) =>
                            setState(() => _screenTimeHours = v),
                      ),
                      const SizedBox(height: 14),
                      _dropdownField(
                        label: 'Lighting',
                        value: _lighting,
                        hint: 'Select lighting',
                        icon: Icons.lightbulb_outline_rounded,
                        items: const ['Bright', 'Normal', 'Dim'],
                        onChanged: (v) => setState(() => _lighting = v),
                      ),
                      const SizedBox(height: 14),
                      _sliderCard(
                        title: 'Sleep',
                        subtitle: 'hours/night',
                        valueLabel: '${_sleepHours.toStringAsFixed(0)} h',
                        min: 0,
                        max: 12,
                        value: _sleepHours,
                        onChanged: (v) => setState(() => _sleepHours = v),
                      ),
                      const SizedBox(height: 14),
                      _dropdownField(
                        label: 'Diet',
                        value: _diet,
                        hint: 'Select diet',
                        icon: Icons.restaurant_outlined,
                        items: const ['Healthy', 'Average', 'Unhealthy'],
                        onChanged: (v) => setState(() => _diet = v),
                      ),
                    ],
                  ),

                  _sectionCard(
                    icon: Icons.warning_amber_rounded,
                    title: 'Current Eye Symptoms',
                    children: [
                      _chipRow(
                        children: [
                          _boolChip('Dryness', _symDryness,
                              (v) => setState(() => _symDryness = v)),
                          _boolChip('Redness', _symRedness,
                              (v) => setState(() => _symRedness = v)),
                          _boolChip('Itching', _symItching,
                              (v) => setState(() => _symItching = v)),
                          _boolChip('Tearing', _symTearing,
                              (v) => setState(() => _symTearing = v)),
                          _boolChip('Eye strain', _symEyeStrain,
                              (v) => setState(() => _symEyeStrain = v)),
                          _boolChip('Blurred vision', _symBlurredVision,
                              (v) => setState(() => _symBlurredVision = v)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    height: 60,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFEFAA4B),
                        disabledBackgroundColor:
                            const Color(0xFFEFAA4B).withOpacity(0.55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Text(
                              'Save & Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _header() {
  return Row(
    children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE7DED4)),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Colors.black,
          ),
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Text(
          'Eye-Health Form',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: -0.6,
          ),
        ),
      ),
    ],
  );
}

Widget _heroCard() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF2E9EA0),
          Color(0xFF43B8B8),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF2E9EA0).withOpacity(0.25),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.remove_red_eye_outlined,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell us about your eyes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'This helps personalize your eye-health monitoring experience.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _sectionCard({
  required IconData icon,
  required String title,
  required List<Widget> children,
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.62),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(
        color: Colors.white.withOpacity(0.75),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.045),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEFAA4B).withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFFEFAA4B), size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

InputDecoration _roundedDecoration({String? label, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    floatingLabelBehavior:
        label == null ? FloatingLabelBehavior.never : FloatingLabelBehavior.auto,
    labelStyle: const TextStyle(
      color: Color(0xFF9B9690),
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: const Color(0xFF9B9690), size: 21),
    filled: true,
    fillColor: const Color(0xFFFFFAF4).withOpacity(0.88),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: Color(0xFFE4DDD4), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: Color(0xFF2E9EA0), width: 1.4),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: Color(0xFFE8E0D7), width: 1),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
    ),
  );
}

Widget _roundedTextField({
  required TextEditingController controller,
  required String hint,
  IconData? icon,
  String? Function(String?)? validator,
  bool enabled = true,
  int maxLines = 1,
}) {
  return TextFormField(
    controller: controller,
    validator: validator,
    enabled: enabled,
    maxLines: maxLines,
    cursorColor: const Color(0xFF2E9EA0),
    style: TextStyle(
      color: enabled ? Colors.black : const Color(0xFFB8B0A8),
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
    ),
    decoration: _roundedDecoration(icon: icon).copyWith(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFFAAA39B),
        fontSize: 15.5,
        fontWeight: FontWeight.w500,
      ),
      fillColor: enabled
          ? const Color(0xFFFFFAF4).withOpacity(0.88)
          : const Color(0xFFFFFAF4).withOpacity(0.48),
    ),
  );
}

Widget _dropdownField({
  required String label,
  required String? value,
  required String hint,
  required List<String> items,
  required ValueChanged<String?> onChanged,
  IconData? icon,
}) {
  return InputDecorator(
    decoration: _roundedDecoration(label: label, icon: icon),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        hint: Text(
          hint,
          style: const TextStyle(
            color: Color(0xFFAAA39B),
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF9B9690),
          size: 24,
        ),
        isExpanded: true,
        dropdownColor: const Color(0xFFFFFAF4),
        borderRadius: BorderRadius.circular(20),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
        ),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

Widget _switchCard({
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFAF4).withOpacity(0.88),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE4DDD4), width: 1),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.healing_outlined,
          color: Color(0xFF9B9690),
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8F8880),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Transform.scale(
          scale: 0.86,
          child: Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFFEFAA4B),
            inactiveThumbColor: const Color(0xFF8C8176),
            inactiveTrackColor: const Color(0xFFF0E4D8),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

Widget _chipRow({required List<Widget> children}) {
  return Wrap(
    spacing: 9,
    runSpacing: 11,
    children: children,
  );
}

Widget _boolChip(String label, bool value, ValueChanged<bool> onChanged) {
  return FilterChip(
    label: Text(
      value ? '✓ $label' : label,
      style: TextStyle(
        color: value ? Colors.black : const Color(0xFF3C3630),
        fontSize: 14.5,
        fontWeight: value ? FontWeight.w800 : FontWeight.w600,
      ),
    ),
    selected: value,
    showCheckmark: false,
    onSelected: onChanged,
    backgroundColor: const Color(0xFFFFFAF4).withOpacity(0.88),
    selectedColor: const Color(0xFFF5CE94),
    side: BorderSide(
      color: value ? const Color(0xFFEFAA4B) : const Color(0xFFE4DDD4),
      width: value ? 1.2 : 1,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    elevation: 0,
    pressElevation: 0,
  );
}

Widget _sliderCard({
  required String title,
  required String subtitle,
  required String valueLabel,
  required double min,
  required double max,
  required double value,
  required ValueChanged<double> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFAF4).withOpacity(0.88),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE4DDD4), width: 1),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF2E9EA0).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF2E9EA0),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF9B9690),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFAA4B).withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                valueLabel,
                style: const TextStyle(
                  color: Color(0xFFB66F12),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFEFAA4B),
            inactiveTrackColor: const Color(0xFFE0D8CF),
            thumbColor: const Color(0xFFEFAA4B),
            overlayColor: const Color(0xFFEFAA4B).withOpacity(0.15),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.3),
            activeTickMarkColor: const Color(0xFFFFD8A2),
            inactiveTickMarkColor: const Color(0xFFCFC8BF),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

Widget _softCircle(double size, Color color, double opacity) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withOpacity(opacity),
      shape: BoxShape.circle,
    ),
  );
}

}
