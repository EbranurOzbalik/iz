import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'journal.dart';

abstract interface class ReminderService {
  Future<bool> schedule(JournalEntry entry);
  Future<void> cancel(String entryId);
}

class LocalReminderService implements ReminderService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: IOSInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  int _id(String value) => value.hashCode & 0x7fffffff;

  Future<bool> _permission() async {
    if (!_ready) return false;
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          true;
    }
    return false;
  }

  @override
  Future<bool> schedule(JournalEntry entry) async {
    final when = entry.reminderAt;
    if (when == null || when.isBefore(DateTime.now())) {
      return false;
    }
    try {
      if (!await _permission()) return false;
      await cancel(entry.id);
      await _plugin.zonedSchedule(
        id: _id(entry.id),
        title: '${entry.type.label} hatırlatıcın',
        body: entry.title,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'iz_reminders',
            'İZ hatırlatıcıları',
            channelDescription: 'Kitap, film, dizi ve tiyatro hatırlatıcıları',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: entry.id,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> cancel(String entryId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id(entryId));
    } catch (_) {
      // A reminder failure must never block journal editing or deletion.
    }
  }
}
