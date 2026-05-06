import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'smart_bottom_nav.dart';

/// Base URL for the backend API.
///
/// Notes:
/// - Android Emulator uses 10.0.2.2 to access host machine localhost.
/// - Keep this in one place to avoid hard-coded URLs across the app.
/// - Consider moving it to a config file (e.g., lib/config/app_config.dart).
const String backendBaseUrl = 'http://10.0.2.2:8080';

/// Local UI model for a notification row.
///
/// Maintainability note:
/// - Keep it aligned with backend response fields.
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String? metricName;
  final double? criticalValue;
  bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    this.metricName,
    this.criticalValue,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      metricName: json['metric_name'] as String?,
      criticalValue: json['critical_value'] == null
          ? null
          : (json['critical_value'] as num).toDouble(),
      isRead: json['isRead'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  final String userId; // mainAccountId
  final String formId; // active profile (eye health form id)

  const NotificationsPage({
    super.key,
    required this.userId,
    required this.formId,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  Color get _bgColor => const Color(0xFFFFF7EE);
  Color get _accent => const Color(0xFF2EC4B6);

  void _goHome() {
  Navigator.pop(context);
}

void _goSettings() {
  Navigator.pop(context);
  // لاحقًا إذا حبيتي تفتحين Settings مباشرة من هنا،
  // نحتاج نمرر mainAccountId وباقي بيانات SettingsPage لهذه الصفحة.
}

void _goProgress() {
  Navigator.pop(context);
  // بما أن Progress حاليًا داخل HomePage عن طريق selectedIndex = 2،
  // الرجوع للهوم هو الخيار الآمن بدون تكرار منطق HomePage.
}

void _goAlerts() {
  // نحن أصلًا داخل صفحة الإشعارات
}

void _goTips() {
  Navigator.pop(context);
  // لاحقًا إذا عندكم TipsPage مستقلة، نقدر نفتحها من هنا.
}

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  /// Maps low-level exceptions to user-friendly messages.
  /// Keeps UI text consistent and avoids leaking raw technical errors.
  String _friendlyErrorMessage(Object e) {
    if (e is SocketException) {
      return 'Cannot connect to the server. Please check your internet connection or make sure the backend is running.';
    }

    if (e is HttpException) {
      return 'Server error occurred. Please try again later.';
    }

    return 'Something went wrong while loading notifications. Please try again.';
  }

  // ------------------ API: GET ------------------
  /// Fetches notifications from backend and updates local state.
  /// Flow:
  /// 1) GET /api/notifications/
  /// 2) decode JSON -> NotificationItem list
  /// 3) sort by createdAt DESC
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('$backendBaseUrl/api/notifications/').replace(
        queryParameters: {'user_id': widget.userId, 'form_id': widget.formId},
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

        final items =
            data
                .map(
                  (e) => NotificationItem.fromJson(e as Map<String, dynamic>),
                )
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        setState(() {
          _notifications
            ..clear()
            ..addAll(items);
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load notifications (code: ${response.statusCode})';
        });
      }
    } catch (e) {
      debugPrint('Load notifications error: $e');
      setState(() {
        _errorMessage = _friendlyErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ------------------ API: DELETE (single delete) ------------------
  Future<void> _deleteNotification(NotificationItem item) async {
    final uri = Uri.parse('$backendBaseUrl/api/notifications/${item.id}')
        .replace(
          queryParameters: {'user_id': widget.userId, 'form_id': widget.formId},
        );

    try {
      final response = await http.delete(uri);

      if (response.statusCode == 200) {
        setState(() {
          _notifications.removeWhere((n) => n.id == item.id);
          _selectedIds.remove(item.id);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete (code: ${response.statusCode})'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error while deleting: $e')));
    }
  }

  // ------------------ API: PATCH (single) ------------------
  Future<void> _markNotificationRead(NotificationItem item) async {
    if (item.isRead) {
      setState(() {});
      return;
    }

    final uri = Uri.parse('$backendBaseUrl/api/notifications/${item.id}/read')
        .replace(
          queryParameters: {'user_id': widget.userId, 'form_id': widget.formId},
        );

    try {
      final response = await http.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isRead': true}),
      );

      if (response.statusCode == 200) {
        setState(() {
          item.isRead = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to mark as read (code: ${response.statusCode})',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error while updating: $e')));
    }
  }

  // ===================== اختيار متعدّد =====================

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleItemSelection(NotificationItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _notifications.length) {
        // لو الكل محدد → فك التحديد عن الكل
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_notifications.map((n) => n.id));
      }
    });
  }

  bool _isSelected(NotificationItem item) => _selectedIds.contains(item.id);

  // delete all selected item
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final ids = _selectedIds.toList();

    setState(() {
      _isLoading = true;
    });

    try {
      for (final id in ids) {
        final uri = Uri.parse('$backendBaseUrl/api/notifications/$id').replace(
          queryParameters: {'user_id': widget.userId, 'form_id': widget.formId},
        );
        final response = await http.delete(uri);
        if (response.statusCode == 200) {
          _notifications.removeWhere((n) => n.id == id);
        }
      }

      setState(() {
        _selectedIds.clear();
        _selectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error while deleting selected: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Mark as read for all selected
  Future<void> _markSelectedRead() async {
    if (_selectedIds.isEmpty) return;

    final ids = _selectedIds.toList();

    setState(() {
      _isLoading = true;
    });

    try {
      for (final id in ids) {
        final uri = Uri.parse('$backendBaseUrl/api/notifications/$id/read')
            .replace(
              queryParameters: {
                'user_id': widget.userId,
                'form_id': widget.formId,
              },
            );

        final response = await http.patch(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'isRead': true}),
        );
        if (response.statusCode == 200) {
          final item = _notifications.firstWhere(
            (n) => n.id == id,
            orElse: () => _notifications.first,
          );
          item.isRead = true;
        }
      }

      setState(() {
        _selectedIds.clear();
        _selectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error while updating selected: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===================== Helpers =====================

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  IconData _metricIcon(String? metricName) {
    switch (metricName) {
      case 'BLI':
      case 'light':
      case 'low_light':
        return Icons.wb_sunny_outlined;
      case 'DEI':
      case 'distance':
      case 'too_close':
        return Icons.monitor_heart_outlined;
      case 'EFI':
      case 'blinks':
      case 'low_blink_rate':
        return Icons.visibility_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      extendBody: true,

        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
  floatingActionButton: _selectionMode
      ? null
      : SmartProgressFab(
          selectedIndex: 3,
          onTap: _goProgress,
        ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF6), Color(0xFFFFF7EE), Color(0xFFFFE8C4)],
            stops: [0.0, 0.62, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 32,
                        color: Colors.black,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Notifications',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _selectionMode
                          ? _toggleSelectionMode
                          : _toggleSelectionMode,
                      child: Text(
                        _selectionMode ? 'Done' : 'Select',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_selectionMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 6, 28, 8),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _selectAll,
                        child: Text(
                          _selectedIds.length == _notifications.length
                              ? 'Unselect all'
                              : 'Select all',
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedIds.length} selected',
                        style: const TextStyle(
                          color: Color(0xFF8F8880),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: RefreshIndicator(
                  color: _accent,
                  onRefresh: _loadNotifications,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _selectionMode
    ? Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF4),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: _selectedIds.isEmpty ? null : _markSelectedRead,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Read'),
              style: TextButton.styleFrom(foregroundColor: _accent),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
            ),
          ],
        ),
      )
    : SmartBottomNav(
        selectedIndex: 3,
        onHomeTap: _goHome,
        onSettingsTap: _goSettings,
        onProgressTap: _goProgress,
        onAlertsTap: _goAlerts,
        onTipsTap: _goTips,
      ),
    );
  }

  String _cleanNotificationText(String text) {
    return text
        .replaceAll(RegExp(r'[🔵⚠️👁️💧🔔☀️]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Widget _buildBody() {
    if (_isLoading && _notifications.isEmpty) {
      return Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_errorMessage != null && _notifications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        children: [
          const SizedBox(height: 140),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6E6660),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton(
              onPressed: _loadNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        children: const [
          SizedBox(height: 150),
          Center(
            child: Text(
              'No notifications yet.',
              style: TextStyle(
                color: Color(0xFF8F8880),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
  physics: const BouncingScrollPhysics(),
  padding: EdgeInsets.fromLTRB(
    10,
    26,
    10,
    _selectionMode ? 110 : 150,
  ),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = _notifications[index];
        final selected = _isSelected(item);

        final tile = InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () {
            if (_selectionMode) {
              _toggleItemSelection(item);
            } else {
              _markNotificationRead(item);
            }
          },
          child: _notificationCard(item, selected),
        );

        if (_selectionMode) return tile;

        return Slidable(
          key: ValueKey(item.id),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.42,
            children: [
              SlidableAction(
                onPressed: (_) => _markNotificationRead(item),
                backgroundColor: const Color(0xFFE0FFFA),
                foregroundColor: _accent,
                icon: Icons.done_all_rounded,
                label: 'Read',
              ),
              SlidableAction(
                onPressed: (_) => _deleteNotification(item),
                backgroundColor: const Color(0xFFFFE6E9),
                foregroundColor: Colors.redAccent,
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
              ),
            ],
          ),
          child: tile,
        );
      },
    );
  }

  Widget _notificationCard(NotificationItem item, bool selected) {
    final style = _styleForNotification(item);
    final isMuted = item.isRead;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isMuted ? 0.76 : 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: selected ? _accent : style.borderColor,
          width: selected ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: style.shadowColor.withOpacity(isMuted ? 0.12 : 0.28),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_selectionMode) ...[
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selected ? _accent : Colors.black26,
              size: 24,
            ),
            const SizedBox(width: 10),
          ],

          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: style.iconBg.withOpacity(isMuted ? 0.55 : 1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              style.icon,
              color: style.iconColor.withOpacity(isMuted ? 0.55 : 1),
              size: 26,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cleanNotificationText(item.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style.titleColor.withOpacity(isMuted ? 0.55 : 1),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black.withOpacity(isMuted ? 0.48 : 0.78),
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDateTime(item.createdAt),
                  style: TextStyle(
                    color: Colors.black.withOpacity(isMuted ? 0.35 : 0.7),
                    fontSize: 12.2,
                    fontWeight: FontWeight.w500,
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

_NotificationVisual _styleForNotification(NotificationItem item) {
  final text = '${item.title} ${item.message} ${item.metricName ?? ''}'
      .toLowerCase();

  if (text.contains('blue') || text.contains('bli')) {
    return const _NotificationVisual(
      icon: Icons.wb_sunny_outlined,
      iconBg: Color(0xFFF5C990),
      iconColor: Color(0xFFE98A2F),
      titleColor: Color(0xFFE98A2F),
      borderColor: Color(0xFFF7D6B0),
      shadowColor: Color(0xFFE98A2F),
    );
  }

  if (text.contains('light') || text.contains('ambient')) {
    return const _NotificationVisual(
      icon: Icons.notifications_none_rounded,
      iconBg: Color(0xFFBDE7E1),
      iconColor: Color(0xFF73BDB5),
      titleColor: Color(0xFF73BDB5),
      borderColor: Color(0xFFBDE7E1),
      shadowColor: Color(0xFF2EC4B6),
    );
  }

  if (text.contains('dry') || text.contains('dei')) {
    return const _NotificationVisual(
      icon: Icons.water_drop_outlined,
      iconBg: Color(0xFFE7F6F4),
      iconColor: Color(0xFFBDE7E1),
      titleColor: Color(0xFFBDE7E1),
      borderColor: Color(0xFFBDE7E1),
      shadowColor: Color(0xFF2EC4B6),
    );
  }

  return const _NotificationVisual(
    icon: Icons.notifications_none_rounded,
    iconBg: Color(0xFFCBF3F0),
    iconColor: Color(0xFF2EC4B6),
    titleColor: Color(0xFF2D2926),
    borderColor: Color(0xFFECE3DA),
    shadowColor: Color(0xFF2EC4B6),
  );
}

class _NotificationVisual {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color titleColor;
  final Color borderColor;
  final Color shadowColor;

  const _NotificationVisual({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.titleColor,
    required this.borderColor,
    required this.shadowColor,
  });
}
