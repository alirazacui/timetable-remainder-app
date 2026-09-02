import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/period_slot.dart';
import '../models/timetable_entry.dart';

/// Everything the app knows is stored locally on the phone (no server, no
/// hardcoding). Two lists: bell timings (PeriodSlot) and the timetable
/// (TimetableEntry), both fully editable from the UI.
class StorageService {
  static const _periodsKey = 'period_slots';
  static const _entriesKey = 'timetable_entries';
  static const _morningTimeKey = 'morning_summary_time'; // "HH:mm"

  Future<List<PeriodSlot>> loadPeriods() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_periodsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => PeriodSlot.fromJson(e)).toList();
  }

  Future<void> savePeriods(List<PeriodSlot> periods) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _periodsKey, jsonEncode(periods.map((e) => e.toJson()).toList()));
  }

  Future<List<TimetableEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => TimetableEntry.fromJson(e)).toList();
  }

  Future<void> saveEntries(List<TimetableEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _entriesKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<String> loadMorningTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_morningTimeKey) ?? '07:00';
  }

  Future<void> saveMorningTime(String hhmm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_morningTimeKey, hhmm);
  }
}
