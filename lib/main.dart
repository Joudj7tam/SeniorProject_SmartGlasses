import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notifications_page.dart';
import 'smart_bottom_nav.dart';

import 'register_page.dart';
import 'health_form_page.dart';
import 'login_page.dart';




/// Background handler for FCM messages.
///
/// Notes:
/// - Must call Firebase.initializeApp() here because this runs in a background isolate.
/// - Keep logic lightweight; heavy work should be deferred or handled by backend.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
    // Optional: persist/log message data for debugging or analytics.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase once at app startup.
  await Firebase.initializeApp();
  
  // Register background handler before runApp.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
      home: const HomePage(), //############################
      //home: const LoginPage(),


      routes: {
        '/home': (_) => const HomePage(),
        '/login': (_) => const LoginPage(),
        '/health-form': (_) => const HealthFormPage(),
      },

    );
  }
}
/// Home page which shows a quick overview and listens to notification events.
///
/// Maintainability note:
/// - If this file grows, extract:
///   1) Firebase messaging setup -> services/notification_service.dart
///   2) Cards/widgets -> widgets/ folder
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  
  @override
  void initState() {
    super.initState();
    _initFirebaseMessaging();
  }

  int _selectedIndex = 2; 
  // Demo values only. Replace later with live sensor stream/state.
  final double _demoDistanceCm = 55; // مسافة تقريبية
  final double _demoBrightness = 0.65; // من 0 إلى 1
  final double _demoDryness = 0.35; // من 0 إلى 1

  // للحالة حق قائمة الأكشنات العلوية
  bool _showQuickActions = false;
  bool _wifiOn = true;
  bool _isDarkMode = false; 

  // ================= Sub-Accounts  =================
  final List<String> _subAccounts = ['Sarah Ahmed']; // first = main (demo)
  int _activeAccountIndex = 0; // 0 = main
  String get _activeAccountName => _subAccounts[_activeAccountIndex];


  /// Initializes Firebase Cloud Messaging (permissions + token + event listeners).
  ///
  /// Maintainability note:
  /// - Keep all FCM wiring here (or move to a dedicated service later).
  /// - Ensure we handle all three app states:
  ///   1) foreground (onMessage)
  ///   2) background -> user taps (onMessageOpenedApp)
  ///   3) terminated -> opened by notification (getInitialMessage)
  Future<void> _initFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request notification permissions (iOS + Android 13+ behavior).
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Print token for backend registration/testing.
    String? token = await messaging.getToken();
    debugPrint('FCM TOKEN: $token');

    // App is open (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint(
        ' رسالة جديدة في foreground: ${message.notification?.title}',
      );
    });

    // App is in background and opened by user tapping notification.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('📬 User tapped notification: ${message.notification?.title}');
      _openNotifications(); // نودّيه مباشرة لصفحة الإشعارات
    });

    // App was terminated and opened via notification tap.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        ' App opened from terminated state by notification: ${initialMessage.notification?.title}',
      );
      
      Future.microtask(() {
        _openNotifications();
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Color _iconColor(int index) {
    return _selectedIndex == index
        ? const Color(0xFF2EC4B6) // selected item
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
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

 /// UI-only mode toggle. If you later implement real theming,
  /// connect it to MaterialApp.themeMode.
  void _toggleMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });    
  }
////////////##########
void _openProfileMenu() {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Profiles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // List accounts
            ...List.generate(_subAccounts.length, (i) {
              final name = _subAccounts[i];
              final isActive = i == _activeAccountIndex;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFCBF3F0),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFF2EC4B6)),
                  ),
                ),
                title: Text(name),
                subtitle: isActive ? const Text('Active') : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isActive)
                      IconButton(
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: () {
                          setState(() => _activeAccountIndex = i);
                          Navigator.pop(ctx);
                        },
                      ),
                    if (i != 0) // prevent deleting main from here
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDeleteSubAccount(ctx, i),
                      ),
                  ],
                ),
                onTap: () {
                  setState(() => _activeAccountIndex = i);
                  Navigator.pop(ctx);
                },
              );
            }),

            const SizedBox(height: 6),

            // Add sub-account
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Sub-Account'),
                onPressed: () => _createSubAccount(ctx),
              ),
            ),

            const SizedBox(height: 6),

            // Delete main account (FR9) - UI only
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text(
                  'Delete Main Account',
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () => _confirmDeleteMainAccount(ctx),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      );
    },
  );
}

