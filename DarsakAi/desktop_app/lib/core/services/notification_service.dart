import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A glassmorphism notification that slides up and fades out.
class GlassNotification {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final DateTime createdAt;

  GlassNotification({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
  }) : createdAt = DateTime.now();
}

/// Manages glass notifications for QR attendance and other events.
class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final List<GlassNotification> _notifications = [];
  final List<Timer> _timers = [];

  List<GlassNotification> get notifications => List.unmodifiable(_notifications);

  void show({
    required String title,
    String? subtitle,
    IconData icon = Icons.check_circle,
    Color color = AppTheme.success,
  }) {
    final n = GlassNotification(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
    );
    _notifications.insert(0, n);
    // Keep max 4 visible
    if (_notifications.length > 4) {
      _notifications.removeLast();
    }
    notifyListeners();

    // Auto-remove after 3.5 seconds
    final timer = Timer(const Duration(milliseconds: 3500), () {
      _remove(n);
    });
    _timers.add(timer);
  }

  void _remove(GlassNotification n) {
    final idx = _notifications.indexOf(n);
    if (idx != -1) {
      _notifications.removeAt(idx);
      notifyListeners();
    }
  }

  void clear() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _notifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
