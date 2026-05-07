import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// UI-only page to display all eye health form info (dummy data for now).
/// Later 'll replace the dummy data with API response from backend.
const String backendBaseUrl = 'http://10.0.2.2:8080';

const Color _profileCream = Color(0xFFFFF6EA);
const Color _profileOrange = Color(0xFFFF9F1C);
const Color _profileOrangeLight = Color(0xFFFFD49A);
const Color _profileMint = Color(0xFF2EC4B6);
const Color _profileMintLight = Color(0xFFD8F6F2);
const Color _profileText = Color(0xFF3D2B22);
const Color _profileMuted = Color(0xFF9B8170);
const Color _profileCard = Color(0xFFFFFCF8);
const Color _profileBorder = Color(0xFFF1DEC9);

class EyeHealthProfilePage extends StatefulWidget {
  final String mainAccountId;
  final String firebaseUid;
  final String formId;

  const EyeHealthProfilePage({
    super.key,
    required this.mainAccountId,
    required this.firebaseUid,
    required this.formId,
  });

  @override
  State<EyeHealthProfilePage> createState() => _EyeHealthProfilePageState();
}

class _EyeHealthProfilePageState extends State<EyeHealthProfilePage> {
  final _editFormKey = GlobalKey<FormState>();
  EyeHealthFormViewData? _formData;
  UserAccountViewData? _userData;

  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isSaving = false;
  String? _error;

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _surgeryDetailsController = TextEditingController();

  DateTime? _editDob;
  String? _editGender;

  bool _myopia = false;
  bool _hyperopia = false;
  bool _astigmatism = false;

  bool _diabetes = false;
  bool _hypertension = false;

  String? _visionAid;

  bool _hadSurgery = false;
  double _screenTimeHours = 4;
  String? _lighting;
  double _sleepHours = 7;
  String? _diet;

  bool _symDryness = false;
  bool _symRedness = false;
  bool _symItching = false;
  bool _symTearing = false;
  bool _symEyeStrain = false;
  bool _symBlurredVision = false;

  bool _smartLightEnabled = false;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _surgeryDetailsController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final formUri = Uri.parse(
        '$backendBaseUrl/api/eye-health-form/get/${widget.formId}',
      ).replace(
        queryParameters: {
          'main_account_id': widget.mainAccountId,
        },
      );

      final userUri = Uri.parse(
        '$backendBaseUrl/api/users/${widget.firebaseUid}',
      );

      final responses = await Future.wait([
        http.get(formUri),
        http.get(userUri),
      ]);

      final formResponse = responses[0];
      final userResponse = responses[1];

      if (formResponse.statusCode != 200) {
        throw 'Failed to load form data (${formResponse.statusCode})';
      }

      if (userResponse.statusCode != 200) {
        throw 'Failed to load user data (${userResponse.statusCode})';
      }

      final formJson = jsonDecode(formResponse.body) as Map<String, dynamic>;
      final userJson = jsonDecode(userResponse.body) as Map<String, dynamic>;

