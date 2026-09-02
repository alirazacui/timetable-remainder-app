import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import '../models/period_slot.dart';
import '../models/timetable_entry.dart';

/// Result returned after parsing a PDF.
class PdfParseResult {
  final List<PeriodSlot> bellTimings;
  final List<TimetableEntry> timetableEntries;
  final List<String> warnings;
  final String rawText; // for debugging / preview

  PdfParseResult({
    required this.bellTimings,
    required this.timetableEntries,
    required this.warnings,
    required this.rawText,
  });

  bool get hasBellTimings => bellTimings.isNotEmpty;
  bool get hasTimetable => timetableEntries.isNotEmpty;
  bool get hasAnything => hasBellTimings || hasTimetable;
}

/// Parses school timetable / bell-timing PDFs.
///
/// Strategy:
///  1. Extract all text from every page using Syncfusion.
///  2. Try to detect "bell timing" blocks:  patterns like  "09:35 - 10:10"
///     on lines that also contain period labels ("1st Period", "Break", etc.)
///  3. Try to detect timetable rows: lines containing a day name followed by
///     class codes like "NUR-N", "Jr. I A", "KG-S", etc.
class PdfParserService {
  static const _uuid = Uuid();

  // ── regex helpers ──────────────────────────────────────────────────────────

  // Matches times in the document, e.g. "08:00", "9:35", "10:10 AM"
  static final _timeRe = RegExp(
    r'\b(\d{1,2})[:\.](\d{2})\s*(AM|PM|am|pm)?\b',
  );

  // Captures a time-range like  "08:00 - 08:35" or "8:00–8:35"
  static final _rangeRe = RegExp(
    r'(\d{1,2})[:\.](\d{2})\s*(?:AM|PM|am|pm)?\s*[-–—to]+\s*(\d{1,2})[:\.](\d{2})\s*(AM|PM|am|pm)?',
    caseSensitive: false,
  );

  // Day names used in timetable grids
  static final _dayRe = RegExp(
    r'\b(monday|tuesday|wednesday|thursday|friday|mon|tue|wed|thu|fri)\b',
    caseSensitive: false,
  );

  // Common period label words
  static final _periodLabelRe = RegExp(
    r'\b(assembly|circle\s*time|break|recess|interval|lunch|'
    r'(\d+)(st|nd|rd|th)\s*period|period\s*\d+)\b',
    caseSensitive: false,
  );

  // Class codes  e.g. "NUR-N", "Jr. I C", "Sr. II A", "KG-S", "Prep-A"
  static final _classCodeRe = RegExp(
    r'\b(NUR|KG|Prep|Jr\.|Sr\.|Class)\s*[-.]?\s*[IVXivx\d]*\s*[A-Za-z]?\b',
  );

  // ── public API ─────────────────────────────────────────────────────────────

  Future<PdfParseResult> parseFile(File file) async {
    final bytes = await file.readAsBytes();
    return parseBytes(bytes);
  }

  Future<PdfParseResult> parseBytes(List<int> bytes) async {
    final warnings = <String>[];
    String rawText = '';

    try {
      final doc = PdfDocument(inputBytes: bytes);
      final buffer = StringBuffer();

      for (int i = 0; i < doc.pages.count; i++) {
        final extractor = PdfTextExtractor(doc);
        final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        buffer.writeln('--- PAGE ${i + 1} ---');
        buffer.writeln(pageText);
      }

      doc.dispose();
      rawText = buffer.toString();
    } catch (e) {
      warnings.add('Could not read PDF: $e');
      return PdfParseResult(
        bellTimings: [],
        timetableEntries: [],
        warnings: warnings,
        rawText: rawText,
      );
    }

    final bellTimings = _extractBellTimings(rawText, warnings);
    final timetableEntries = _extractTimetable(rawText, bellTimings, warnings);

    return PdfParseResult(
      bellTimings: bellTimings,
      timetableEntries: timetableEntries,
      warnings: warnings,
      rawText: rawText,
    );
  }

  // ── Bell-timing extraction ─────────────────────────────────────────────────

