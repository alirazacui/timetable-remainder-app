import 'package:flutter/material.dart';

/// One row of the "bell timings" sheet, e.g. "3rd Period" 9:35-10:10.
/// [scheduleType] lets you keep a separate Mon-Thu table and a Friday table,
/// exactly like the school's bell timing sheet has two tables.
class PeriodSlot {
  String id; // stable id so timetable entries can reference it
  String label; // "1st Period", "Break", "Assembly Time" etc.
  int periodNumber; // 0 for non-teaching slots (assembly/break), else 1,2,3...
  bool isTeachingPeriod; // false for assembly/circle time/break
  TimeOfDay start;
  TimeOfDay end;
  String scheduleType; // "MonThu" or "Fri" (extend if your school adds more)

  PeriodSlot({
    required this.id,
    required this.label,
    required this.periodNumber,
    required this.isTeachingPeriod,
    required this.start,
    required this.end,
    required this.scheduleType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'periodNumber': periodNumber,
        'isTeachingPeriod': isTeachingPeriod,
        'startH': start.hour,
        'startM': start.minute,
        'endH': end.hour,
        'endM': end.minute,
        'scheduleType': scheduleType,
      };

  factory PeriodSlot.fromJson(Map<String, dynamic> json) => PeriodSlot(
        id: json['id'],
        label: json['label'],
        periodNumber: json['periodNumber'],
        isTeachingPeriod: json['isTeachingPeriod'],
        start: TimeOfDay(hour: json['startH'], minute: json['startM']),
        end: TimeOfDay(hour: json['endH'], minute: json['endM']),
        scheduleType: json['scheduleType'],
      );
}