      setState(() {
        _formData = EyeHealthFormViewData.fromJson(formJson);
        _userData = UserAccountViewData.fromJson(userJson);
        _isLoading = false;
      });
    } on SocketException {
      setState(() {
        _error = 'Cannot connect to server. Make sure backend is running.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  void _enterEditMode() {
    final form = _formData;
    final user = _userData;
    if (form == null || user == null) return;

    _fullNameController.text = form.fullName;
    _emailController.text = user.email;
    _phoneController.text = user.phone;

    _editDob = form.dateOfBirth;
    _editGender = form.gender.isEmpty ? null : form.gender;

    _myopia = form.previousEyeConditions.contains('myopia');
    _hyperopia = form.previousEyeConditions.contains('hyperopia');
    _astigmatism = form.previousEyeConditions.contains('astigmatism');

    _diabetes = form.chronicDiseases.contains('diabetes');
    _hypertension = form.chronicDiseases.contains('hypertension');

    if (form.usesGlasses) {
      _visionAid = 'Glasses';
    } else if (form.usesContactLenses) {
      _visionAid = 'Contact Lenses';
    } else {
      _visionAid = 'None';
    }

    final surgeryText = form.eyeSurgeryHistory?.trim() ?? '';
    _hadSurgery = surgeryText.isNotEmpty;
    _surgeryDetailsController.text = surgeryText;

    _screenTimeHours = form.screenTimeHours.toDouble().clamp(0, 16);
    _lighting = form.lightingConditions.isEmpty ? null : form.lightingConditions;

    _sleepHours = form.sleepHours.toDouble().clamp(0, 12);
    _diet = (form.diet == null || form.diet!.isEmpty) ? null : form.diet;

    _symDryness = form.currentEyeSymptoms.contains('dryness');
    _symRedness = form.currentEyeSymptoms.contains('redness');
    _symItching = form.currentEyeSymptoms.contains('itching');
    _symTearing = form.currentEyeSymptoms.contains('tearing');
    _symEyeStrain = form.currentEyeSymptoms.contains('eye_strain');
    _symBlurredVision = form.currentEyeSymptoms.contains('blurred_vision');

    _smartLightEnabled = form.smartLightEnabled;

    setState(() => _isEditMode = true);
  }

  void _cancelEditMode() {
    FocusScope.of(context).unfocus();
    setState(() => _isEditMode = false);
  }

  String? _requiredText(String? value, String message) {
    if ((value ?? '').trim().isEmpty) return message;
    return null;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _editDob ?? DateTime(now.year - 20, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() => _editDob = picked);
    }
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();

    final isValid = _editFormKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_editDob == null) {
      _showSnack('Date of birth is required');
      return;
    }

    if (_editGender == null) {
      _showSnack('Gender is required');
      return;
    }

    if (_visionAid == null) {
      _showSnack('Please select glasses/contact/none');
      return;
    }

    if (_lighting == null) {
      _showSnack('Lighting is required');
      return;
    }

    if (_diet == null) {
      _showSnack('Diet is required');
      return;
    }

    if (_hadSurgery && _surgeryDetailsController.text.trim().isEmpty) {
      _showSnack('Please add surgery details');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final previousConditions = <String>[];
      if (_myopia) previousConditions.add('myopia');
      if (_hyperopia) previousConditions.add('hyperopia');
      if (_astigmatism) previousConditions.add('astigmatism');

      final chronicDiseases = <String>[];
      if (_diabetes) chronicDiseases.add('diabetes');
      if (_hypertension) chronicDiseases.add('hypertension');

      final symptoms = <String>[];
      if (_symDryness) symptoms.add('dryness');
      if (_symRedness) symptoms.add('redness');
      if (_symItching) symptoms.add('itching');
      if (_symTearing) symptoms.add('tearing');
      if (_symEyeStrain) symptoms.add('eye_strain');
      if (_symBlurredVision) symptoms.add('blurred_vision');

      final userUri = Uri.parse(
        '$backendBaseUrl/api/users/${widget.firebaseUid}',
      );

      final formUri = Uri.parse(
        '$backendBaseUrl/api/eye-health-form/update/${widget.formId}',
      ).replace(queryParameters: {'main_account_id': widget.mainAccountId});

      final userPayload = {
        'phone': _phoneController.text.trim(),
      };

      final formPayload = {
        'full_name': _fullNameController.text.trim(),
        'date_of_birth': _editDob!.toIso8601String(),
        'gender': _editGender,
        'previous_eye_conditions': previousConditions,
        'chronic_diseases': chronicDiseases,
        'uses_glasses': _visionAid == 'Glasses',
        'uses_contact_lenses': _visionAid == 'Contact Lenses',
        'eye_surgery_history':
            _hadSurgery ? _surgeryDetailsController.text.trim() : null,
        'screen_time_hours': _screenTimeHours.round(),
        'lighting_conditions': _lighting,
        'sleep_hours': _sleepHours.round(),
        'diet': _diet,
        'current_eye_symptoms': symptoms,
        'smart_light_enabled': _smartLightEnabled,
      };

      final responses = await Future.wait([
        http.put(
          userUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(userPayload),
        ),
        http.put(
          formUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(formPayload),
        ),
      ]);

      final userResponse = responses[0];
      final formResponse = responses[1];

      if (userResponse.statusCode != 200) {
        throw _extractErrorMessage(userResponse, 'Failed to update account');
      }

      if (formResponse.statusCode != 200) {
        throw _extractErrorMessage(formResponse, 'Failed to update profile');
      }

      final userDecoded = jsonDecode(userResponse.body) as Map<String, dynamic>;
      final formDecoded = jsonDecode(formResponse.body) as Map<String, dynamic>;

      final updatedUserJson =
          (userDecoded['data'] as Map<String, dynamic>?) ?? userDecoded;

      final updatedFormJson =
          (formDecoded['data'] as Map<String, dynamic>?) ?? formDecoded;

      if (!mounted) return;

      setState(() {
        _userData = UserAccountViewData.fromJson(updatedUserJson);
        _formData = EyeHealthFormViewData.fromJson(updatedFormJson);
        _isEditMode = false;
        _isSaving = false;
      });

      _showSnack('Profile updated successfully');

      Navigator.pop(context, true);
      
    } on SocketException {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('Cannot connect to server. Make sure backend is running.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack(e.toString());
    }
  }

  String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }

      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}

    return '$fallback (${response.statusCode})';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  @override
