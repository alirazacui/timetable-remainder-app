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
  static const _morningEnabledKey = 'morning_summary_enabled';
  static const _tenMinuteEnabledKey = 'ten_minute_enabled';
  static const _fiveMinuteEnabledKey = 'five_minute_enabled';
  static const _startEnabledKey = 'class_start_enabled';
  static const _endEnabledKey = 'class_end_enabled';

  Future<Map<String, bool>> loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'morning': prefs.getBool(_morningEnabledKey) ?? true,
      'tenMinute': prefs.getBool(_tenMinuteEnabledKey) ?? true,
      'fiveMinute': prefs.getBool(_fiveMinuteEnabledKey) ?? true,
      'start': prefs.getBool(_startEnabledKey) ?? true,
      'end': prefs.getBool(_endEnabledKey) ?? false,
    };
  }

  Future<void> saveNotificationSettings({
    required bool morning,
    required bool tenMinute,
    required bool fiveMinute,
    required bool start,
    required bool end,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_morningEnabledKey, morning);
    await prefs.setBool(_tenMinuteEnabledKey, tenMinute);
    await prefs.setBool(_fiveMinuteEnabledKey, fiveMinute);
    await prefs.setBool(_startEnabledKey, start);
    await prefs.setBool(_endEnabledKey, end);
  }

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
