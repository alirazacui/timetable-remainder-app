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
                title: 'Bell Timings',
                subtitle: 'Separate timing sets for Mon-Thu and Friday.',
                icon: Icons.schedule_rounded,
              ),
              const SizedBox(height: 16),
              _SectionCard(title: 'Monday - Thursday', children: monThu.map(_tile).toList()),
              const SizedBox(height: 12),
              _SectionCard(title: 'Friday', children: fri.map(_tile).toList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(PeriodSlot p) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB7185)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text('${p.periodNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          ),
          title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${p.start.format(context)} - ${p.end.format(context)}${p.isTeachingPeriod ? '' : ' • non-teaching'}'),
          onTap: () => _editSlot(existing: p),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() => _periods.removeWhere((x) => x.id == p.id));
              _save();
            },
          ),
        ),
      );
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
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

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
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (children.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No timings stored yet.'),
            )
          else
            ...children,
        ],
      ),
    );
  }
}
