// settings_page.dart
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatefulWidget {
  final bool smartLightEnabled;
  final double smartLightIntensity; // 0..1
  final Color smartLightColor;

  final ValueNotifier<Map<String, String?>> glassesLink;
  final VoidCallback onRequestLink;

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
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _smartLightEnabled;

  @override
  void initState() {
    super.initState();
    _smartLightEnabled = widget.smartLightEnabled;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logout failed: $e')),
    );
  }
}

Widget _buildGlassesLinkSection() {
  return ValueListenableBuilder<Map<String, String?>>(
    valueListenable: widget.glassesLink,
    builder: (context, link, _) {
      final linkedId = link['id'];
      final linkedName = link['name'];
      final isLinked = linkedId != null;

      return Container(
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
                color: const Color(0xFFE7F0FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.link, color: Color(0xFF4D96FF)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Glasses Link',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLinked
                        ? 'Linked to: ${linkedName ?? '-'}'
                        : 'Not linked to any account.',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),

            // if linked: Unlink
            if (isLinked)
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text('Unlink Glasses'),
                      content: const Text(
                        'Are you sure you want to unlink the glasses from this account?',
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
                    widget.glassesLink.value = {'id': null, 'name': null};
                  }
                },
                child: const Text(
                  'Unlink',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                ),
              )
            else
              // if not linked: Link
              TextButton(
                onPressed: widget.onRequestLink,
                child: const Text(
                  'Link',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
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
        content: const Text(
          'Are you sure you want to log out?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
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
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
                onChanged: (v) {
                  setState(() => _smartLightEnabled = v);

                  // رجّع القيمة للهوم (عشان تنربط بعدين بالباك)
                  widget.onSmartLightToggle?.call(v);
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
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Intensity: $intensityPercent%',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
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