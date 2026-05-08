// settings_page.dart
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'theme_provider.dart';

import 'smart_bottom_nav.dart';
import 'main.dart';
import 'progress_page.dart';
import 'notifications_page.dart';
import 'tips_page.dart';

import 'success_popup.dart';

const String backendBaseUrl = 'http://10.0.2.2:8080';

const Color _settingsBgTop = Color(0xFF98DED7);
const Color _settingsBgMid = Color(0xFFF8F5EF);
const Color _settingsBgBottom = Color(0xFFF2D7AE);

const Color _settingsCard = Color(0xFFFFFCF8);
const Color _settingsSoftWhite = Color(0xFFFDFDFD);
const Color _settingsBorder = Color(0xFFECE3D6);

const Color _settingsText = Color(0xFF3E2E25);
const Color _settingsMuted = Color(0xFF8F7D70);

const Color _settingsOrange = Color(0xFFFFA62B);
const Color _settingsOrangeSoft = Color(0xFFFFF0DC);

const Color _settingsMint = Color(0xFF2EC4B6);
const Color _settingsMintSoft = Color(0xFFE4F8F5);

const Color _settingsBlue = Color(0xFF5C95FF);
const Color _settingsBlueSoft = Color(0xFFEAF1FF);

class _DeviceItem {
  final String id;
  final String name;

  const _DeviceItem({required this.id, required this.name});
}

class SettingsPage extends StatefulWidget {
  final bool smartLightEnabled;
  final double smartLightIntensity;
  final Color smartLightColor;
  final String? activeFormId;
  final ValueNotifier<Map<String, String?>> glassesLink;
  final VoidCallback onRequestLink;
  final String mainAccountId;
  final String firebaseUid;
  final ValueChanged<bool>? onSmartLightToggle;

