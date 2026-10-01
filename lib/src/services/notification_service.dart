import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider((ref) => NotificationService());

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;
  bool _permissionRequested = false;
  static const _channel = AndroidNotificationChannel(
    'webp_conversion_complete',
    'WebP conversions',
    description: 'Notifications when a WebP conversion finishes',
    importance: Importance.high,
  );

  Future<void> _initialize() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('push_icon'),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  Future<void> prepare() async {
    if (!Platform.isAndroid) return;
    try {
      await (_initialization ??= _initialize());
      if (!_permissionRequested) {
        _permissionRequested = true;
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }
    } catch (error) {
      _initialization = null;
      debugPrint('Notification setup failed: $error');
    }
  }

  Future<void> showCompleted(int bytes) async {
    if (!Platform.isAndroid) return;
    try {
      await (_initialization ??= _initialize());
      await _plugin.show(
        0,
        'Conversion complete',
        'Your WebP is ready (${(bytes / 1000000).toStringAsFixed(2)} MB).',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'webp_conversion_complete',
            'WebP conversions',
            channelDescription: 'Notifications when a WebP conversion finishes',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'push_icon',
            category: AndroidNotificationCategory.status,
            autoCancel: true,
          ),
        ),
      );
    } catch (error) {
      // Notification failure must never turn a successful conversion into a failure.
      debugPrint('Completion notification failed: $error');
    }
  }
}
