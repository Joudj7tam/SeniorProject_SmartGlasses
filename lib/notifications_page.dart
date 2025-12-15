import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
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
  const NotificationsPage({Key? key}) : super(key: key);

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
      final uri = Uri.parse('$backendBaseUrl/api/notifications/');
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

  // ------------------ API: DELETE (singlr delete) ------------------
  Future<void> _deleteNotification(NotificationItem item) async {
    final uri = Uri.parse('$backendBaseUrl/api/notifications/${item.id}');

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

    final uri = Uri.parse('$backendBaseUrl/api/notifications/${item.id}/read');

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
        final uri = Uri.parse('$backendBaseUrl/api/notifications/$id');
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
        final uri = Uri.parse('$backendBaseUrl/api/notifications/$id/read');
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
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: _bgColor,
        foregroundColor: Colors.black87,
        actions: [
          if (!_selectionMode)
            TextButton(
              onPressed: _toggleSelectionMode,
              child: const Text(
                'Select',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else ...[
            TextButton(
              onPressed: _selectAll,
              child: Text(
                'Select all',
                style: TextStyle(
                  color: _selectedIds.length == _notifications.length
                      ? _accent
                      : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: _toggleSelectionMode,
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _buildBody(),
      ),

      // When press "Select" 
      bottomNavigationBar: _selectionMode
          ? Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Read 
                  TextButton.icon(
                    onPressed: _selectedIds.isEmpty ? null : _markSelectedRead,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Read'),
                    style: TextButton.styleFrom(foregroundColor: _accent),
                  ),
                  const Spacer(),
                  // Delete 
                  TextButton.icon(
                    onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _notifications.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(_errorMessage!, textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(
            child: Text(
              'No notifications yet.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _notifications[index];
        final selected = _isSelected(item);

        Widget tile = InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_selectionMode) {
              _toggleItemSelection(item);
            } else {
              _markNotificationRead(item);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: item.isRead ? Colors.white : const Color(0xFFFFFDF8),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                if (_selectionMode) ...[
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? _accent : Colors.black26,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFCBF3F0),
                      child: Icon(_metricIcon(item.metricName), color: _accent),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: item.isRead
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: item.isRead ? Colors.black54 : Colors.black87,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(item.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                ),
              ],
            ),
          ),
        );

       
        if (_selectionMode) {
          return tile;
        }
        
        return Slidable(
          key: ValueKey(item.id),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.45,
            children: [
              SlidableAction(
                onPressed: (_) => _markNotificationRead(item),
                backgroundColor: const Color(0xFFE0FFFA),
                foregroundColor: _accent,
                icon: Icons.done_all,
                label: 'Read',
              ),
              SlidableAction(
                onPressed: (_) => _deleteNotification(item),
                backgroundColor: const Color(0xFFFFE6E9),
                foregroundColor: Colors.redAccent,
                icon: Icons.delete_outline,
                label: 'Delete',
              ),
            ],
          ),
          child: tile,
        );
      },
    );
  }
}