Future<void> _createSubAccount(BuildContext bottomSheetContext) async {

  Navigator.pop(bottomSheetContext); 

  // يفتح Health Form أول
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const HealthFormPage()),
  );

  // إذا رجع اسم من الفورم → ينشئ الحساب
  if (result != null && result is String) {
    setState(() {
      _subAccounts.add(result);
      _activeAccountIndex = _subAccounts.length - 1;
    });
  }
}

Future<void> _confirmDeleteSubAccount(BuildContext bottomSheetContext, int index) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Sub-Account'),
      content: Text('Delete "${_subAccounts[index]}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (ok != true) return;

  setState(() {
    _subAccounts.removeAt(index);
    if (_activeAccountIndex == index) _activeAccountIndex = 0;
    if (_activeAccountIndex > _subAccounts.length - 1) _activeAccountIndex = 0;
  });

  Navigator.pop(bottomSheetContext); // close sheet after delete
}

Future<void> _confirmDeleteMainAccount(BuildContext bottomSheetContext) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Main Account'),
      content: const Text(
        'This will delete the main account and ALL sub-accounts (UI only). Continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete All'),
        ),
      ],
    ),
  );

  if (ok != true) return;

  setState(() {
    _subAccounts
      ..clear()
      ..add('Sarah Ahmed'); // reset demo main
    _activeAccountIndex = 0;
  });

  Navigator.pop(bottomSheetContext);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Main account deleted successfully')),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(      
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ====== header ======
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFFCBF3F0), 
                        child: Icon(
                          Icons.person,
                          size: 28,
                          color: Color(0xFF2EC4B6), 
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: _openProfileMenu,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(),
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _activeAccountName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                          ],
                        ),
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
                    style: TextStyle(fontSize: 13, color: Colors.black54),
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

          // ====== (Edit / Wi-Fi / Mode) circles ======
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
        child: Icon(Icons.show_chart, color: _iconColor(2)),
      ),

      // ================== Bottom Bar ==================
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

  /// Quick actions overlay (Edit / Wi-Fi / Mode).
  /// Keep this UI separate from business logic; actions should call dedicated methods.  
  Widget _buildQuickActionsOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _toggleQuickActions,
            child: Container(color: Colors.black.withOpacity(0.25)),
          ),
          // close button
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'close_actions',
              mini: true,
              shape: const CircleBorder(),
              backgroundColor: Colors.white,
              onPressed: _toggleQuickActions,
              child: const Icon(Icons.close, color: Colors.black87),
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
                  // Edit 
                  Transform.translate(
                    offset: const Offset(-8, 0),
                    child: _QuickActionBubble(
                      icon: Icons.edit,
                      label: 'Edit',
                      onTap: () {
                        _toggleQuickActions(); // يقفل القائمة
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                      },

                    ),
                  ),
                  const SizedBox(height: 12),
                  // Wi-Fi 
                  _QuickActionBubble(
                    icon: _wifiOn ? Icons.wifi : Icons.wifi_off,
                    label: 'Wi-Fi',
                    onTap: _toggleWifi,
                  ),
                  const SizedBox(height: 12),
                  // Mode 
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

  // Cards (UI only). When real sensor data arrives, drive them via state management.

  // 1) Distance Card
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
                              right: index == dashCount - 1 ? 0 : dashSpace,
                            ),
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
                Icon(
                  Icons.desktop_windows_outlined,
                  size: 36,
                  color: Colors.black54,
                ),
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

  // 2) Brightness Card
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

  // 3) Dryness Card
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
              Icon(
                Icons.remove_red_eye_outlined,
                size: 26,
                color: Colors.black54,
              ),
              SizedBox(width: 8),
              Icon(
                Icons.remove_red_eye_outlined,
                size: 22,
                color: Colors.black38,
              ),
              SizedBox(width: 8),
              Icon(
                Icons.remove_red_eye_outlined,
                size: 18,
                color: Colors.black26,
              ),
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

//// Shared UI card for sensor/indicator previews.
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
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Small circular button with icon + label used in quick actions overlay.
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
            child: Icon(icon, color: const Color(0xFF2EC4B6)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
