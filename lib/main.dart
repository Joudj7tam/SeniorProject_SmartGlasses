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
import 'tips_page.dart';
import 'pdf_report_service.dart';
import 'app_theme.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';

import 'success_popup.dart';

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, child) => MaterialApp(
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
        darkTheme: buildDarkTheme(),
        themeMode: themeMode,

        home: const LoginPage(),
        routes: {'/login': (_) => const LoginPage()},
      ),
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
  bool _isGeneratingReport = false;

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

      await showSuccessPopup(
        context,
        _homeSelectedCharts.contains(chart)
            ? 'Added to Home'
            : 'Removed from Home',
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
        builder: (_) => NotificationsPage(
          userId: widget.mainAccountId,
          firebaseUid: widget.firebaseUid,
          formId: formId,
        ),
      ),
    );
  }

  Future<void> _openProgressPage() async {
    final formId = _activeProfileId;

    if (formId == null || formId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No active profile found')));
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProgressPage(
          userId: widget.mainAccountId,
          firebaseUid: widget.firebaseUid,
          formId: formId,
          onBackRequested: () {
            Navigator.pop(context);
          },
        ),
      ),
    );

    await _loadHomeSelectedCharts();
  }

  void _openTipsPage() {
    final formId = _activeProfileId;

    if (formId == null || formId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No active profile found')));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TipsPage(
          mainAccountId: widget.mainAccountId,
          firebaseUid: widget.firebaseUid,
          formId: formId,
        ),
      ),
    );
  }

  Future<void> _openProfileInfoPage() async {
    final formId = _activeProfileId;

    if (formId == null || formId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No active profile found')));
      return;
    }

    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EyeHealthProfilePage(
          mainAccountId: widget.mainAccountId,
          firebaseUid: widget.firebaseUid,
          formId: formId,
        ),
      ),
    );
    if (updated == true) {
      await _loadProfiles();
    }
  }

  void _openSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          mainAccountId: widget.mainAccountId,
          firebaseUid: widget.firebaseUid,

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
                                final name = (_profiles[i]['full_name'] ?? '')
                                    .toString();
                                final isActive =
                                    _profiles[i]['is_active'] == true;
                                final formId = (_profiles[i]['id'] ?? '')
                                    .toString();
                                final isMain =
                                    (_mainFormId != null &&
                                    formId == _mainFormId);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () async {
                                      try {
                                        final formId =
                                            (_profiles[i]['id'] ?? '')
                                                .toString();

                                        final uri =
                                            Uri.parse(
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
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
                                                : const Color(
                                                    0xFFB88956,
                                                  ).withOpacity(0.10),
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
                                                      ? _sheetMint.withOpacity(
                                                          0.20,
                                                        )
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 9,
                                                            vertical: 5,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isActive
                                                            ? _sheetMint
                                                                  .withOpacity(
                                                                    0.16,
                                                                  )
                                                            : _sheetOrangeSoft
                                                                  .withOpacity(
                                                                    0.75,
                                                                  ),
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
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            isActive
                                                                ? 'Active'
                                                                : 'Tap to switch',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
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
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 5,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white
                                                              .withOpacity(
                                                                0.75,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
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

                                                        final uri =
                                                            Uri.parse(
                                                              '$backendBaseUrl/api/eye-health-form/switch',
                                                            ).replace(
                                                              queryParameters: {
                                                                'main_account_id':
                                                                    widget
                                                                        .mainAccountId,
                                                                'form_id':
                                                                    formId,
                                                              },
                                                            );

                                                        final res = await http
                                                            .post(uri);

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
                                                          context,
                                                        ).showSnackBar(
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
                                    backgroundColor: Colors.white.withOpacity(
                                      0.45,
                                    ),
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
                                  onPressed: () =>
                                      _confirmDeleteMainAccount(ctx),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    backgroundColor: Colors.red.withOpacity(
                                      0.045,
                                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBg1 : const Color(0xFFF8EFE5),
      extendBody: true,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [kDarkBg1, kDarkBg2, kDarkBg3]
                    : const [
                        Color(0xFF7FD1C9),
                        Color(0xFFEAF4EC),
                        Color(0xFFFFD08A),
                      ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          Positioned(
            top: -90,
            left: -90,
            child: _homeSoftCircle(
              260,
              isDark ? kDarkAccent : Colors.white,
              isDark ? 0.06 : 0.18,
            ),
          ),
          Positioned(
            bottom: 120,
            right: -70,
            child: _homeSoftCircle(
              220,
              isDark ? kDarkBlue : const Color(0xFFFFBF69),
              isDark ? 0.08 : 0.22,
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 18, 26, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _openProfileInfoPage,
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: isDark
                                ? kDarkAccentSoft
                                : const Color(0xFFCBF3F0).withOpacity(0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? kDarkBorder
                                  : Colors.white.withOpacity(0.55),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 34,
                            color: Color(0xFF2EC4B6),
                          ),
                        ),
                      ),

                      const SizedBox(width: 18),

                      InkWell(
                        onTap: _openProfileMenu,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(),
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? kDarkMuted
                                    : const Color(0xFF4D4540),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _activeAccountName,
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? kDarkText
                                    : const Color(0xFF4D3732),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      IconButton(
                        onPressed: _openNotifications,
                        icon: const Icon(Icons.notifications_rounded),
                        color: isDark ? kDarkText : Colors.white,
                        iconSize: 27,
                      ),

                      IconButton(
                        onPressed: _toggleQuickActions,
                        icon: const Icon(Icons.add_circle_rounded),
                        color: isDark ? kDarkText : Colors.white,
                        iconSize: 30,
                      ),
                    ],
                  ),

                  const SizedBox(height: 58),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildSelectedChartsSection(),
                          const SizedBox(height: 12),

                          _buildDailyTipCard(),
                          const SizedBox(height: 12),

                          _buildGenerateReportButton(),
                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_showQuickActions) _buildQuickActionsOverlay(),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SmartProgressFab(
        selectedIndex: _selectedIndex,
        onTap: _openProgressPage,
      ),

      bottomNavigationBar: SmartBottomNav(
        selectedIndex: _selectedIndex,

        onHomeTap: () => _onItemTapped(0),

        onSettingsTap: _openSettingsPage,

        onProgressTap: _openProgressPage,

        onAlertsTap: _openNotifications,

        onTipsTap: _openTipsPage,
      ),
    );
  }

  Widget _homeSoftCircle(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        shape: BoxShape.circle,
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
        subtitle: '',
        child: SizedBox(
          height: 210,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: 0.30,
                  child: Image.asset(
                    'assets/images/home_chart.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'Go to Progress and select charts to show here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF4D4540),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
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
            subtitle: 'Selected from Progress page.',
            child: SizedBox(height: 380, child: _chartWidget(type)),
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

  Widget _buildDailyTipCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : const Color(0xFFEAF4F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? kDarkBorder : const Color(0xFFBFE3DF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2EC4B6).withOpacity(isDark ? 0.10 : 0.15),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Color(0xFF8FCAC3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Eye Care Tip',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6AAFA7),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Follow the 20-20-20 rule: Every 20 minutes,\nlook at something 20 feet away for 20 seconds.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    color: isDark ? kDarkMuted : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Image.asset(
            'assets/images/phone_20.png',
            width: 90,
            height: 90,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  String _formatDateForApi(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _generatePdfReport() async {
    final formId = _activeProfileId;

    if (formId == null || formId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active profile selected')),
      );
      return;
    }

    setState(() {
      _isGeneratingReport = true;
    });

    try {
      final savedPath = await PdfReportService.generateAndSaveReport(
        userId: widget.mainAccountId,
        firebaseUid: widget.firebaseUid,
        formId: formId,
        selectedDate: _formatDateForApi(DateTime.now()),
        rangeType: 'day',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF report saved: $savedPath')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate report: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingReport = false;
        });
      }
    }
  }

  // ================== Generate Report  ==================
  Widget _buildGenerateReportButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 4),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFFB25E), Color(0xFF6FD3C8)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2EC4B6).withOpacity(0.15),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _isGeneratingReport ? null : _generatePdfReport,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.32),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.45)),
                  ),
                  child: _isGeneratingReport
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.auto_graph_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isGeneratingReport
                            ? 'Generating Report...'
                            : 'Generate a Report',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Create a summary based on your latest readings & profile.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      decoration: BoxDecoration(
        color: isDark
            ? kDarkCard
            : const Color(0xFFFFFAF4).withOpacity(0.93),
        borderRadius: BorderRadius.circular(18),
        border: isDark
            ? Border.all(color: kDarkBorder, width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.35)
                : Colors.black.withOpacity(0.18),
            blurRadius: 22,
            spreadRadius: -8,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? kDarkText : const Color(0xFF2D2926),
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? kDarkMuted : const Color(0xFF8F8880),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),
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
