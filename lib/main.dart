import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'eye_health_profile_page.dart';

import 'notifications_page.dart';
import 'smart_bottom_nav.dart';

import 'register_page.dart';
import 'health_form_page.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'progress_page.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';

const String backendBaseUrl = 'http://10.0.2.2:8080';

const Color _sheetCream = Color(0xFFFFF7EE);
const Color _sheetCard = Color(0xFFFFFCF8);
const Color _sheetMint = Color(0xFF2EC4B6);
const Color _sheetMintSoft = Color(0xFFDDF7F4);
const Color _sheetOrange = Color(0xFFFF9F1C);
const Color _sheetOrangeSoft = Color(0xFFFFE9C8);
const Color _sheetText = Color(0xFF3E2E25);
const Color _sheetMuted = Color(0xFF8F7D70);
const Color _sheetBorder = Color(0xFFEADCCD);

// For demo/testing purposes, using fixed device ID.
const String kDeviceId = 'SMART_GLASSES_001';

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
      // home: const HomePage(), //############################
      home: const LoginPage(), //############################
      // home: const RegisterPage(), //############################
      routes: {'/login': (_) => const LoginPage()},
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
  final String mainAccountId;
  final String firebaseUid;
  const HomePage({
    super.key,
    required this.mainAccountId,
    required this.firebaseUid,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _mainFormId;
  String? deviceId;
  bool _profilesLoadedOnce = false; // first-time loading indicator
  bool _isUpdatingHomeCharts = false;

  final Set<ProgressChartType> _homeSelectedCharts = {};

  bool _powerOn = false;
  Timer? _deviceStateTimer;

  // ================= Glasses Link =================

  String? _askedLinkForFormId;

  final ValueNotifier<Map<String, String?>> _glassesLink = ValueNotifier({
    'user_id': null,
    'form_id': null,
    'name': null,
    'deviceId': null,
  });

  String? get _activeProfileId {
    if (_profiles.isEmpty) return null;

    final active = _profiles.firstWhere(
      (p) => p['is_active'] == true,
      orElse: () => _profiles[0],
    );

    return (active['id'] ?? '').toString();
  }

  String get _activeProfileName => _activeAccountName;

  @override
  void initState() {
    super.initState();
    _initFirebaseMessaging();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProfiles();
    });

    _deviceStateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadDeviceStateFromDb(),
    );
  }

  @override
  void dispose() {
    _deviceStateTimer?.cancel();
    super.dispose();
  }

  // Checks with backend if the active profile is linked to glasses and updates state accordingly.
  Future<bool> _isActiveProfileLinkedFromBackend() async {
    final formId = _activeProfileId;
    if (formId == null) return false;

    try {
      final uri = Uri.parse('$backendBaseUrl/api/devices/by-user-form').replace(
        queryParameters: {
          'user_id': widget.mainAccountId, // main account MongoDB id
          'form_id': formId, // eye health form MongoDB id
        },
      );

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final device = (decoded['device'] as Map?)?.cast<String, dynamic>();

        final deviceId = (device?['deviceId'] ?? '').toString();
        final name = _activeProfileName;

        // حدّث state من الباك
        _glassesLink.value = {
          'deviceId': deviceId.isEmpty ? null : deviceId,
          'user_id': widget.mainAccountId,
          'form_id': formId,
          'name': name,
        };

        return deviceId.isNotEmpty;
      }

      if (res.statusCode == 404) {
        // not linked
        return false;
      }

      debugPrint('Link check failed: ${res.statusCode} ${res.body}');
      return false;
    } catch (e) {
      debugPrint('Link check error: $e');
      return false;
    }
  }

  Future<void> _refreshDeviceLinkByDeviceId() async {
    try {
      final uri = Uri.parse(
        '$backendBaseUrl/api/devices/link-by-device',
      ).replace(queryParameters: {'deviceId': kDeviceId});

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;

        final userId = (decoded['user_id'] ?? '').toString();
        final formId = (decoded['form_id'] ?? '').toString();

        // جيبي اسم البروفايل من الليست باستخدام form_id
        String? linkedName;
        if (formId.isNotEmpty) {
          final match = _profiles.firstWhere(
            (p) => (p['id'] ?? '').toString() == formId,
            orElse: () => {},
          );
          final n = (match['full_name'] ?? '').toString();
          linkedName = n.isNotEmpty ? n : null;
        }

        _glassesLink.value = {
          'deviceId': kDeviceId,
          'user_id': userId.isNotEmpty ? userId : null,
          'form_id': formId.isNotEmpty ? formId : null,
          'name': linkedName,
        };
        return;
      }

      if (res.statusCode == 404) {
        // الديفايس مو مربوط لأي حساب
        _glassesLink.value = {
          'deviceId': kDeviceId,
          'user_id': null,
          'form_id': null,
          'name': null,
        };
        return;
      }

      debugPrint('by-device failed: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('by-device error: $e');
    }
  }

  // ================= Home Selected Charts =================

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

  Future<void> _loadHomeSelectedCharts() async {
    final formId = _activeProfileId;
    if (formId == null) return;

    try {
      final uri =
          Uri.parse(
            '$backendBaseUrl/api/eye-health-form/get-home-selected-charts',
          ).replace(
            queryParameters: {
              'form_id': formId,
              'main_account_id': widget.mainAccountId,
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
        _homeSelectedCharts
          ..clear()
          ..addAll(loadedCharts);
      });
    } catch (e) {
      debugPrint('Load home charts error: $e');
    }
  }

  Future<void> _updateHomeSelectedChartsInBackend() async {
    final formId = _activeProfileId;
    if (formId == null) return;

    final chartStrings = _homeSelectedCharts.map(_chartTypeToString).toList();

    try {
      final uri = Uri.parse(
        '$backendBaseUrl/api/eye-health-form/update-home-selected-charts/$formId',
      ).replace(queryParameters: {'main_account_id': widget.mainAccountId});

      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(chartStrings),
      );

      if (res.statusCode != 200) {
        throw 'Failed to update home charts (code: ${res.statusCode}) ${res.body}';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _toggleChartForHome(ProgressChartType chart) async {
    if (_isUpdatingHomeCharts) return;

    final previousCharts = Set<ProgressChartType>.from(_homeSelectedCharts);

    setState(() {
      _isUpdatingHomeCharts = true;
      if (_homeSelectedCharts.contains(chart)) {
        _homeSelectedCharts.remove(chart);
      } else {
        _homeSelectedCharts.add(chart);
      }
    });

    try {
      await _updateHomeSelectedChartsInBackend();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _homeSelectedCharts.contains(chart)
                ? 'Added to Home'
                : 'Removed from Home',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _homeSelectedCharts
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

  // Loads sub-accounts (profiles) from backend.
  Future<void> _loadProfiles() async {
    try {
      final uri = Uri.parse(
        '$backendBaseUrl/api/eye-health-form/list',
      ).replace(queryParameters: {'main_account_id': widget.mainAccountId});

      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw 'Failed to load profiles (code: ${res.statusCode})';
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (decoded['data'] as List).cast<Map<String, dynamic>>();
      final mainFormId = (decoded['main_form_id'] ?? '').toString();

      if (!mounted) return;
      setState(() {
        _profiles = data;
        _mainFormId = mainFormId;
        // Sort: main form first
        if (_mainFormId != null) {
          _profiles.sort((a, b) {
            final aIsMain = (a['id'] ?? '').toString() == _mainFormId;
            final bIsMain = (b['id'] ?? '').toString() == _mainFormId;
            if (aIsMain == bIsMain) return 0;
            return aIsMain ? -1 : 1;
          });
        }
        _profilesLoadedOnce = true;
      });

      await _refreshDeviceLinkByDeviceId();
      await _loadDeviceStateFromDb();
      await _loadHomeSelectedCharts();

      if (_profiles.isEmpty) {
        _glassesLink.value = {
          'deviceId': kDeviceId,
          'user_id': null,
          'form_id': null,
          'name': null,
        };
        return;
      }

      final linked = await _isActiveProfileLinkedFromBackend();

      final activeFormId = _activeProfileId; // بعد setState
      if (activeFormId != null && _askedLinkForFormId != activeFormId) {
        _askedLinkForFormId = activeFormId;

        if (!linked && mounted) {
          await _showLinkGlassesDialog();
        }
      }

      // ===== Ask to link glasses ONCE when profiles load the first time =====
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot connect to server. Is backend running?'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showLinkGlassesDialog() async {
    final formId = _activeProfileId;
    final formName = _activeProfileName;

    if (formId == null) return;

    // check from backend if the current active account is already linked
    final linked = await _isActiveProfileLinkedFromBackend();
    if (linked) return;

    // avoiding asking to link if the currently active profile is already linked to the glasses
    if (_glassesLink.value['form_id'] == formId) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Link Glasses',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('Do you want to link the glasses to "$formName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Confirm',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result != true) return;

    // ✅ Confirm => assign في الباك
    try {
      final uri = Uri.parse('$backendBaseUrl/api/devices/assign');
      final body = jsonEncode({
        'deviceId': kDeviceId,
        'user_id': widget.mainAccountId, // main account mongo id
        'form_id': formId, // active form id
      });

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (res.statusCode != 200) {
        throw 'Assign failed (code: ${res.statusCode}): ${res.body}';
      }

      // ✅ بعد الـ assign، اعيدي قراءة الحالة من الباك لتثبيت UI
      await _refreshDeviceLinkByDeviceId();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // ================= load Device State =================
  Future<void> _loadDeviceStateFromDb() async {
    final formId = _activeProfileId;
    if (formId == null) return;

    try {
      final uri = Uri.parse('$backendBaseUrl/api/devices/by-user-form').replace(
        queryParameters: {'user_id': widget.mainAccountId, 'form_id': formId},
      );

      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final device = data['device'];

        final newDeviceId = device['deviceId']?.toString();
        final newPower = device['power'] == true;

        if (!mounted) return;

        final hasChanged = (deviceId != newDeviceId) || (_powerOn != newPower);

        if (hasChanged) {
          setState(() {
            deviceId = newDeviceId;
            _powerOn = newPower;
          });
        }
      } else {
        debugPrint('Device not found');
      }
    } catch (e) {
      debugPrint('Load power error: $e');
    }
  }

  int _selectedIndex = 0;
  int _previousIndex = 0;
  // Demo values only. Replace later with live sensor stream/state.
  final double _demoDistanceCm = 55; // مسافة تقريبية
  final double _demoBrightness = 0.65; // من 0 إلى 1
  final double _demoDryness = 0.35; // من 0 إلى 1

  // للحالة حق قائمة الأكشنات العلوية
  bool _showQuickActions = false;
  bool _wifiOn = true;
  bool _isDarkMode = false;

  // ================= Smart-Light =================
  // Smart-Light values (still stored هنا عشان نعرضها هناك)
  bool _smartLightEnabled = true;
  final double _smartLightIntensity = 0.95; // 0..1
  final Color _smartLightColor = const Color(0xFF06D6A0); // example green

  // ================= Sub-Accounts  =================
  // Profiles = Forms from backend
  List<Map<String, dynamic>> _profiles =
      []; // each item has: id, full_name, is_active

  String get _activeAccountName {
    if (_profiles.isEmpty) return '...';

    // find active profile (is_active == true)
    final active = _profiles.firstWhere(
      (p) => p['is_active'] == true,
      orElse: () => _profiles[0],
    );

    return (active['full_name'] ?? '...').toString();
  }

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

    if (token != null && token.isNotEmpty) {
      await _syncFcmTokenToBackend(token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM token refreshed: $newToken');
      if (newToken.isNotEmpty) {
        await _syncFcmTokenToBackend(newToken);
      }
    });

    // App is open (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint(' رسالة جديدة في foreground: ${message.notification?.title}');
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

  Future<void> _syncFcmTokenToBackend(String token) async {
    try {
      final uri = Uri.parse('$backendBaseUrl/api/users/update-fcm-token')
          .replace(
            queryParameters: {
              'user_id': widget.mainAccountId,
              'fcm_token': token,
            },
          );

      final res = await http.post(uri);
      if (res.statusCode != 200) {
        debugPrint('sync token failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('sync token error: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      if (index != _selectedIndex) {
        _previousIndex = _selectedIndex;
        _selectedIndex = index;
      }
    });
  }

  void _goBackFromProgress() {
    setState(() {
      _selectedIndex = _previousIndex;
    });
  }

  Color _iconColor(int index) {
    return _selectedIndex == index
        ? const Color(0xFF2EC4B6) // selected item
        : Colors.black45;
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
    final formId = _activeProfileId;
    if (formId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NotificationsPage(userId: widget.mainAccountId, formId: formId),
      ),
    );
  }

  void _openProfileInfoPage() {
    final formId = _activeProfileId;

    if (formId == null || formId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active profile found')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EyeHealthProfilePage(
          mainAccountId: widget.mainAccountId,
          firebaseUid: widget.firebaseUid,
          formId: formId,
        ),
      ),
    );
  }

  void _openSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          mainAccountId: widget.mainAccountId,
          smartLightEnabled: _smartLightEnabled,
          smartLightIntensity: _smartLightIntensity,
          smartLightColor: _smartLightColor,
          onSmartLightToggle: (v) => setState(() => _smartLightEnabled = v),

          glassesLink: _glassesLink,

          onRequestLink: () => _showLinkGlassesDialog(),
          activeFormId: _activeProfileId,
        ),
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

  /// UI-only mode toggle. If you later implement real theming,
  /// connect it to MaterialApp.themeMode.
  void _toggleMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  void _openProfileMenu() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (ctx) {
      final sheetHeight = MediaQuery.of(ctx).size.height * 0.72;

      return Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: _sheetCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -55,
              right: -35,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: _sheetMint.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -45,
              left: -35,
              child: Container(
                width: 145,
                height: 145,
                decoration: BoxDecoration(
                  color: _sheetOrange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _sheetText.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _sheetMintSoft,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.manage_accounts_outlined,
                            color: _sheetMint,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profiles',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: _sheetText,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Switch between your eye-health profiles.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _sheetMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            if (_profiles.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: _sheetCard,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: _sheetBorder),
                                ),
                                child: const Text(
                                  'No profiles available',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _sheetMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),

                            ...List.generate(_profiles.length, (i) {
                              final name =
                                  (_profiles[i]['full_name'] ?? '').toString();
                              final isActive =
                                  _profiles[i]['is_active'] == true;
                              final formId =
                                  (_profiles[i]['id'] ?? '').toString();
                              final isMain =
                                  (_mainFormId != null && formId == _mainFormId);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () async {
                                    try {
                                      final formId =
                                          (_profiles[i]['id'] ?? '').toString();

                                      final uri = Uri.parse(
                                        '$backendBaseUrl/api/eye-health-form/switch',
                                      ).replace(
                                        queryParameters: {
                                          'main_account_id':
                                              widget.mainAccountId,
                                          'form_id': formId,
                                        },
                                      );

                                      final res = await http.post(uri);

                                      if (res.statusCode != 200) {
                                        throw 'Switch failed (code: ${res.statusCode})';
                                      }

                                      await _loadProfiles();
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? _sheetMintSoft.withOpacity(0.82)
                                          : _sheetCard,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isActive
                                            ? _sheetMint.withOpacity(0.45)
                                            : Colors.white.withOpacity(0.90),
                                        width: isActive ? 1.4 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isActive
                                              ? _sheetMint.withOpacity(0.18)
                                              : const Color(0xFFB88956)
                                                  .withOpacity(0.10),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 54,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: isActive
                                                  ? const [
                                                      Color(0xFFBDF3EE),
                                                      Color(0xFFEFFFFC),
                                                    ]
                                                  : const [
                                                      Color(0xFFFFE7C2),
                                                      Color(0xFFFFF8EF),
                                                    ],
                                            ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isActive
                                                    ? _sheetMint
                                                        .withOpacity(0.20)
                                                    : _sheetOrange
                                                        .withOpacity(0.14),
                                                blurRadius: 12,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                color: isActive
                                                    ? _sheetMint
                                                    : _sheetOrange,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 13),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name.isEmpty
                                                    ? 'Unnamed profile'
                                                    : name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: _sheetText,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 9,
                                                      vertical: 5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: isActive
                                                          ? _sheetMint
                                                              .withOpacity(0.16)
                                                          : _sheetOrangeSoft
                                                              .withOpacity(0.75),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        999,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isActive
                                                              ? Icons
                                                                  .check_circle_outline
                                                              : Icons
                                                                  .touch_app_outlined,
                                                          size: 13,
                                                          color: isActive
                                                              ? _sheetMint
                                                              : _sheetOrange,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          isActive
                                                              ? 'Active'
                                                              : 'Tap to switch',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: isActive
                                                                ? _sheetMint
                                                                : _sheetOrange,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (isMain) ...[
                                                    const SizedBox(width: 7),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 5,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withOpacity(0.75),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(999),
                                                      ),
                                                      child: const Text(
                                                        'Main',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: _sheetMuted,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (!isActive)
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.85),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: _sheetBorder,
                                                  ),
                                                ),
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  icon: const Icon(
                                                    Icons.swap_horiz_rounded,
                                                    color: _sheetText,
                                                    size: 22,
                                                  ),
                                                  onPressed: () async {
                                                    try {
                                                      final formId =
                                                          (_profiles[i]['id'] ??
                                                                  '')
                                                              .toString();

                                                      final uri = Uri.parse(
                                                        '$backendBaseUrl/api/eye-health-form/switch',
                                                      ).replace(
                                                        queryParameters: {
                                                          'main_account_id':
                                                              widget
                                                                  .mainAccountId,
                                                          'form_id': formId,
                                                        },
                                                      );

                                                      final res =
                                                          await http.post(uri);

                                                      if (res.statusCode !=
                                                          200) {
                                                        throw 'Switch failed (code: ${res.statusCode})';
                                                      }

                                                      await _loadProfiles();
                                                      if (ctx.mounted) {
                                                        Navigator.pop(ctx);
                                                      }

                                                      if (!mounted) return;
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            e.toString(),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                              ),
                                            if (!isMain) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: Colors.red
                                                      .withOpacity(0.07),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    color: Colors.redAccent,
                                                    size: 21,
                                                  ),
                                                  onPressed: () =>
                                                      _confirmDeleteSubAccount(
                                                    ctx,
                                                    i,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: 4),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add Sub-Account'),
                                onPressed: () => _createSubAccount(ctx),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _sheetOrange,
                                  side: BorderSide(
                                    color: _sheetOrange.withOpacity(0.38),
                                    width: 1.4,
                                  ),
                                  backgroundColor:
                                      Colors.white.withOpacity(0.45),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                icon: const Icon(
                                  Icons.delete_forever_rounded,
                                  color: Colors.redAccent,
                                ),
                                label: const Text(
                                  'Delete Main Account',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                onPressed: () => _confirmDeleteMainAccount(ctx),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  backgroundColor:
                                      Colors.red.withOpacity(0.045),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),
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
      );
    },
  );
}

  Future<void> _createSubAccount(BuildContext bottomSheetContext) async {
    Navigator.pop(bottomSheetContext);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HealthFormPage(
          mainAccountId: widget.mainAccountId,
          firebaseUid: widget.firebaseUid,
          goHomeAfterSave: false,
        ),
      ),
    );

    _askedLinkForFormId = null;
    await _loadProfiles(); // the new form is now active, so refresh profiles to update UI
  }

  Future<void> _confirmDeleteSubAccount(
    BuildContext bottomSheetContext,
    int index,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sub-Account'),
        content: Text(
          'Delete "${(_profiles[index]['full_name'] ?? '').toString()}"?',
        ),
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

    try {
      final formId = (_profiles[index]['id'] ?? '').toString();

      final uri = Uri.parse('$backendBaseUrl/api/eye-health-form/delete')
          .replace(
            queryParameters: {
              'main_account_id': widget.mainAccountId,
              'form_id': formId,
            },
          );

      final res = await http.delete(uri);

      if (res.statusCode != 200) {
        throw 'Delete failed (code: ${res.statusCode})';
      }

      _glassesLink.value = {
        'deviceId': kDeviceId,
        'user_id': null,
        'form_id': null,
        'name': null,
      };

      // reload profiles
      await _loadProfiles();

      if (bottomSheetContext.mounted) Navigator.pop(bottomSheetContext);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmDeleteMainAccount(
    BuildContext bottomSheetContext,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Main Account'),
        content: const Text(
          'This will delete the main account and ALL sub-accounts. Continue?',
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

    try {
      final uri = Uri.parse(
        '$backendBaseUrl/api/users/delete-main',
      ).replace(queryParameters: {'main_uid': widget.firebaseUid});

      final res = await http.delete(uri);

      if (res.statusCode != 200) {
        throw 'Delete failed (code: ${res.statusCode})';
      }

      if (!mounted) return;

      // go back to register page after deleting main account
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RegisterPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 2
          ? ProgressPage(
              selectedForHome: _homeSelectedCharts,
              onToggleForHome: _toggleChartForHome,
              userId: widget.mainAccountId,
              firebaseUid: widget.firebaseUid,
              formId: _activeProfileId ?? '',
              onBackRequested: _goBackFromProgress,
            )
          : Stack(
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
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: _openProfileInfoPage,
                              child: const CircleAvatar(
                                radius: 24,
                                backgroundColor: Color(0xFFCBF3F0),
                                child: Icon(
                                  Icons.person,
                                  size: 28,
                                  color: Color(0xFF2EC4B6),
                                ),
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
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
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
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                              ),
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
                                _buildSelectedChartsSection(),
                                const SizedBox(height: 16),

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
        backgroundColor: const Color(0xFFFFBF69),
        onPressed: () => _onItemTapped(2),
        child: Icon(Icons.show_chart, color: _iconColor(2)),
      ),

      // ================== Bottom Bar ==================
      bottomNavigationBar: SmartBottomNav(
        selectedIndex: _selectedIndex,
        onItemTap: (index) {
          if (index == 1) {
            // Settings
            _openSettingsPage();
            return;
          }
          if (index == 3) {
            // Alerts → افتح صفحة الإشعارات
            _openNotifications();
            return;
          }
          _onItemTapped(index);
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
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
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

  // Graphics card
  Widget _buildSelectedChartsSection() {
    if (_homeSelectedCharts.isEmpty) {
      return _SensorCard(
        title: 'Home Charts',
        subtitle: 'No charts selected yet.',
        child: const SizedBox(
          height: 60,
          child: Center(
            child: Text('Go to Progress and select charts to show here.'),
          ),
        ),
      );
    }

    return Column(
      children: _homeSelectedCharts.map((type) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SensorCard(
            title: _chartTitle(type),
            subtitle: 'Selected from Progress page .',
            child: SizedBox(
              height: 380, // مهم: عشان الرسم يبان داخل الكارد
              child: _chartWidget(type),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _chartTitle(ProgressChartType type) {
    switch (type) {
      case ProgressChartType.blinkByTime:
        return 'Blink by Time';
      case ProgressChartType.alerts:
        return 'Alerts';
      case ProgressChartType.blueLightScatter:
        return 'Blue Light';
    }
  }

  String _todayToApi() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Widget _chartWidget(ProgressChartType type) {
    final formId = _activeProfileId ?? '';
    final selectedDate = _todayToApi();

    switch (type) {
      case ProgressChartType.blinkByTime:
        return BlinkByTimeBarChart(
          userId: widget.mainAccountId,
          formId: formId,
          selectedDate: selectedDate,
        );
      case ProgressChartType.alerts:
        return AlertsBarChart(
          range: TimeRange.daily,
          userId: widget.mainAccountId,
          formId: formId,
          selectedDate: selectedDate,
        );
      case ProgressChartType.blueLightScatter:
        return BlueLightScatterChart(
          range: TimeRange.daily,
          userId: widget.mainAccountId,
          formId: formId,
          selectedDate: selectedDate,
        );
    }
  }

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

  // 3) Brightness Card
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

  // 4) Dryness Card
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