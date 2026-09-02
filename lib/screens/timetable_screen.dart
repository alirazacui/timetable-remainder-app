import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/period_slot.dart';
import '../models/timetable_entry.dart';
import '../services/storage_service.dart';

const _weekdayNames = {
  DateTime.monday: 'Monday',
  DateTime.tuesday: 'Tuesday',
  DateTime.wednesday: 'Wednesday',
  DateTime.thursday: 'Thursday',
  DateTime.friday: 'Friday',
};

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _storage = StorageService();
  final _uuid = const Uuid();
  List<TimetableEntry> _entries = [];
  List<PeriodSlot> _periods = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await _storage.loadEntries();
    final p = await _storage.loadPeriods();
    setState(() {
      _entries = e;
      _periods = p;
    });
  }

  Future<void> _saveEntries() async => _storage.saveEntries(_entries);

  Future<void> _editEntry({TimetableEntry? existing}) async {
    if (_periods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pehle Bell Timings screen se periods add karein.')));
      return;
    }
    int weekday = existing?.weekday ?? DateTime.monday;
    String? periodSlotId = existing?.periodSlotId ??
        _periods
            .firstWhere((p) => p.isTeachingPeriod, orElse: () => _periods.first)
            .id;
    final classCtrl = TextEditingController(text: existing?.className ?? '');
    final subjectCtrl = TextEditingController(text: existing?.subject ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final scheduleType = weekday == DateTime.friday ? 'Fri' : 'MonThu';
          final relevantPeriods = _periods
              .where((p) =>
                  p.scheduleType == scheduleType && p.isTeachingPeriod)
              .toList()
            ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

          return AlertDialog(
            title: Text(existing == null ? 'Add lecture' : 'Edit lecture'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: weekday,
                    items: _weekdayNames.entries
                        .map((e) =>
                            DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setDialogState(() {
                      weekday = v ?? DateTime.monday;
                      periodSlotId = null;
                    }),
                    decoration: const InputDecoration(labelText: 'Day'),
                  ),
                  DropdownButtonFormField<String>(
                    value: relevantPeriods.any((p) => p.id == periodSlotId)
                        ? periodSlotId
                        : null,
                    items: relevantPeriods
                        .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                                '${p.label} (${p.start.format(context)})')))
                        .toList(),
                    onChanged: (v) => setDialogState(() => periodSlotId = v),
                    decoration: const InputDecoration(labelText: 'Period'),
                  ),
                  TextField(
                    controller: classCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Class (e.g. Jr. I C, KG-N)'),
                  ),
                  TextField(
                    controller: subjectCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Subject (optional)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (periodSlotId == null || classCtrl.text.trim().isEmpty) {
                    return;
                  }
                  final entry = TimetableEntry(
                    id: existing?.id ?? _uuid.v4(),
                    weekday: weekday,
                    periodSlotId: periodSlotId!,
                    className: classCtrl.text.trim(),
                    subject: subjectCtrl.text.trim(),
                  );
                  setState(() {
                    if (existing == null) {
                      _entries.add(entry);
                    } else {
                      final idx =
                          _entries.indexWhere((x) => x.id == existing.id);
                      _entries[idx] = entry;
                    }
                  });
                  _saveEntries();
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periodsById = {for (final p in _periods) p.id: p};

    return Scaffold(
      appBar: AppBar(title: const Text('My Timetable')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editEntry(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: _weekdayNames.entries.map((day) {
          final dayEntries = _entries.where((e) => e.weekday == day.key).toList()
            ..sort((a, b) {
              final pa = periodsById[a.periodSlotId]?.periodNumber ?? 0;
              final pb = periodsById[b.periodSlotId]?.periodNumber ?? 0;
              return pa.compareTo(pb);
            });
          return ExpansionTile(
            title: Text(day.value),
            children: dayEntries.map((e) {
              final slot = periodsById[e.periodSlotId];
              return ListTile(
                title: Text('${e.className} ${e.subject.isNotEmpty ? "(${e.subject})" : ""}'),
                subtitle: Text(slot == null
                    ? 'Unknown period'
                    : '${slot.label} — ${slot.start.format(context)} to ${slot.end.format(context)}'),
                onTap: () => _editEntry(existing: e),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() => _entries.removeWhere((x) => x.id == e.id));
                    _saveEntries();
                  },
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
