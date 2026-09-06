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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F4F1), Color(0xFFF5F1EA), Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(
                title: 'My Timetable',
                subtitle: 'Edit the teaching pattern any time.',
                icon: Icons.class_rounded,
              ),
              const SizedBox(height: 16),
              ..._weekdayNames.entries.map((day) {
                final dayEntries = _entries.where((e) => e.weekday == day.key).toList()
                  ..sort((a, b) {
                    final pa = periodsById[a.periodSlotId]?.periodNumber ?? 0;
                    final pb = periodsById[b.periodSlotId]?.periodNumber ?? 0;
                    return pa.compareTo(pb);
                  });

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F2F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text(day.value.substring(0, 2), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F766E)))),
                    ),
                    title: Text(day.value, style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text('${dayEntries.length} lecture${dayEntries.length == 1 ? '' : 's'}'),
                    children: dayEntries.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(12), child: Text('No lectures stored for this day yet.'))]
                        : dayEntries.map((e) {
                            final slot = periodsById[e.periodSlotId];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB7185)]),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(child: Text('P${slot?.periodNumber ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                                ),
                                title: Text(e.className),
                                subtitle: Text(slot == null
                                    ? 'Unknown period'
                                    : '${slot.label} • ${slot.start.format(context)} to ${slot.end.format(context)}'),
                                onTap: () => _editEntry(existing: e),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    setState(() => _entries.removeWhere((x) => x.id == e.id));
                                    _saveEntries();
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HeaderCard({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF164E63)]),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.88))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
