// settings_page.dart
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String backendBaseUrl = 'http://10.0.2.2:8080';

class _DeviceItem {
  final String id;
  final String name;

  const _DeviceItem({required this.id, required this.name});
}

class SettingsPage extends StatefulWidget {
  final bool smartLightEnabled;
  final double smartLightIntensity; // 0..1
  final Color smartLightColor;
  final String? activeFormId;
  final ValueNotifier<Map<String, String?>> glassesLink;
  final VoidCallback onRequestLink;
  final String mainAccountId;

  /// يرجّع قيمة السويتش للهوم (عشان  الربط بعدين بالباك/الـESP)
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
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _smartLightEnabled;
  bool _isLoadingDevices = false;
  bool _powerOn = false;
  bool _isPowerLoading = false;

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Add New Device',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: _deviceNameController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter a unique device name',
              filled: true,
              fillColor: const Color(0xFFFFF7EE),
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
                backgroundColor: const Color(0xFFFF9F1C),
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

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Device added successfully')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
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

      //go back to login page and delete the stack
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device unlinked successfully')),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device deleted successfully')),
    );
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
          linkedDeviceName = _devices
              .firstWhere((d) => d.id == linkedDeviceId)
              .name;
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F0FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.visibility_outlined,
                      color: Color(0xFF4D96FF),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add, name, and choose the device you want to link.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            height: 1.3,
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
                  color: const Color(0xFFFFF7EE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      color: Color(0xFF4D96FF),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        subtitleText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7EE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.power_settings_new_rounded,
                      color: Color(0xFFFF9F1C),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDeviceLinked
                                ? 'Control ${linkedDeviceName ?? 'linked device'}'
                                : 'No linked device to control',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _powerOn,
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7EE),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDeviceId,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(18),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    selectedItemBuilder: (context) {
                      return _devices.map((device) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            device.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: const Text('Delete Device'),
                                    content: Text(
                                      'Are you sure you want to delete ${device.name}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
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
                                  Navigator.pop(context); // يقفل dropdown
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
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2EC4B6),
                    side: const BorderSide(color: Color(0xFFCBF3F0)),
                    backgroundColor: const Color(0xFFF7FFFE),
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                        backgroundColor: const Color(0xFFFF9F1C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Link Selected Device',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: const Text('Unlink Device'),
                                  content: Text(
                                    'Are you sure you want to unlink ${linkedDeviceName ?? 'this device'}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
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
                              ? Colors.red.withOpacity(0.25)
                              : Colors.grey.withOpacity(0.2),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        isDeviceLinked
                            ? 'Unlink: ${linkedDeviceName ?? 'Device'}'
                            : 'Unlink',
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Confirm Logout',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await _logout();
              },
              child: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7EE),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildGlassesLinkSection(),
                      const SizedBox(height: 16),
                      _buildSmartLightSection(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ===== Log out bottom center =====
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _showLogoutDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= Smart-Light Section =================

  Widget _buildSmartLightSection() {
    return Column(
      children: [
        // Header card with switch
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBF3F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF2EC4B6),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Enable or disable ambient smart lighting.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _smartLightEnabled,
                onChanged: (v) async {
                  setState(() => _smartLightEnabled = v);

                  // رجّع القيمة للهوم (عشان تنربط بعدين بالباك)
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.smartLightColor.withOpacity(0.20),
            const Color(0xFFFFFFFF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // preview row
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: widget.smartLightColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Intensity: $intensityPercent%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                widget.smartLightColor.value
                    .toRadixString(16)
                    .toUpperCase()
                    .padLeft(8, '0'),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Intensity display (read-only)
          const Text(
            'Brightness',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: widget.smartLightIntensity.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.black.withOpacity(0.06),
            ),
          ),

          const SizedBox(height: 16),

          // Color display (read-only palette)
          const Text(
            'Color',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),

          Wrap(spacing: 10, runSpacing: 10, children: _buildReadOnlyPalette()),
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
            color: selected ? Colors.black87 : Colors.black.withOpacity(0.10),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
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
