import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/period_slot.dart';
import '../services/storage_service.dart';

class BellTimingsScreen extends StatefulWidget {
  const BellTimingsScreen({super.key});
  @override
  State<BellTimingsScreen> createState() => _BellTimingsScreenState();
}

class _BellTimingsScreenState extends State<BellTimingsScreen> {
  final _storage = StorageService();
  List<PeriodSlot> _periods = [];
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _storage.loadPeriods();
    setState(() => _periods = p);
  }

  Future<void> _save() async {
    await _storage.savePeriods(_periods);
  }

  Future<void> _editSlot({PeriodSlot? existing}) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final periodNumCtrl =
        TextEditingController(text: existing?.periodNumber.toString() ?? '0');
    TimeOfDay start = existing?.start ?? const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay end = existing?.end ?? const TimeOfDay(hour: 8, minute: 35);
    String scheduleType = existing?.scheduleType ?? 'MonThu';
    bool isTeaching = existing?.isTeachingPeriod ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add period' : 'Edit period'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Label (e.g. 3rd Period)'),
                ),
                TextField(
                  controller: periodNumCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Period number (0 for Assembly/Break)'),
                ),
                SwitchListTile(
                  title: const Text('Is a teaching period?'),
                  value: isTeaching,
                  onChanged: (v) => setDialogState(() => isTeaching = v),
                ),
                DropdownButtonFormField<String>(
                  value: scheduleType,
                  items: const [
                    DropdownMenuItem(value: 'MonThu', child: Text('Mon-Thu')),
                    DropdownMenuItem(value: 'Fri', child: Text('Friday')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => scheduleType = v ?? 'MonThu'),
                  decoration: const InputDecoration(labelText: 'Applies to'),
                ),
                ListTile(
                  title: Text('Start: ${start.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked =
                        await showTimePicker(context: context, initialTime: start);
                    if (picked != null) setDialogState(() => start = picked);
                  },
                ),
                ListTile(
                  title: Text('End: ${end.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked =
                        await showTimePicker(context: context, initialTime: end);
                    if (picked != null) setDialogState(() => end = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final slot = PeriodSlot(
                  id: existing?.id ?? _uuid.v4(),
                  label: labelCtrl.text.trim().isEmpty
                      ? 'Period'
                      : labelCtrl.text.trim(),
                  periodNumber: int.tryParse(periodNumCtrl.text) ?? 0,
                  isTeachingPeriod: isTeaching,
                  start: start,
                  end: end,
                  scheduleType: scheduleType,
                );
                setState(() {
                  if (existing == null) {
                    _periods.add(slot);
                  } else {
                    final idx = _periods.indexWhere((p) => p.id == existing.id);
                    _periods[idx] = slot;
                  }
                });
                _save();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monThu = _periods.where((p) => p.scheduleType == 'MonThu').toList()
      ..sort((a, b) => a.start.hour * 60 + a.start.minute -
          (b.start.hour * 60 + b.start.minute));
    final fri = _periods.where((p) => p.scheduleType == 'Fri').toList()
      ..sort((a, b) => a.start.hour * 60 + a.start.minute -
          (b.start.hour * 60 + b.start.minute));

    return Scaffold(
      appBar: AppBar(title: const Text('Bell Timings')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editSlot(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          _sectionHeader('Monday - Thursday'),
          ...monThu.map(_tile),
          _sectionHeader('Friday'),
          ...fri.map(_tile),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Widget _tile(PeriodSlot p) => ListTile(
        title: Text('${p.label} ${p.isTeachingPeriod ? "" : "(non-teaching)"}'),
        subtitle: Text('${p.start.format(context)} - ${p.end.format(context)}'),
        onTap: () => _editSlot(existing: p),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () {
            setState(() => _periods.removeWhere((x) => x.id == p.id));
            _save();
          },
        ),
      );
}