  List<PeriodSlot> _extractBellTimings(String text, List<String> warnings) {
    final lines = text.split('\n');
    final slots = <PeriodSlot>[];
    String currentScheduleType = 'MonThu';

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Detect schedule-type header (Friday section)
      if (RegExp(r'\bfriday\b', caseSensitive: false).hasMatch(line) &&
          !_rangeRe.hasMatch(line)) {
        currentScheduleType = 'Fri';
      } else if (RegExp(r'\bmon(day)?\s*[-–to]+\s*thu(rsday)?\b',
              caseSensitive: false)
          .hasMatch(line)) {
        currentScheduleType = 'MonThu';
      }

      // Must have a time range to be a bell-timing line
      final rangeMatch = _rangeRe.firstMatch(line);
      if (rangeMatch == null) continue;

      final startH = int.parse(rangeMatch.group(1)!);
      final startM = int.parse(rangeMatch.group(2)!);
      int endH = int.parse(rangeMatch.group(3)!);
      int endM = int.parse(rangeMatch.group(4)!);
      final ampm = rangeMatch.group(5) ?? rangeMatch.group(5) ?? '';

      // Basic AM/PM correction
      final startTOD = _toTimeOfDay(startH, startM, ampm);
      final endTOD = _toTimeOfDay(endH, endM, ampm);

      // Extract label from the line (everything except the time range)
      final label = _extractLabel(line, rangeMatch.start, rangeMatch.end);

      // Determine if it's a teaching period
      final isTeaching = !RegExp(
              r'\b(assembly|circle\s*time|break|recess|interval|lunch)\b',
              caseSensitive: false)
          .hasMatch(label);

      // Period number
      final periodNumMatch =
          RegExp(r'\b(\d+)(st|nd|rd|th)', caseSensitive: false).firstMatch(label);
      final periodNum = periodNumMatch != null
          ? int.tryParse(periodNumMatch.group(1)!) ?? 0
          : (isTeaching ? slots.where((s) => s.scheduleType == currentScheduleType && s.isTeachingPeriod).length + 1 : 0);

      final labelFinal =
          label.trim().isEmpty ? _defaultLabel(periodNum, isTeaching) : label.trim();

      // Avoid exact duplicates
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
      warnings.add(
          'No bell timings found. The PDF may use an unsupported format.');
    }

    return slots;
  }

  String _extractLabel(String line, int rangeStart, int rangeEnd) {
    // Take the part of the line before the time range (usually the label)
    final before = line.substring(0, rangeStart).trim();
    final after = line.substring(rangeEnd).trim();
    // Prefer "before" text; fall back to "after"
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
    // Heuristic: school usually starts 7-9 AM and ends by 3 PM
    // If hours are 1-6 with no explicit AM/PM, assume they are PM (1 PM to 6 PM)
    // Else if 7-12, assume AM
    if (ampm.isEmpty) {
      if (hour >= 1 && hour <= 6) hour += 12; // afternoon hours
    }
    return TimeOfDay(hour: hour.clamp(0, 23), minute: m.clamp(0, 59));
  }

  // ── Timetable extraction ───────────────────────────────────────────────────

  /// Tries to extract a grid timetable.  Works for layouts like:
  ///
  ///   Monday    | NUR-N  | KG-S   | Jr. I C  | ...
  ///   Tuesday   | KG-N   | Sr. IIA| ...
  ///
  /// or paragraph styles where the day appears on one line and the classes follow.
  List<TimetableEntry> _extractTimetable(
      String text, List<PeriodSlot> slots, List<String> warnings) {
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

    // Build teaching slots per schedule type, sorted by period number
    final monThuSlots = slots
        .where((s) => s.scheduleType == 'MonThu' && s.isTeachingPeriod)
        .toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
    final friSlots = slots
        .where((s) => s.scheduleType == 'Fri' && s.isTeachingPeriod)
        .toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

    int? currentWeekday;
    int periodIndex = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Check if this line starts a new day
      final dayMatch = _dayRe.firstMatch(line.toLowerCase());
      if (dayMatch != null) {
        final dayKey = dayMatch.group(0)!.toLowerCase().substring(0, 3);
        currentWeekday = dayMap[dayKey] ??
            dayMap[dayMatch.group(0)!.toLowerCase()];
        periodIndex = 0;
      }

      if (currentWeekday == null) continue;

      // Scan the line for class codes
      final matches = _classCodeRe.allMatches(line).toList();
      if (matches.isEmpty) continue;

      final isFriday = currentWeekday == DateTime.friday;
      final relevantSlots = isFriday ? friSlots : monThuSlots;

      for (final match in matches) {
        if (periodIndex >= relevantSlots.length) break;

        final className = match.group(0)!.trim();
        // Skip very short matches that are likely noise
        if (className.length < 2) {
          continue;
        }

        final slot = relevantSlots[periodIndex];

        // Avoid duplicate entries for same weekday+slot
        final isDuplicate = entries.any((e) =>
            e.weekday == currentWeekday && e.periodSlotId == slot.id);
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
      warnings.add(
          'No timetable entries found. The PDF may not contain class codes '
          'in a recognisable format (e.g. "NUR-N", "Jr. I C", "KG-S").');
    }

    return entries;
  }
}
