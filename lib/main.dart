import 'package:flutter/material.dart';
import 'notifications_page.dart';
import 'smart_bottom_nav.dart';

void main() {
  runApp(const SmartGlassesApp());
}

class SmartGlassesApp extends StatelessWidget {
  const SmartGlassesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Glasses',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFFF7EE), 
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF9F1C), 
          primary: const Color(0xFFFF9F1C),
          secondary: const Color(0xFF2EC4B6), 
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 2; // الافتراضي: progress في النص

  // قيم تجريبية فقط (لما تجي الداتا من الحساس نغرها)
  final double _demoDistanceCm = 55; // مسافة تقريبية
  final double _demoBrightness = 0.65; // من 0 إلى 1
  final double _demoDryness = 0.35; // من 0 إلى 1

  // للحالة حق قائمة الأكشنات العلوية
  bool _showQuickActions = false;
  bool _wifiOn = true;
  bool _isDarkMode = false; // حالياً بس بنبدّل الأيقونة (بدون ثيم كامل)

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Color _iconColor(int index) {
    return _selectedIndex == index
        ? const Color(0xFF2EC4B6) // لون مميز للآيتم المختار
        : Colors.black45;
  }

  TextStyle _labelStyle(int index) {
    return TextStyle(
      fontSize: 11,
      fontWeight: _selectedIndex == index ? FontWeight.w600 : FontWeight.w400,
      color: _iconColor(index),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning!';
    } else {
      return 'Good evening!';
    }
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsPage(),
      ),
    );
  }

  void _toggleQuickActions() {
    setState(() {
      _showQuickActions = !_showQuickActions;
    });
  }

  void _toggleWifi() {
    setState(() {
      _wifiOn = !_wifiOn;
    });
  }

  void _toggleMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    // لاحقاً نقدر نربطها مع ThemeMode في الـ MaterialApp
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ================== الجسم (الهيدر + المحتوى) داخل Stack عشان الأوفرلاي ==================
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ====== الهيدر ======
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFFCBF3F0), // #cbf3f0
                        child: Icon(
                          Icons.person,
                          size: 28,
                          color: Color(0xFF2EC4B6), // #2ec4b6
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // السطر الصغير: Good morning / Good evening
                          Text(
                            _greeting(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // السطر الأكبر: الاسم
                          const Text(
                            'Sarah Ahmed',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // جرس التنبيهات
                      IconButton(
                        onPressed: _openNotifications,
                        icon: const Icon(Icons.notifications_none_rounded),
                        color: const Color(0xFF2EC4B6),
                        iconSize: 26,
                      ),
                      // زر الزائد لفتح الكويك أكشنز
                      IconButton(
                        onPressed: _toggleQuickActions,
                        icon: const Icon(Icons.add_circle_outline),
                        color: const Color(0xFF2EC4B6),
                        iconSize: 28,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ====== عنوان بسيط للهوم ======
                  const Text(
                    'Today\'s Eye Health Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Visual preview of your current setup (distance, brightness & eye dryness).',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ====== باقي المحتوى في Scroll ======
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildDistanceCard(),
                          const SizedBox(height: 16),
                          _buildBrightnessCard(),
                          const SizedBox(height: 16),
                          _buildDrynessCard(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ====== الأوفرلاي حق الثلاث دوائر (Edit / Wi-Fi / Mode) ======
          if (_showQuickActions) _buildQuickActionsOverlay(),
        ],
      ),

      // ================== الأيقونة الدائرية (Progress) ==================
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        elevation: 4,
        backgroundColor: const Color(0xFFFFBF69), // #ffbf69
        onPressed: () => _onItemTapped(2),
        child: Icon(
          Icons.show_chart,
          color: _iconColor(2),
        ),
      ),

      // ================== الـ Bottom Bar (مشترك) ==================
      bottomNavigationBar: SmartBottomNav(
        selectedIndex: _selectedIndex,
        onItemTap: (index) {
          if (index == 3) {
            // Alerts → افتح صفحة الإشعارات
            _openNotifications();
          } else {
            _onItemTapped(index);
          }
        },
      ),
    );
  }

  // ================== الأوفرلاي ==================
  Widget _buildQuickActionsOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          // خلفية معتمة
          GestureDetector(
            onTap: _toggleQuickActions,
            child: Container(
              color: Colors.black.withOpacity(0.25),
            ),
          ),
          // زر الإغلاق
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'close_actions',
              mini: true,
              shape: const CircleBorder(),
              backgroundColor: Colors.white,
              onPressed: _toggleQuickActions,
              child: const Icon(
                Icons.close,
                color: Colors.black87,
              ),
            ),
          ),
          // الدوائر الثلاثة 
          Positioned(
            top: 80,
            right: 40,
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Edit – مائلة شوي لليسار
                  Transform.translate(
                    offset: const Offset(-8, 0),
                    child: _QuickActionBubble(
                      icon: Icons.edit,
                      label: 'Edit',
                      onTap: () {
                        // حاليًا مافي فنكشن حقيقي
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Wi-Fi – في النص تقريبًا
                  _QuickActionBubble(
                    icon: _wifiOn ? Icons.wifi : Icons.wifi_off,
                    label: 'Wi-Fi',
                    onTap: _toggleWifi,
                  ),
                  const SizedBox(height: 12),
                  // Mode – مائلة شوي لليمين
                  Transform.translate(
                    offset: const Offset(8, 0),
                    child: _QuickActionBubble(
                      icon: _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      label: 'Mode',
                      onTap: _toggleMode,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================== Widgets للكروت الثلاثة ==================

  // 1) كرت المسافة
  Widget _buildDistanceCard() {
    return _SensorCard(
      title: 'Distance to Screen',
      subtitle: 'Preview of how far you are from the screen.',
      child: SizedBox(
        height: 120,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // الشخص
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.person_outline, size: 40, color: Colors.black54),
                SizedBox(height: 4),
                Text(
                  'You',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            // الخط المتقطع + القيمة
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final dashWidth = 6.0;
                      final dashSpace = 4.0;
                      final dashCount =
                          (constraints.maxWidth / (dashWidth + dashSpace))
                              .floor();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(dashCount, (index) {
                          return Container(
                            width: dashWidth,
                            height: 2,
                            margin: EdgeInsets.only(
                                right: index == dashCount - 1 ? 0 : dashSpace),
                            color: const Color(0xFF2EC4B6),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_demoDistanceCm.toStringAsFixed(0)} cm',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '(sample value – will be live later)',
                    style: TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
            ),
            // الجهاز
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.desktop_windows_outlined,
                    size: 36, color: Colors.black54),
                SizedBox(height: 4),
                Text(
                  'Screen',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2) كرت السطوع
  Widget _buildBrightnessCard() {
    return _SensorCard(
      title: 'Screen Brightness',
      subtitle: 'Preview of current brightness level.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.wb_sunny_rounded,
            size: 48,
            color: Color(0xFFFF9F1C),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 26,
            child: Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7EE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _demoBrightness.clamp(0.0, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2EC4B6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment(
                    (_demoBrightness.clamp(0.0, 1.0) * 2) - 1,
                    0,
                  ),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFF2EC4B6),
                        width: 2,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Level: ${(_demoBrightness * 100).round()}%',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '(will be controlled by real sensor input)',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  // 3) كرت جفاف العين
  Widget _buildDrynessCard() {
    final drynessPercent = (_demoDryness * 100).round();
    String drynessLabel;
    if (_demoDryness < 0.33) {
      drynessLabel = 'Low dryness (comfortable)';
    } else if (_demoDryness < 0.66) {
      drynessLabel = 'Moderate dryness';
    } else {
      drynessLabel = 'High dryness (take a break)';
    }

    return _SensorCard(
      title: 'Eye Dryness',
      subtitle: 'Indicative dryness level & blink activity.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$drynessPercent%',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2EC4B6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            drynessLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.remove_red_eye_outlined,
                  size: 26, color: Colors.black54),
              SizedBox(width: 8),
              Icon(Icons.remove_red_eye_outlined,
                  size: 22, color: Colors.black38),
              SizedBox(width: 8),
              Icon(Icons.remove_red_eye_outlined,
                  size: 18, color: Colors.black26),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Blinking icons are placeholders for future animation.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

// كرت عام نستخدمه لكل الحساسات
class _SensorCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SensorCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// دائرة الأكشن الصغيرة + النص
class _QuickActionBubble extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionBubble({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFFBF69),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2EC4B6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
