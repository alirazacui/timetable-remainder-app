import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/period_slot.dart';
import '../models/timetable_entry.dart';
import 'storage_service.dart';

/// Schedules three kinds of reminders per lecture, for the next 7 days:
///  - a morning summary (once a day, at a time you set)
///  - "prepare" reminder 20 minutes before the lecture starts
///  - "walk to class" reminder 5 minutes before the lecture starts
///
/// Re-run scheduleAll() whenever the timetable/bell timings are edited, and
/// ideally once a week (it only ever looks 7 days ahead) — the Home screen
/// has a "Sync notifications" button for this.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _storage = StorageService();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  /// Clears everything scheduled and rebuilds the next 7 days of reminders
  /// from whatever is currently saved in storage.
  Future<int> scheduleAll() async {
    await init();
    await _plugin.cancelAll();

    final periods = await _storage.loadPeriods();
    final entries = await _storage.loadEntries();
    final morningTimeStr = await _storage.loadMorningTime();
    final morningParts = morningTimeStr.split(':');
    final morningHour = int.parse(morningParts[0]);
    final morningMinute = int.parse(morningParts[1]);

    final periodsById = {for (final p in periods) p.id: p};
    final now = tz.TZDateTime.now(tz.local);
    int scheduledCount = 0;

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = now.add(Duration(days: dayOffset));
      final weekday = date.weekday; // 1=Mon ... 7=Sun
      if (weekday > DateTime.friday) continue; // school is Mon-Fri

      final todaysEntries = entries.where((e) => e.weekday == weekday).toList()
        ..sort((a, b) {
          final pa = periodsById[a.periodSlotId]?.periodNumber ?? 0;
          final pb = periodsById[b.periodSlotId]?.periodNumber ?? 0;
          return pa.compareTo(pb);
        });

      if (todaysEntries.isEmpty) continue;

      // 1) Morning summary
      final morningTime = tz.TZDateTime(tz.local, date.year, date.month,
          date.day, morningHour, morningMinute);
      if (morningTime.isAfter(now)) {
        final summary = todaysEntries.map((e) {
          final slot = periodsById[e.periodSlotId];
          final label = slot?.label ?? 'Period';
          return '$label: ${e.className}';
        }).join(', ');
        await _zonedSchedule(
          id: _idFor(date, 'morning', 0),
          title: 'Sir, aaj ka lecture schedule',
          body: 'Aaj aapke lectures: $summary',
          time: morningTime,
        );
        scheduledCount++;
      }

      // 2) Per-lecture 20-min and 5-min reminders
      for (final entry in todaysEntries) {
        final slot = periodsById[entry.periodSlotId];
        if (slot == null || !slot.isTeachingPeriod) continue;

        final lectureStart = tz.TZDateTime(tz.local, date.year, date.month,
            date.day, slot.start.hour, slot.start.minute);

        final prep = lectureStart.subtract(const Duration(minutes: 20));
        final walk = lectureStart.subtract(const Duration(minutes: 5));

        if (prep.isAfter(now)) {
          await _zonedSchedule(
            id: _idFor(date, 'prep', entry.hashCode),
            title: 'Get ready',
            body:
                'Sir, ${slot.label} (${entry.className}) 20 minute mein shuru hoga — prepare ho jayein.',
            time: prep,
          );
          scheduledCount++;
        }
        if (walk.isAfter(now)) {
          await _zonedSchedule(
            id: _idFor(date, 'walk', entry.hashCode),
            title: 'Time to move',
            body:
                'Sir, ${slot.label} (${entry.className}) 5 minute mein shuru hoga — class ki taraf chalna shuru karein.',
            time: walk,
          );
          scheduledCount++;
        }
      }
    }
    return scheduledCount;
  }

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime time,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      time,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lecture_reminders',
          'Lecture Reminders',
          channelDescription: 'Morning summary and pre-lecture reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  /// Deterministic-ish unique id per (date, kind, extra) so re-scheduling
  /// doesn't collide, and stays within the 32-bit int range Android wants.
  int _idFor(tz.TZDateTime date, String kind, int extra) {
    final base = '${date.year}${date.month}${date.day}$kind$extra'.hashCode;
    return base & 0x7fffffff;
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
