import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/period_slot.dart';
import '../models/timetable_entry.dart';

class OcrScheduleResult {
  final List<PeriodSlot> bellTimings;
  final List<TimetableEntry> timetableEntries;
  final List<String> warnings;
  final String rawText;

  OcrScheduleResult({
    required this.bellTimings,
    required this.timetableEntries,
    required this.warnings,
    required this.rawText,
  });

  bool get hasBellTimings => bellTimings.isNotEmpty;
  bool get hasTimetable => timetableEntries.isNotEmpty;
  bool get hasAnything => hasBellTimings || hasTimetable;
}

class OcrScheduleParserService {
  static const _uuid = Uuid();

  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final RegExp _rangeRe = RegExp(
    r'(\d{1,2})[:\.](\d{2})\s*(?:AM|PM|am|pm)?\s*[-–—to]+\s*(\d{1,2})[:\.](\d{2})\s*(AM|PM|am|pm)?',
    caseSensitive: false,
  );

  final RegExp _dayRe = RegExp(
    r'\b(monday|tuesday|wednesday|thursday|friday|mon|tue|wed|thu|fri)\b',
    caseSensitive: false,
  );

  final RegExp _classCodeRe = RegExp(
    r'\b(NUR|KG|Prep|Jr\.|Sr\.|Class)\s*[-.]?\s*[IVXivx\d]*\s*[A-Za-z]?\b',
  );

  Future<OcrScheduleResult> parseImage(File file) async {
    final inputImage = InputImage.fromFilePath(file.path);
    final recognizedText = await _recognizer.processImage(inputImage);
    final rawText = recognizedText.text;
    final warnings = <String>[];

    final bellTimings = _extractBellTimings(rawText, warnings);
    final timetableEntries = _extractTimetable(rawText, bellTimings, warnings);

    if (rawText.trim().isEmpty) {
      warnings.add('No text was detected in the image.');
    }

    return OcrScheduleResult(
      bellTimings: bellTimings,
      timetableEntries: timetableEntries,
      warnings: warnings,
      rawText: rawText,
    );
  }

  void close() {
    _recognizer.close();
  }

  List<PeriodSlot> _extractBellTimings(String text, List<String> warnings) {
    final lines = text.split('\n');
    final slots = <PeriodSlot>[];
    String currentScheduleType = 'MonThu';

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (RegExp(r'\bfriday\b', caseSensitive: false).hasMatch(line) &&
          !_rangeRe.hasMatch(line)) {
        currentScheduleType = 'Fri';
      } else if (RegExp(r'\bmon(day)?\s*[-–to]+\s*thu(rsday)?\b', caseSensitive: false)
          .hasMatch(line)) {
        currentScheduleType = 'MonThu';
      }

      final rangeMatch = _rangeRe.firstMatch(line);
      if (rangeMatch == null) continue;

      final startH = int.parse(rangeMatch.group(1)!);
      final startM = int.parse(rangeMatch.group(2)!);
      final endH = int.parse(rangeMatch.group(3)!);
      final endM = int.parse(rangeMatch.group(4)!);
      final ampm = rangeMatch.group(5) ?? '';

      final startTOD = _toTimeOfDay(startH, startM, ampm);
      final endTOD = _toTimeOfDay(endH, endM, ampm);
      final label = _extractLabel(line, rangeMatch.start, rangeMatch.end);

      final isTeaching = !RegExp(
        r'\b(assembly|circle\s*time|break|recess|interval|lunch)\b',
        caseSensitive: false,
      ).hasMatch(label);

      final periodNumMatch = RegExp(r'\b(\d+)(st|nd|rd|th)', caseSensitive: false).firstMatch(label);
      final periodNum = periodNumMatch != null
          ? int.tryParse(periodNumMatch.group(1)!) ?? 0
          : (isTeaching
              ? slots.where((s) => s.scheduleType == currentScheduleType && s.isTeachingPeriod).length + 1
              : 0);

      final labelFinal = label.trim().isEmpty ? _defaultLabel(periodNum, isTeaching) : label.trim();

      final alreadyExists = slots.any((s) =>
          s.scheduleType == currentScheduleType &&
          s.start.hour == startTOD.hour &&
          s.start.minute == startTOD.minute);
      if (alreadyExists) continue;

      slots.add(PeriodSlot(
        id: _uuid.v4(),
        label: labelFinal,
        periodNumber: periodNum,
        isTeachingPeriod: isTeaching,
        start: startTOD,
        end: endTOD,
        scheduleType: currentScheduleType,
      ));
    }

