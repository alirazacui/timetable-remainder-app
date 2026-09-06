import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  final _notifications = NotificationService();

  bool _morning = true;
  bool _tenMinute = true;
  bool _fiveMinute = true;
  bool _start = true;
  bool _end = false;
  TimeOfDay _morningTime = const TimeOfDay(hour: 7, minute: 0);
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final morningTime = await _storage.loadMorningTime();
    final settings = await _storage.loadNotificationSettings();
    final parts = morningTime.split(':');
    setState(() {
      _morningTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      _morning = settings['morning'] ?? true;
      _tenMinute = settings['tenMinute'] ?? true;
      _fiveMinute = settings['fiveMinute'] ?? true;
      _start = settings['start'] ?? true;
      _end = settings['end'] ?? false;
      _loading = false;
    });
  }

  Future<void> _pickMorningTime() async {
    final picked = await showTimePicker(context: context, initialTime: _morningTime);
    if (picked != null) {
      final hhmm =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await _storage.saveMorningTime(hhmm);
      setState(() => _morningTime = picked);
    }
  }

  Future<void> _save() async {
    setState(() => _status = 'Saving settings...');
    await _storage.saveNotificationSettings(
      morning: _morning,
      tenMinute: _tenMinute,
      fiveMinute: _fiveMinute,
      start: _start,
      end: _end,
    );
    setState(() => _status = 'Settings saved. Tap reschedule to apply them.');
  }

  Future<void> _reschedule() async {
    setState(() => _status = 'Rescheduling notifications...');
    final count = await _notifications.scheduleAll();
    setState(() => _status = '$count notifications scheduled.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                title: 'Settings',
                subtitle: 'Choose how Sir Schedule behaves every day.',
                icon: Icons.settings_rounded,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Notification controls',
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Morning schedule'),
                      subtitle: const Text('Daily summary when school starts'),
                      value: _morning,
                      onChanged: (value) => setState(() => _morning = value),
                    ),
                    SwitchListTile(
                      title: const Text('10-minute warning'),
                      subtitle: const Text('Prepare before class starts'),
                      value: _tenMinute,
                      onChanged: (value) => setState(() => _tenMinute = value),
                    ),
                    SwitchListTile(
                      title: const Text('5-minute walking reminder'),
                      subtitle: const Text('Start walking toward the class'),
                      value: _fiveMinute,
                      onChanged: (value) => setState(() => _fiveMinute = value),
                    ),
                    SwitchListTile(
                      title: const Text('Class-start notification'),
                      subtitle: const Text('Exact lecture start alert'),
                      value: _start,
                      onChanged: (value) => setState(() => _start = value),
                    ),
                    SwitchListTile(
                      title: const Text('Class-end notification'),
                      subtitle: const Text('Optional end-of-lecture alert'),
                      value: _end,
                      onChanged: (value) => setState(() => _end = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Morning reminder time',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F2F1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.access_time_rounded, color: Color(0xFF0F766E)),
                  ),
                  title: Text(_morningTime.format(context), style: Theme.of(context).textTheme.titleMedium),
                  subtitle: const Text('Tap to change the daily reminder time'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _pickMorningTime,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Settings'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reschedule,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Reschedule'),
                    ),
                  ),
                ],
              ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_status, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

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
          child,
        ],
      ),
    );
  }
}