  const SettingsPage({
    super.key,
    required this.smartLightEnabled,
    required this.smartLightIntensity,
    required this.smartLightColor,
    this.onSmartLightToggle,
    required this.glassesLink,
    required this.onRequestLink,
    required this.activeFormId,
    required this.mainAccountId,
    required this.firebaseUid,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Widget _buildDarkModeSection() {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = context.watch<ThemeProvider>().isDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _softCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2C2C3E)
                  : const Color(0xFFEEEEFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isDark
                  ? const Color(0xFF9B8FFF)
                  : const Color(0xFFFF9F1C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dark Mode',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark ? 'Dark theme is on' : 'Light theme is on',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isDark,
            activeThumbColor: const Color(0xFF9B8FFF),
            onChanged: (_) => themeProvider.toggle(),
          ),
        ],
      ),
    );
  }

  late bool _smartLightEnabled;
  bool _isLoadingDevices = false;
  bool _powerOn = false;
  bool _isPowerLoading = false;

  String? get _safeFormId {
    final formId = widget.activeFormId;
    if (formId == null || formId.isEmpty) return null;
    return formId;
  }

  void _showNoActiveProfileMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No active profile found')),
    );
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(
          mainAccountId: widget.mainAccountId,
          firebaseUid: widget.firebaseUid,
        ),
      ),
    );
  }

  void _goSettings() {
    // Already on Settings page
  }

  void _goProgress() {
    final formId = _safeFormId;
    if (formId == null) {
      _showNoActiveProfileMessage();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProgressPage(
          userId: widget.mainAccountId,
          firebaseUid: widget.firebaseUid,
          formId: formId,
          onBackRequested: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsPage(
                  mainAccountId: widget.mainAccountId,
                  firebaseUid: widget.firebaseUid,
                  smartLightEnabled: _smartLightEnabled,
                  smartLightIntensity: widget.smartLightIntensity,
                  smartLightColor: widget.smartLightColor,
                  onSmartLightToggle: widget.onSmartLightToggle,
                  glassesLink: widget.glassesLink,
                  onRequestLink: widget.onRequestLink,
                  activeFormId: widget.activeFormId,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _goAlerts() {
    final formId = _safeFormId;
    if (formId == null) {
      _showNoActiveProfileMessage();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsPage(
          userId: widget.mainAccountId,
          firebaseUid: widget.firebaseUid,
          formId: formId,
        ),
      ),
    );
  }

  void _goTips() {
    final formId = _safeFormId;
    if (formId == null) {
      _showNoActiveProfileMessage();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TipsPage(
          mainAccountId: widget.mainAccountId,
          firebaseUid: widget.firebaseUid,
          formId: formId,
        ),
      ),
    );
  }

  List<_DeviceItem> _devices = [
    const _DeviceItem(id: 'SMART_GLASSES_001', name: 'My Smart Glasses'),
  ];

  String? _selectedDeviceId = 'SMART_GLASSES_001';
  final TextEditingController _deviceNameController = TextEditingController();

  _DeviceItem? get _selectedDevice {
    try {
      return _devices.firstWhere((d) => d.id == _selectedDeviceId);
    } catch (_) {
      return null;
    }
  }

  BoxDecoration _softCardDecoration({
    Color color = _settingsCard,
    Gradient? gradient,
  }) {
    return BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFBE9360).withValues(alpha: 0.12),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _smartLightEnabled = widget.smartLightEnabled;
    _loadSmartLightState();
    _loadDevicesFromBackend();
    _loadLinkedDeviceFromBackend();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }

  void _showAddDeviceDialog() {
    _deviceNameController.clear();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _settingsCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Add New Device',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _settingsText,
            ),
          ),
          content: TextField(
            controller: _deviceNameController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter a unique device name',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _settingsOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                final enteredName = _deviceNameController.text.trim();

                if (enteredName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a device name')),
                  );
                  return;
                }

                final alreadyExists = _devices.any(
                  (d) => d.name.toLowerCase() == enteredName.toLowerCase(),
                );

                if (alreadyExists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Device name must be unique')),
                  );
                  return;
                }

                try {
                  await _addDeviceToBackend(enteredName);

                  if (!mounted) return;
                  Navigator.pop(ctx);

                  await showSuccessPopup(context, 'Device added successfully');
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Add Device'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  Future<void> _loadSmartLightState() async {
    final formId = widget.activeFormId;
    if (formId == null || formId.isEmpty) return;

    try {
      final uri =
          Uri.parse(
            '$backendBaseUrl/api/eye-health-form/smart-light-state',
          ).replace(
            queryParameters: {
              'form_id': formId,
              'main_account_id': widget.mainAccountId,
            },
          );

      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw 'Failed to fetch smart light state (code: ${res.statusCode}): ${res.body}';
      }

      final body = jsonDecode(res.body);
      final bool enabled = (body['data']?['enabled'] == true);

      if (!mounted) return;
      setState(() => _smartLightEnabled = enabled);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading smart light state: $e')),
      );
    }
  }

  Future<void> _loadDevicesFromBackend() async {
    final formId = widget.activeFormId;
    if (formId == null || formId.isEmpty) return;

    setState(() => _isLoadingDevices = true);

    try {
      final uri = Uri.parse('$backendBaseUrl/api/devices/by-user-form').replace(
        queryParameters: {'user_id': widget.mainAccountId, 'form_id': formId},
      );

      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw 'Failed to load devices (code: ${res.statusCode})';
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (body['data'] as List?) ?? [];

      final loadedDevices = data
          .map((item) {
            final map = item as Map<String, dynamic>;
            return _DeviceItem(
              id: (map['deviceId'] ?? '').toString(),
              name: ((map['device_name'] ?? '').toString().isNotEmpty)
                  ? (map['device_name'] ?? '').toString()
                  : (map['deviceId'] ?? '').toString(),
            );
          })
          .where((d) => d.id.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _devices = loadedDevices;

        if (_devices.isNotEmpty) {
          final selectedStillExists = _devices.any(
            (d) => d.id == _selectedDeviceId,
          );
          _selectedDeviceId = selectedStillExists
              ? _selectedDeviceId
              : _devices.first.id;
        } else {
          _selectedDeviceId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading devices: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingDevices = false);
    }
  }

  Future<void> _addDeviceToBackend(String deviceName) async {
    final formId = widget.activeFormId;
    if (formId == null || formId.isEmpty) return;

    final deviceId = 'DEV_${DateTime.now().millisecondsSinceEpoch}';

    final uri = Uri.parse('$backendBaseUrl/api/devices/add');

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'deviceId': deviceId,
        'device_name': deviceName,
        'user_id': widget.mainAccountId,
        'form_id': formId,
        'is_linked': false,
        'power': false,
        'errorLock': false,
      }),
    );

    if (res.statusCode != 200) {
      throw 'Failed to add device (code: ${res.statusCode}): ${res.body}';
    }

    await _loadDevicesFromBackend();

    if (!mounted) return;
    setState(() {
      _selectedDeviceId = deviceId;
    });
  }

  Future<void> _loadLinkedDeviceFromBackend() async {
    final formId = widget.activeFormId;
    if (formId == null || formId.isEmpty) return;

    try {
      final uri = Uri.parse('$backendBaseUrl/api/devices/linked').replace(
        queryParameters: {'user_id': widget.mainAccountId, 'form_id': formId},
      );

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final device = body['device'] as Map<String, dynamic>;

        final deviceId = (device['deviceId'] ?? '').toString();

        widget.glassesLink.value = {
          'deviceId': deviceId.isEmpty ? null : deviceId,
          'user_id': widget.mainAccountId,
          'form_id': formId,
          'name': null,
        };
        await _loadLinkedDevicePower();
        return;
      }

      if (res.statusCode == 404) {
        widget.glassesLink.value = {
          'deviceId': null,
          'user_id': null,
          'form_id': null,
          'name': null,
        };
        if (!mounted) return;
        setState(() {
          _powerOn = false;
        });
        return;
      }

      throw 'Failed to load linked device (code: ${res.statusCode})';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading linked device: $e')),
      );
    }
  }

  Future<void> _loadLinkedDevicePower() async {
    final linkedDeviceId = widget.glassesLink.value['deviceId'];

    if (linkedDeviceId == null || linkedDeviceId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _powerOn = false;
      });
      return;
    }

    try {
      final uri = Uri.parse(
        '$backendBaseUrl/api/devices/power/$linkedDeviceId',
      );
      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw 'Failed to load device power (code: ${res.statusCode})';
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _powerOn = body['power'] == true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading device power: $e')));
    }
  }

  Future<void> _toggleLinkedDevicePower(bool value) async {
    final formId = widget.activeFormId;
    final linkedDeviceId = widget.glassesLink.value['deviceId'];

    if (formId == null ||
        formId.isEmpty ||
        linkedDeviceId == null ||
        linkedDeviceId.isEmpty) {
      return;
    }

    setState(() => _isPowerLoading = true);

    try {
      final uri = Uri.parse('$backendBaseUrl/api/devices/power');

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': linkedDeviceId,
          'user_id': widget.mainAccountId,
          'form_id': formId,
          'power': value,
        }),
      );

      if (res.statusCode != 200) {
        throw 'Failed to update power (code: ${res.statusCode}): ${res.body}';
      }

      if (!mounted) return;
      setState(() {
        _powerOn = value;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating device power: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isPowerLoading = false);
    }
  }

  Future<void> _linkSelectedDevice() async {
    final formId = widget.activeFormId;
    final selected = _selectedDevice;

    if (formId == null || formId.isEmpty || selected == null) return;

    final uri = Uri.parse('$backendBaseUrl/api/devices/link').replace(
      queryParameters: {
        'deviceId': selected.id,
        'user_id': widget.mainAccountId,
        'form_id': formId,
      },
    );

    final res = await http.post(uri);

    if (res.statusCode != 200) {
      throw 'Failed to link device (code: ${res.statusCode}): ${res.body}';
    }

    await _loadDevicesFromBackend();
    await _loadLinkedDeviceFromBackend();
    await _loadLinkedDevicePower();
  }

  Future<void> _unlinkGlasses() async {
    final formId = widget.activeFormId;
    final linkedDeviceId = widget.glassesLink.value['deviceId'];

    if (formId == null ||
        formId.isEmpty ||
        linkedDeviceId == null ||
        linkedDeviceId.isEmpty) {
      return;
    }

    final uri = Uri.parse('$backendBaseUrl/api/devices/unlink').replace(
      queryParameters: {
        'deviceId': linkedDeviceId,
        'user_id': widget.mainAccountId,
        'form_id': formId,
      },
    );

    final res = await http.post(uri);

    if (res.statusCode != 200) {
      throw 'Failed to unlink device (code: ${res.statusCode}): ${res.body}';
    }

    await _loadDevicesFromBackend();
    await _loadLinkedDeviceFromBackend();
    if (!mounted) return;
    setState(() {
      _powerOn = false;
    });

    if (!mounted) return;
    await showSuccessPopup(context, 'Device unlinked successfully');
  }

  Future<void> _deleteDevice(String deviceId) async {
    final formId = widget.activeFormId;
    if (formId == null || formId.isEmpty) return;

    final uri = Uri.parse('$backendBaseUrl/api/devices/delete').replace(
      queryParameters: {
        'deviceId': deviceId,
        'user_id': widget.mainAccountId,
        'form_id': formId,
      },
    );

    final res = await http.delete(uri);

    if (res.statusCode != 200) {
      throw 'Failed to delete device (code: ${res.statusCode}): ${res.body}';
    }

    final wasLinked = widget.glassesLink.value['deviceId'] == deviceId;

    await _loadDevicesFromBackend();

    if (wasLinked) {
      widget.glassesLink.value = {
        'deviceId': null,
        'user_id': null,
        'form_id': null,
        'name': null,
      };

      if (!mounted) return;
      setState(() {
        _powerOn = false;
      });
    } else {
      await _loadLinkedDeviceFromBackend();
    }

    if (!mounted) return;
    await showSuccessPopup(context, 'Device deleted successfully');
  }

  Widget _buildGlassesLinkSection() {
    return ValueListenableBuilder<Map<String, String?>>(
      valueListenable: widget.glassesLink,
      builder: (context, link, _) {
        final linkedFormId = link['form_id'];
        final linkedUserId = link['user_id'];
        final linkedDeviceId = link['deviceId'];

        String? linkedDeviceName;
        try {
          linkedDeviceName = _devices.firstWhere((d) => d.id == linkedDeviceId).name;
        } catch (_) {
          linkedDeviceName = null;
        }

        final isDeviceLinked =
            (linkedUserId != null && linkedUserId.isNotEmpty) &&
            (linkedFormId != null && linkedFormId.isNotEmpty);

        final subtitleText = isDeviceLinked
            ? 'Currently linked device: ${linkedDeviceName ?? 'Unknown device'}'
            : 'No device currently linked';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _softCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _settingsBlueSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.remove_red_eye_outlined,
                      color: _settingsBlue,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Devices',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _settingsText,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add, name, and choose the device you want to link.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _settingsMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      color: _settingsBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        subtitleText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _settingsText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.power_settings_new_rounded,
                      color: _settingsOrange,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Device Power',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: _settingsText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isDeviceLinked
                                ? 'Control ${linkedDeviceName ?? 'linked device'}'
                                : 'No linked device to control',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _settingsMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _powerOn,
                      activeColor: _settingsOrange,
                      onChanged: (!isDeviceLinked || _isPowerLoading)
                          ? null
                          : (value) async {
                              await _toggleLinkedDevicePower(value);
                            },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Choose Device',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _settingsText,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _settingsBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDeviceId,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(18),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _settingsMuted,
                    ),
                    selectedItemBuilder: (context) {
                      return _devices.map((device) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            device.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _settingsText,
                            ),
                          ),
                        );
                      }).toList();
                    },
                    items: _devices.map((device) {
                      return DropdownMenuItem<String>(
                        value: device.id,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                device.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _settingsText,
                                ),
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: _settingsCard,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    title: const Text('Delete Device'),
                                    content: Text(
                                      'Are you sure you want to delete ${device.name}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (ok == true) {
                                  Navigator.pop(context);
                                  try {
                                    await _deleteDevice(device.id);
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _isLoadingDevices
                        ? null
                        : (value) {
                            setState(() {
                              _selectedDeviceId = value;
                            });
                          },
                  ),
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingDevices ? null : _showAddDeviceDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Add New Device',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _settingsMint,
                    side: const BorderSide(color: Color(0xFFBEEDE8)),
                    backgroundColor: _settingsMintSoft.withValues(alpha: 0.50),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedDevice == null || _isLoadingDevices
                          ? null
                          : () async {
                              try {
                                await _linkSelectedDevice();

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${_selectedDevice!.name} linked successfully',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _settingsOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Link Selected Device',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isDeviceLinked
                          ? () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: _settingsCard,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  title: const Text('Unlink Device'),
                                  content: Text(
                                    'Are you sure you want to unlink ${linkedDeviceName ?? 'this device'}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Unlink',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (ok == true) {
                                try {
                                  await _unlinkGlasses();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(
                          color: isDeviceLinked
                              ? Colors.red.withValues(alpha: 0.25)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.55),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        isDeviceLinked
                            ? 'Unlink: ${linkedDeviceName ?? 'Device'}'
                            : 'Unlink',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _settingsCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Confirm Logout',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _settingsText,
            ),
          ),
          content: const Text(
            'Are you sure you want to log out?',
            style: TextStyle(color: _settingsMuted),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: _settingsMuted),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _logout();
              },
              child: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.75),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBE9360).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _showLogoutDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SmartProgressFab(
        selectedIndex: 1,
        onTap: _goProgress,
      ),

      bottomNavigationBar: SmartBottomNav(
        selectedIndex: 1,
        onHomeTap: _goHome,
        onSettingsTap: _goSettings,
        onProgressTap: _goProgress,
        onAlertsTap: _goAlerts,
        onTipsTap: _goTips,
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0D1B2A),
                    const Color(0xFF1B2A3B),
                    const Color(0xFF0D1B2A),
                  ]
                : [
                    _settingsBgTop,
                    _settingsBgMid,
                    _settingsBgBottom,
                  ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              left: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              right: -40,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE6B8).withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 18, 26, 0),
                child: Column(
                  children: [
                    SizedBox(
                      height: 54,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.28),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 21,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              'Settings',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom + 135,
                        ),
                        child: Column(
                          children: [
                            _buildGlassesLinkSection(),
                            const SizedBox(height: 16),
                            _buildDarkModeSection(),
                            const SizedBox(height: 16),
                            _buildSmartLightSection(),
                            const SizedBox(height: 16),
                            _buildLogoutButton(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartLightSection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _softCardDecoration(),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _settingsMintSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: _settingsMint,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart-Light',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: _settingsText,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Enable or disable ambient smart lighting.',
                      style: TextStyle(fontSize: 12.5, color: _settingsMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _smartLightEnabled,
                activeColor: _settingsMint,
                onChanged: (v) async {
                  setState(() => _smartLightEnabled = v);

                  widget.onSmartLightToggle?.call(v);
                  if (widget.activeFormId != null) {
                    try {
                      final response = await http.post(
                        Uri.parse(
                          '$backendBaseUrl/api/eye-health-form/toggle-smart-light'
                          '?form_id=${widget.activeFormId}&enabled=$v',
                        ),
                      );

                      if (response.statusCode != 200) {
                        throw Exception('Failed to update smart light');
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating smart light: $e'),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),

        if (_smartLightEnabled) ...[
          const SizedBox(height: 12),
          _buildSmartLightReadOnlyControlsCard(),
        ],
      ],
    );
  }

  Widget _buildSmartLightReadOnlyControlsCard() {
    final intensityPercent = (widget.smartLightIntensity * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _softCardDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.smartLightColor.withValues(alpha: 0.18),
            _settingsSoftWhite,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.smartLightColor.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.wb_sunny_rounded,
                  color: widget.smartLightIntensity < 0.35
                      ? Colors.black87
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Light Controls',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _settingsText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Intensity: $intensityPercent%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _settingsMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.smartLightColor.value
                      .toRadixString(16)
                      .toUpperCase()
                      .padLeft(8, '0'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: _settingsMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'Brightness',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _settingsText,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: widget.smartLightIntensity.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(widget.smartLightColor),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Color',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _settingsText,
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _buildReadOnlyPalette(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReadOnlyPalette() {
    const palette = <Color>[
      Color(0xFFFF9F1C),
      Color(0xFF2EC4B6),
      Color(0xFF4D96FF),
      Color(0xFFB5179E),
      Color(0xFFFF4D6D),
      Color(0xFFFFD166),
      Color(0xFF06D6A0),
      Color(0xFF111827),
    ];

    return palette.map((c) {
      final selected = c.value == widget.smartLightColor.value;

      return Container(
        width: selected ? 40 : 34,
        height: selected ? 40 : 34,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: selected ? 10 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      );
    }).toList();
  }
}
