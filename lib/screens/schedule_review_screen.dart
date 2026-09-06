import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/period_slot.dart';
import '../models/timetable_entry.dart';
import '../services/ocr_schedule_parser_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_motion.dart';
import '../widgets/animated_entrance.dart';

class ScheduleReviewScreen extends StatefulWidget {
  final OcrScheduleResult initialResult;
  final bool importBellTimings;
  final bool importTimetable;
  final bool replaceExisting;

  const ScheduleReviewScreen({
    super.key,
    required this.initialResult,
    required this.importBellTimings,
    required this.importTimetable,
    required this.replaceExisting,
  });

  @override
  State<ScheduleReviewScreen> createState() => _ScheduleReviewScreenState();
}

class _ScheduleReviewScreenState extends State<ScheduleReviewScreen> {
  final _storage = StorageService();
  final _uuid = const Uuid();

  late List<PeriodSlot> _bellTimings;
  late List<TimetableEntry> _entries;
  String _status = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bellTimings = List<PeriodSlot>.from(widget.initialResult.bellTimings);
    _entries = List<TimetableEntry>.from(widget.initialResult.timetableEntries);
  }

  Future<void> _saveAll() async {
    setState(() {
      _saving = true;
      _status = 'Saving review changes...';
    });

    try {
      if (widget.importBellTimings) {
        final existing = widget.replaceExisting ? <PeriodSlot>[] : await _storage.loadPeriods();
        await _storage.savePeriods([...existing, ..._bellTimings]);
      }

      if (widget.importTimetable) {
        final existing = widget.replaceExisting ? <TimetableEntry>[] : await _storage.loadEntries();
        await _storage.saveEntries([...existing, ..._entries]);
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = 'Saved locally. You can edit the schedule anytime from the home screen.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = 'Save failed: $e';
      });
    }
  }

  Future<void> _editBell({PeriodSlot? existing}) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final periodCtrl = TextEditingController(text: (existing?.periodNumber ?? 0).toString());
    TimeOfDay start = existing?.start ?? const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay end = existing?.end ?? const TimeOfDay(hour: 8, minute: 35);
    String scheduleType = existing?.scheduleType ?? 'MonThu';
    bool isTeaching = existing?.isTeachingPeriod ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add bell timing' : 'Edit bell timing'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                TextField(
                  controller: periodCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Period number'),
                ),
                SwitchListTile(
                  title: const Text('Is teaching period?'),
                  value: isTeaching,
                  onChanged: (value) => setDialogState(() => isTeaching = value),
                ),
                DropdownButtonFormField<String>(
                  value: scheduleType,
                  items: const [
                    DropdownMenuItem(value: 'MonThu', child: Text('Mon-Thu')),
                    DropdownMenuItem(value: 'Fri', child: Text('Friday')),
                  ],
                  onChanged: (value) => setDialogState(() => scheduleType = value ?? 'MonThu'),
                  decoration: const InputDecoration(labelText: 'Applies to'),
                ),
                ListTile(
                  title: Text('Start: ${start.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: start);
                    if (picked != null) setDialogState(() => start = picked);
                  },
                ),
                ListTile(
                  title: Text('End: ${end.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: end);
                    if (picked != null) setDialogState(() => end = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final slot = PeriodSlot(
                  id: existing?.id ?? _uuid.v4(),
                  label: labelCtrl.text.trim().isEmpty ? 'Period' : labelCtrl.text.trim(),
                  periodNumber: int.tryParse(periodCtrl.text) ?? 0,
                  isTeachingPeriod: isTeaching,
                  start: start,
                  end: end,
                  scheduleType: scheduleType,
                );
                setState(() {
                  if (existing == null) {
                    _bellTimings.add(slot);
                  } else {
                    final index = _bellTimings.indexWhere((x) => x.id == existing.id);
                    _bellTimings[index] = slot;
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editEntry({TimetableEntry? existing}) async {
    final classCtrl = TextEditingController(text: existing?.className ?? '');
    final subjectCtrl = TextEditingController(text: existing?.subject ?? '');
    int weekday = existing?.weekday ?? DateTime.monday;
    String? periodId = existing?.periodSlotId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final relevantPeriods = _bellTimings
              .where((p) => p.scheduleType == (weekday == DateTime.friday ? 'Fri' : 'MonThu') && p.isTeachingPeriod)
              .toList()
            ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

          return AlertDialog(
            title: Text(existing == null ? 'Add timetable entry' : 'Edit timetable entry'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: weekday,
                    items: const [
                      DropdownMenuItem(value: DateTime.monday, child: Text('Monday')),
                      DropdownMenuItem(value: DateTime.tuesday, child: Text('Tuesday')),
                      DropdownMenuItem(value: DateTime.wednesday, child: Text('Wednesday')),
                      DropdownMenuItem(value: DateTime.thursday, child: Text('Thursday')),
                      DropdownMenuItem(value: DateTime.friday, child: Text('Friday')),
                    ],
                    onChanged: (value) => setDialogState(() {
                      weekday = value ?? DateTime.monday;
                      periodId = null;
                    }),
                    decoration: const InputDecoration(labelText: 'Day'),
                  ),
                  DropdownButtonFormField<String>(
                    value: relevantPeriods.any((p) => p.id == periodId) ? periodId : null,
                    items: relevantPeriods
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text('P${p.periodNumber} (${p.start.format(context)})'),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => periodId = value),
                    decoration: const InputDecoration(labelText: 'Period'),
                  ),
                  TextField(
                    controller: classCtrl,
                    decoration: const InputDecoration(labelText: 'Class'),
                  ),
                  TextField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(labelText: 'Subject (optional)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (periodId == null || classCtrl.text.trim().isEmpty) return;
                  final entry = TimetableEntry(
                    id: existing?.id ?? _uuid.v4(),
                    weekday: weekday,
                    periodSlotId: periodId!,
                    className: classCtrl.text.trim(),
                    subject: subjectCtrl.text.trim(),
                  );
                  setState(() {
                    if (existing == null) {
                      _entries.add(entry);
                    } else {
                      final index = _entries.indexWhere((x) => x.id == existing.id);
                      _entries[index] = entry;
                    }
                  });
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
    final periodsById = {for (final slot in _bellTimings) slot.id: slot};

    return Scaffold(
      appBar: AppBar(title: const Text('Review & Edit Schedule')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _saveAll,
        icon: const Icon(Icons.save),
        label: const Text('Save to Phone'),
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
              const AnimatedEntrance(
                child: _HeaderCard(
                  title: 'Review & Edit Schedule',
                  subtitle: 'Correct OCR results before saving to the phone.',
                  icon: Icons.fact_check_rounded,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.importBellTimings) ...[
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 70),
                  child: _SectionCard(
                    title: 'Bell timings',
                    trailing: TextButton.icon(
                      onPressed: _saving ? null : () => _editBell(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                    child: Column(children: _bellTimings.isEmpty ? [const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No bell timings detected.'))] : _bellTimings.map((slot) => _BellDraftTile(slot: slot, onTap: () => _editBell(existing: slot), onDelete: () => setState(() => _bellTimings.removeWhere((x) => x.id == slot.id)))).toList()),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (widget.importTimetable) ...[
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 120),
                  child: _SectionCard(
                    title: 'Timetable',
                    trailing: TextButton.icon(
                      onPressed: _saving ? null : () => _editEntry(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                    child: Column(children: _groupedEntries(periodsById)),
                  ),
                ),
              ],
              if (_saving) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_status, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _groupedEntries(Map<String, PeriodSlot> periodsById) {
    final grouped = <int, List<TimetableEntry>>{};
    for (final entry in _entries) {
      grouped.putIfAbsent(entry.weekday, () => []).add(entry);
    }

    final orderedDays = [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    ];

    final widgets = <Widget>[];
    for (final day in orderedDays) {
      final dayEntries = grouped[day];
      if (dayEntries == null || dayEntries.isEmpty) continue;

      dayEntries.sort((a, b) {
        final pa = periodsById[a.periodSlotId]?.periodNumber ?? 0;
        final pb = periodsById[b.periodSlotId]?.periodNumber ?? 0;
        return pa.compareTo(pb);
      });

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            title: Text(_weekdayName(day), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: dayAccentColor(day))),
            subtitle: Text('${dayEntries.length} lecture${dayEntries.length == 1 ? '' : 's'}', style: TextStyle(color: dayAccentColor(day).withOpacity(0.75))),
            children: dayEntries.map((entry) {
              final slot = periodsById[entry.periodSlotId];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: dayAccentColor(day).withOpacity(0.8), width: 4)),
                ),
                child: ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [dayAccentColor(day), periodAccentColor(slot?.periodNumber ?? 0)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Text('P${slot?.periodNumber ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                  ),
                  title: Text(entry.className),
                  subtitle: Text(slot == null ? 'Period not linked' : '${slot.label} • ${slot.start.format(context)} → ${slot.end.format(context)}'),
                  onTap: _saving ? null : () => _editEntry(existing: entry),
                  trailing: IconButton(
                    onPressed: _saving
                        ? null
                        : () {
                            setState(() => _entries.removeWhere((x) => x.id == entry.id));
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    return widgets;
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      default:
        return '';
    }
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _BellDraftTile extends StatelessWidget {
  final PeriodSlot slot;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BellDraftTile({required this.slot, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [dayAccentColor(slot.scheduleType == 'Fri' ? DateTime.friday : DateTime.monday), periodAccentColor(slot.periodNumber)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text('${slot.periodNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        ),
        title: Text(slot.label),
        subtitle: Text('${slot.start.format(context)} → ${slot.end.format(context)}'),
        onTap: onTap,
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
      ),
    );
  }
}