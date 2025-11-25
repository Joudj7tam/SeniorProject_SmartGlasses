// notifications_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'smart_bottom_nav.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<_NotificationItem> _notifications = [
    _NotificationItem(
      id: '1',
      title: 'High brightness detected',
      message: 'Your screen brightness has been high for 20 minutes.',
      icon: Icons.wb_sunny_outlined,
    ),
    _NotificationItem(
      id: '2',
      title: 'You are too close to the screen',
      message: 'Distance dropped below 40 cm. Consider leaning back.',
      icon: Icons.monitor_heart_outlined,
    ),
    _NotificationItem(
      id: '3',
      title: 'Low blink rate',
      message: 'You blinked less than usual in the last 5 minutes.',
      icon: Icons.visibility_outlined,
    ),
  ];

  Color get _bgColor => const Color(0xFFFFF7EE);
  Color get _accent => const Color(0xFF2EC4B6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,

      // ================== AppBar ==================
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),

      // ================== BODY ==================
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemBuilder: (context, index) {
                final item = _notifications[index];

                return Slidable(
                  key: ValueKey(item.id),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    dismissible: DismissiblePane(
                      onDismissed: () {
                        setState(() {
                          _notifications.removeAt(index);
                        });
                      },
                    ),
                    children: [
                      SlidableAction(
                        onPressed: (_) {
                          setState(() {
                            item.isRead = !item.isRead;
                          });
                        },
                        backgroundColor: const Color(0xFFE0FFFA),
                        foregroundColor: const Color(0xFF2EC4B6),
                        icon: Icons.done_all,
                      ),
                      SlidableAction(
                        onPressed: (_) {
                          setState(() {
                            _notifications.removeAt(index);
                          });
                        },
                        backgroundColor: const Color(0xFFFFE6E9),
                        foregroundColor: Colors.redAccent,
                        icon: Icons.delete_outline,
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() {
                        item.isRead = !item.isRead;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: item.isRead
                            ? Colors.white
                            : const Color(0xFFFFFDF8),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFFCBF3F0),
                            child: Icon(
                              item.icon,
                              color: _accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: item.isRead
                                        ? Colors.black54
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.message,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: _notifications.length,
            ),

      // ================== FAB + FOOTER ==================
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        elevation: 4,
        backgroundColor: const Color(0xFFFFBF69),
        onPressed: () {},
        child: Icon(
          Icons.show_chart,
          color: _accent,
        ),
      ),
      bottomNavigationBar: SmartBottomNav(
        selectedIndex: 3, // Alerts هي الصفحة الحالية
        onItemTap: (index) {
          if (index == 3) return; // أنتِ بالفعل في Alerts
          // حالياً: رجوع للهوم لأي اختيار آخر
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: Color(0xFFCBF3F0),
            ),
            SizedBox(height: 16),
            Text(
              'Nothing here yet!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'When your smart glasses detect something important,\nnotifications will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationItem {
  final String id;
  final String title;
  final String message;
  final IconData icon;
  bool isRead;

  _NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    this.isRead = false,
  });
}
