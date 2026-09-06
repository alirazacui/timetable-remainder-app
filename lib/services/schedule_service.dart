import 'package:intl/intl.dart';

import '../models/period_slot.dart';
import '../models/timetable_entry.dart';
import 'storage_service.dart';

class ScheduledLecture {
  final DateTime date;
  final TimetableEntry entry;
  final PeriodSlot slot;

  ScheduledLecture({
    required this.date,
    required this.entry,
    required this.slot,
  });

  DateTime get startDateTime => DateTime(
        date.year,
        date.month,
        date.day,
        slot.start.hour,
        slot.start.minute,
      );

  DateTime get endDateTime => DateTime(
        date.year,
        date.month,
        date.day,
        slot.end.hour,
        slot.end.minute,
      );
}

class ScheduleService {
  final StorageService _storage = StorageService();

  Future<List<ScheduledLecture>> loadTodaySchedule() async {
    final today = DateTime.now();
    return loadScheduleForDay(today);
  }

  Future<List<ScheduledLecture>> loadScheduleForDay(DateTime day) async {
    final periods = await _storage.loadPeriods();
    final entries = await _storage.loadEntries();

    final scheduleType = day.weekday == DateTime.friday ? 'Fri' : 'MonThu';
    final periodsById = {for (final period in periods) period.id: period};

    final dayEntries = entries.where((entry) => entry.weekday == day.weekday).toList()
      ..sort((a, b) {
        final pa = periodsById[a.periodSlotId]?.periodNumber ?? 0;
        final pb = periodsById[b.periodSlotId]?.periodNumber ?? 0;
        return pa.compareTo(pb);
      });

    return dayEntries
        .map((entry) {
          final slot = periodsById[entry.periodSlotId];
          if (slot == null || slot.scheduleType != scheduleType) {
            return null;
          }
          return ScheduledLecture(date: day, entry: entry, slot: slot);
        })
        .whereType<ScheduledLecture>()
        .toList();
  }

  Future<ScheduledLecture?> loadNextLecture() async {
    final now = DateTime.now();

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final day = DateTime(now.year, now.month, now.day)
          .add(Duration(days: dayOffset));
      final lectures = await loadScheduleForDay(day);
      for (final lecture in lectures) {
        if (lecture.endDateTime.isAfter(now)) {
          return lecture;
        }
      }
    }

    return null;
  }

  String formatRange(ScheduledLecture lecture) {
    final formatter = DateFormat('hh:mm a');
    return '${formatter.format(lecture.startDateTime)} - ${formatter.format(lecture.endDateTime)}';
  }

  String formatTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }
}