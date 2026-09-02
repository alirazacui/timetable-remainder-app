import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'bell_timings_screen.dart';
import 'timetable_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _notifications = NotificationService();
  int _periodCount = 0;
  int _entryCount = 0;
  TimeOfDay _morningTime = const TimeOfDay(hour: 7, minute: 0);
  String _status = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final periods = await _storage.loadPeriods();
    final entries = await _storage.loadEntries();
    final morningStr = await _storage.loadMorningTime();
    final parts = morningStr.split(':');
    setState(() {
      _periodCount = periods.length;
      _entryCount = entries.length;
      _morningTime =
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    });
  }

  Future<void> _pickMorningTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _morningTime);
    if (picked != null) {
      final hhmm =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await _storage.saveMorningTime(hhmm);
      setState(() => _morningTime = picked);
    }
  }

  Future<void> _sync() async {
    setState(() => _status = 'Scheduling...');
    final count = await _notifications.scheduleAll();
    setState(() => _status = '$count notifications scheduled for next 7 days.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lecture Reminders')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Bell Timings'),
              subtitle: Text('$_periodCount periods configured'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BellTimingsScreen()));
                _refresh();
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.class_),
              title: const Text('My Timetable'),
              subtitle: Text('$_entryCount lectures configured'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TimetableScreen()));
                _refresh();
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.alarm),
              title: const Text('Morning summary time'),
              subtitle: Text(_morningTime.format(context)),
              trailing: const Icon(Icons.edit),
              onTap: _pickMorningTime,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _sync,
            icon: const Icon(Icons.sync),
            label: const Text('Sync notifications'),
          ),
          const SizedBox(height: 8),
          Text(_status, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          const Text(
            'Tip: run "Sync notifications" again whenever you edit the '
            'timetable or bell timings, and at least once a week (it only '
            'schedules 7 days ahead).',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