    if (slots.isEmpty) {
      warnings.add('No bell timings found. The image may not contain a bell schedule or the OCR may be unclear.');
    }

    return slots;
  }

  List<TimetableEntry> _extractTimetable(String text, List<PeriodSlot> slots, List<String> warnings) {
    if (slots.isEmpty) {
      warnings.add('Timetable extraction skipped: no bell timings to map periods to.');
      return [];
    }

    final lines = text.split('\n');
    final entries = <TimetableEntry>[];

    final dayMap = <String, int>{
      'monday': DateTime.monday,
      'mon': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'tue': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'wed': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'thu': DateTime.thursday,
      'friday': DateTime.friday,
      'fri': DateTime.friday,
    };

    final monThuSlots = slots.where((s) => s.scheduleType == 'MonThu' && s.isTeachingPeriod).toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
    final friSlots = slots.where((s) => s.scheduleType == 'Fri' && s.isTeachingPeriod).toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

    int? currentWeekday;
    int periodIndex = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final dayMatch = _dayRe.firstMatch(line.toLowerCase());
      if (dayMatch != null) {
        final dayKey = dayMatch.group(0)!.toLowerCase().substring(0, 3);
        currentWeekday = dayMap[dayKey] ?? dayMap[dayMatch.group(0)!.toLowerCase()];
        periodIndex = 0;
      }

      if (currentWeekday == null) continue;

      final matches = _classCodeRe.allMatches(line).toList();
      if (matches.isEmpty) continue;

      final isFriday = currentWeekday == DateTime.friday;
      final relevantSlots = isFriday ? friSlots : monThuSlots;

      for (final match in matches) {
        if (periodIndex >= relevantSlots.length) break;
        final className = match.group(0)!.trim();
        if (className.length < 2) continue;

        final slot = relevantSlots[periodIndex];
        final isDuplicate = entries.any((e) => e.weekday == currentWeekday && e.periodSlotId == slot.id);
        if (!isDuplicate) {
          entries.add(TimetableEntry(
            id: _uuid.v4(),
            weekday: currentWeekday!,
            periodSlotId: slot.id,
            className: className,
            subject: '',
          ));
        }
        periodIndex++;
      }
    }

    if (entries.isEmpty) {
      warnings.add('No timetable entries found. The OCR text may not contain class codes in a recognisable format.');
    }

    return entries;
  }

  String _extractLabel(String line, int rangeStart, int rangeEnd) {
    final before = line.substring(0, rangeStart).trim();
    final after = line.substring(rangeEnd).trim();
    if (before.isNotEmpty) return before;
    if (after.isNotEmpty) return after;
    return '';
  }

  String _defaultLabel(int num, bool teaching) {
    if (!teaching) return 'Break';
    if (num == 0) return 'Assembly';
    final suffix = _ordinalSuffix(num);
    return '$num$suffix Period';
  }

  String _ordinalSuffix(int n) {
    if (n == 11 || n == 12 || n == 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  TimeOfDay _toTimeOfDay(int h, int m, String ampm) {
    int hour = h;
    if (ampm.toLowerCase() == 'pm' && hour < 12) hour += 12;
    if (ampm.toLowerCase() == 'am' && hour == 12) hour = 0;
    if (ampm.isEmpty && hour >= 1 && hour <= 6) {
      hour += 12;
    }
    return TimeOfDay(hour: hour.clamp(0, 23), minute: m.clamp(0, 59));
  }
}