Widget build(BuildContext context) {
  final form = _formData;
  final user = _userData;

  return Scaffold(
    backgroundColor: _profileCream,
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFB75E),
            Color(0xFFFFF4E6),
            _profileCream,
          ],
          stops: [0.0, 0.28, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -45,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 72,
            left: -45,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.30),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.45),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: _profileText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isEditMode ? 'Edit Profile' : 'Profile Information',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _profileText,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _profileOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        onPressed: _isLoading || _isSaving
                            ? null
                            : _isEditMode
                                ? _cancelEditMode
                                : _enterEditMode,
                        icon: Icon(
                          _isEditMode ? Icons.close_rounded : Icons.edit_outlined,
                          size: 17,
                        ),
                        label: Text(
                          _isEditMode ? 'Cancel' : 'Edit',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? _ErrorView(
                              message: _error!,
                              onRetry: _fetchAllData,
                            )
                          : form == null || user == null
                              ? const Center(child: Text('No profile data found'))
                              : _isEditMode
                                  ? _buildEditBody()
                                  : _buildViewBody(form, user),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildViewBody(EyeHealthFormViewData form, UserAccountViewData user) {
  return ListView(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
    children: [
      _HeaderCard(data: form),
      const SizedBox(height: 16),

      _SectionTitle(title: 'Account Information'),
      const SizedBox(height: 10),
      _InfoGrid(items: [
        _InfoItem(
          icon: Icons.person_outline,
          title: 'Full Name',
          value: form.fullName,
        ),
        _InfoItem(
          icon: Icons.email_outlined,
          title: 'Email',
          value: user.email,
        ),
        _InfoItem(
          icon: Icons.phone_outlined,
          title: 'Phone',
          value: user.phone.isEmpty ? '—' : user.phone,
        ),
        _InfoItem(
          icon: Icons.verified_outlined,
          title: 'Profile Status',
          value: form.isActive ? 'Active' : 'Inactive',
        ),
      ]),

      const SizedBox(height: 18),
      _SectionTitle(title: 'Personal Information'),
      const SizedBox(height: 10),
      _InfoGrid(items: [
        _InfoItem(
          icon: Icons.wc_rounded,
          title: 'Gender',
          value: form.gender,
        ),
        _InfoItem(
          icon: Icons.cake_outlined,
          title: 'Date of Birth',
          value: _fmtDate(form.dateOfBirth),
        ),
        _InfoItem(
          icon: Icons.light_mode_outlined,
          title: 'Smart Light',
          value: form.smartLightEnabled ? 'Enabled' : 'Disabled',
        ),
      ]),

      const SizedBox(height: 18),
      _SectionTitle(title: 'Previous Eye Conditions'),
      const SizedBox(height: 10),
      _ChipsWrap(
        chips: form.previousEyeConditions.isEmpty
            ? const ['None']
            : form.previousEyeConditions.map(_humanize).toList(),
      ),

      const SizedBox(height: 18),
      _SectionTitle(title: 'Chronic Diseases'),
      const SizedBox(height: 10),
      _ChipsWrap(
        chips: form.chronicDiseases.isEmpty
            ? const ['None']
            : form.chronicDiseases.map(_humanize).toList(),
      ),

      const SizedBox(height: 18),
      _SectionTitle(title: 'Vision Aids'),
      const SizedBox(height: 10),
      _InfoGrid(items: [
        _InfoItem(
          icon: Icons.remove_red_eye_outlined,
          title: 'Uses Glasses',
          value: form.usesGlasses ? 'Yes' : 'No',
        ),
        _InfoItem(
          icon: Icons.contact_page_outlined,
          title: 'Uses Contact Lenses',
          value: form.usesContactLenses ? 'Yes' : 'No',
        ),
      ]),

      const SizedBox(height: 18),
      _SectionTitle(title: 'Eye Surgery History'),
      const SizedBox(height: 10),
      _BigNoteCard(
        icon: Icons.health_and_safety_outlined,
        title: 'History',
        text: (form.eyeSurgeryHistory == null ||
                form.eyeSurgeryHistory!.trim().isEmpty)
            ? 'No surgeries reported.'
            : form.eyeSurgeryHistory!.trim(),
      ),

      const SizedBox(height: 18),
      _SectionTitle(title: 'Daily Habits & Lifestyle'),
      const SizedBox(height: 10),
      _InfoGrid(items: [
        _InfoItem(
          icon: Icons.monitor_outlined,
          title: 'Screen Time',
          value: '${form.screenTimeHours} h/day',
        ),
        _InfoItem(
          icon: Icons.lightbulb_outline,
          title: 'Lighting',
          value: form.lightingConditions,
        ),
        _InfoItem(
          icon: Icons.bedtime_outlined,
          title: 'Sleep',
          value: '${form.sleepHours} h/night',
        ),
        _InfoItem(
          icon: Icons.restaurant_outlined,
          title: 'Diet',
          value: form.diet ?? '—',
        ),
      ]),

      const SizedBox(height: 18),
      _SectionTitle(title: 'Current Eye Symptoms'),
      const SizedBox(height: 10),
      _ChipsWrap(
        chips: form.currentEyeSymptoms.isEmpty
            ? const ['None']
            : form.currentEyeSymptoms.map(_humanize).toList(),
      ),

      const SizedBox(height: 18),
      _SectionTitle(title: 'Record Metadata'),
      const SizedBox(height: 10),
      _InfoGrid(items: [
        _InfoItem(
          icon: Icons.calendar_month_outlined,
          title: 'Created At',
          value: _fmtDateTime(form.createdAt),
        ),
        _InfoItem(
          icon: Icons.update_outlined,
          title: 'Updated At',
          value: _fmtDateTime(form.updatedAt),
        ),
      ]),
    ],
  );
}

  Widget _buildEditBody() {
    return Form(
      key: _editFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _EditModeBanner(isSaving: _isSaving),
          const SizedBox(height: 16),

          _SectionTitle(title: 'Account Information'),
          const SizedBox(height: 10),

          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
            validator: (v) => _requiredText(v, 'Full name is required'),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _emailController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
              helperText: 'Email cannot be edited here',
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 18),
          _SectionTitle(title: 'Personal Information'),
          const SizedBox(height: 10),

          InkWell(
            onTap: _pickDob,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                border: OutlineInputBorder(),
              ),
              child: Text(_editDob == null ? 'Select date' : _fmtDate(_editDob!)),
            ),
          ),
          const SizedBox(height: 12),

          _DropdownBox(
            label: 'Gender',
            value: _editGender,
            hint: 'Select gender',
            items: const ['Male', 'Female'],
            onChanged: (v) => setState(() => _editGender = v),
          ),

          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Smart Light'),
            subtitle: const Text('Enable or disable smart light recommendations'),
            value: _smartLightEnabled,
            onChanged: (v) => setState(() => _smartLightEnabled = v),
          ),

          const SizedBox(height: 18),
          _SectionTitle(title: 'Previous Eye Conditions'),
          const SizedBox(height: 10),
          _chipRow(
            children: [
              _boolChip('Myopia', _myopia, (v) => setState(() => _myopia = v)),
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
          _SectionTitle(title: 'Chronic Diseases'),
          const SizedBox(height: 10),
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
          _SectionTitle(title: 'Glasses / Contact Lenses'),
          const SizedBox(height: 10),
          _DropdownBox(
            label: 'Do you use glasses or contact lenses?',
            value: _visionAid,
            hint: 'Select one',
            items: const ['Glasses', 'Contact Lenses', 'None'],
            onChanged: (v) => setState(() => _visionAid = v),
          ),

          const SizedBox(height: 18),
          _SectionTitle(title: 'History of Eye Surgeries'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Have you had eye surgery?'),
            value: _hadSurgery,
            onChanged: (v) {
              setState(() {
                _hadSurgery = v;
                if (!v) _surgeryDetailsController.clear();
              });
            },
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
          _SectionTitle(title: 'Daily Habits & Lifestyle'),
          const SizedBox(height: 10),

          _sliderCard(
            title: 'Screen time (hours/day)',
            valueLabel: '${_screenTimeHours.round()} h',
            min: 0,
            max: 16,
            value: _screenTimeHours,
            onChanged: (v) => setState(() => _screenTimeHours = v),
          ),

          const SizedBox(height: 12),
          _DropdownBox(
            label: 'Lighting',
            value: _lighting,
            hint: 'Select lighting',
            items: const ['Bright', 'Normal', 'Dim'],
            onChanged: (v) => setState(() => _lighting = v),
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
          _DropdownBox(
            label: 'Diet',
            value: _diet,
            hint: 'Select diet',
            items: const ['Healthy', 'Average', 'Unhealthy'],
            onChanged: (v) => setState(() => _diet = v),
          ),

          const SizedBox(height: 18),
          _SectionTitle(title: 'Current Eye Symptoms'),
          const SizedBox(height: 10),
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

          const SizedBox(height: 22),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
            ),
          ),
        ],
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
      onSelected: _isSaving ? null : onChanged,
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
            onChanged: _isSaving ? null : onChanged,
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _humanize(String s) {
    // e.g. "eye strain" / "eye_strain" / "myopia"
    final cleaned = s.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return s;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}

/// ===== Simple view-model (UI layer) =====
class UserAccountViewData {
  final String email;
  final String phone;
  final String firebaseUid;
  final String mainFormId;

  UserAccountViewData({
    required this.email,
    required this.phone,
    required this.firebaseUid,
    required this.mainFormId,
  });

  factory UserAccountViewData.fromJson(Map<String, dynamic> json) {
    return UserAccountViewData(
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      firebaseUid: (json['firebase_uid'] ?? '').toString(),
      mainFormId: (json['main_form_id'] ?? '').toString(),
    );
  }
}

  class EyeHealthFormViewData {
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

  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  EyeHealthFormViewData({
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
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EyeHealthFormViewData.fromJson(Map<String, dynamic> json) {
    return EyeHealthFormViewData(
      fullName: (json['full_name'] ?? '').toString(),
      dateOfBirth: _parseDate(json['date_of_birth']),
      gender: (json['gender'] ?? '').toString(),
      previousEyeConditions: _parseStringList(json['previous_eye_conditions']),
      chronicDiseases: _parseStringList(json['chronic_diseases']),
      usesGlasses: json['uses_glasses'] == true,
      usesContactLenses: json['uses_contact_lenses'] == true,
      eyeSurgeryHistory: json['eye_surgery_history']?.toString(),
      screenTimeHours: _parseInt(json['screen_time_hours']),
      lightingConditions: (json['lighting_conditions'] ?? '').toString(),
      sleepHours: _parseInt(json['sleep_hours']),
      diet: json['diet']?.toString(),
      currentEyeSymptoms: _parseStringList(json['current_eye_symptoms']),
      smartLightEnabled: json['smart_light_enabled'] == true,
      isActive: json['is_active'] == true,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString())?.toLocal() ?? DateTime.now();
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 46),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditModeBanner extends StatelessWidget {
  final bool isSaving;

  const _EditModeBanner({required this.isSaving});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.20),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Mode Active',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  isSaving
                      ? 'Saving your changes...'
                      : 'Update the fields below, then press Save Changes.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.62),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownBox extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownBox({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          hint: Text(hint),
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// ===== UI Widgets =====
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: _profileText,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: _profileOrange,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoItem> items;

  const _InfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 88,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, i) => _InfoTile(item: items[i]),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String title;
  final String value;

  _InfoItem({
    required this.icon,
    required this.title,
    required this.value,
  });
}

class _InfoTile extends StatelessWidget {
  final _InfoItem item;

  const _InfoTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _profileCard,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.85)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB88956).withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: _profileOrange,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: _profileMuted,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: _profileText,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;

  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? _profileMint.withOpacity(0.18) : Colors.black.withOpacity(0.06);
    final fg = isActive ? _profileMint : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final EyeHealthFormViewData data;
  const _HeaderCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFFFE4BB),
            Color(0xFFEAF3DD),
            Color(0xFFCFF3EE),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.65), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB88956).withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -20,
            child: Icon(
              Icons.remove_red_eye_outlined,
              size: 78,
              color: Colors.white.withOpacity(0.22),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: _profileMintLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _profileMint.withOpacity(0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      data.fullName.isNotEmpty
                          ? data.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: _profileMint,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: _profileText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Eye-Health Form Summary',
                        style: TextStyle(
                          color: _profileMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(isActive: data.isActive),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipsWrap extends StatelessWidget {
  final List<String> chips;

  const _ChipsWrap({required this.chips});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: chips
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: t.toLowerCase() == 'none'
                    ? _profileCard
                    : _profileMintLight.withOpacity(0.80),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: t.toLowerCase() == 'none'
                      ? _profileBorder
                      : _profileMint.withOpacity(0.22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB88956).withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    t.toLowerCase() == 'none'
                        ? Icons.remove_rounded
                        : Icons.remove_red_eye_outlined,
                    size: 14,
                    color: t.toLowerCase() == 'none'
                        ? _profileMuted
                        : _profileMint,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: t.toLowerCase() == 'none'
                          ? _profileMuted
                          : _profileText,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BigNoteCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _BigNoteCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _profileCard,
            Color(0xFFE5FAF7),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB88956).withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            bottom: -8,
            child: Icon(
              Icons.remove_red_eye_outlined,
              size: 58,
              color: _profileMint.withOpacity(0.16),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _profileMintLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _profileMint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _profileText,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      text,
                      style: const TextStyle(
                        color: _profileMuted,
                        height: 1.35,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}