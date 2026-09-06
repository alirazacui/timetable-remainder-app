import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/schedule_service.dart';
import 'pdf_import_screen.dart';
import 'bell_timings_screen.dart';
import 'timetable_screen.dart';
import 'settings_screen.dart';
import 'weekly_schedule_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _notifications = NotificationService();
  final _scheduleService = ScheduleService();
  int _periodCount = 0;
  int _entryCount = 0;
  TimeOfDay _morningTime = const TimeOfDay(hour: 7, minute: 0);
  String _status = '';
  List<ScheduledLecture> _todayLectures = [];
  ScheduledLecture? _nextLecture;
  bool _loadingSchedule = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final periods = await _storage.loadPeriods();
    final entries = await _storage.loadEntries();
    final morningStr = await _storage.loadMorningTime();
    final todayLectures = await _scheduleService.loadTodaySchedule();
    final nextLecture = await _scheduleService.loadNextLecture();
    final parts = morningStr.split(':');
    setState(() {
      _periodCount = periods.length;
      _entryCount = entries.length;
      _morningTime =
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      _todayLectures = todayLectures;
      _nextLecture = nextLecture;
      _loadingSchedule = false;
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
    final todayName = _weekdayName(DateTime.now().weekday);
    final nextClassName = _nextLecture?.entry.className ?? 'No class yet';
    final nextClassTime = _nextLecture == null ? 'Add schedule to begin' : _scheduleService.formatTime(_nextLecture!.startDateTime);
    final nextClassCountdown = _nextLecture == null ? '' : _countdownLabel(_nextLecture!.startDateTime.difference(DateTime.now()));

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
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sir Schedule', style: Theme.of(context).textTheme.titleLarge),
                          Text('Today — $todayName', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _pickMorningTime,
                      icon: const Icon(Icons.alarm_add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _HeroCard(
                  title: 'Good morning, Sir',
                  subtitle: 'Your teaching day at a glance',
                  child: _loadingSchedule
                      ? const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(),
                        ))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NEXT CLASS', style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2, color: const Color(0xFF0F766E))),
                            const SizedBox(height: 8),
                            Text(nextClassName, style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            Text(nextClassTime, style: Theme.of(context).textTheme.bodyLarge),
                            if (nextClassCountdown.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(nextClassCountdown, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFFF97316))),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _StatPill(label: 'Periods', value: '$_periodCount')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatPill(label: 'Lectures', value: '$_entryCount')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatPill(label: 'Morning', value: _morningTime.format(context))),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionTitle(title: 'Today\'s Classes', action: _todayLectures.isEmpty ? null : TextButton(onPressed: _sync, child: const Text('Reschedule'))),
                const SizedBox(height: 10),
                if (_todayLectures.isEmpty)
                  const _EmptyStateCard(
                    icon: Icons.event_busy_rounded,
                    title: 'No classes stored yet',
                    subtitle: 'Scan or enter your timetable to see today\'s schedule here.',
                  )
                else
                  ..._todayLectures.map((lecture) => _LectureCard(
                        lecture: lecture,
                        scheduleService: _scheduleService,
                      )),
                const SizedBox(height: 18),
                _SectionTitle(title: 'Quick Actions'),
                const SizedBox(height: 10),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.18,
                  ),
                  children: [
                    _ActionCard(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Scan / Import',
                      subtitle: 'OCR from camera or gallery',
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfImportScreen()));
                        _refresh();
                      },
                    ),
                    _ActionCard(
                      icon: Icons.view_week_rounded,
                      title: 'Weekly Schedule',
                      subtitle: 'Monday to Friday overview',
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyScheduleScreen()));
                        _refresh();
                      },
                    ),
                    _ActionCard(
                      icon: Icons.schedule_rounded,
                      title: 'Bell Timings',
                      subtitle: 'Edit period timings',
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const BellTimingsScreen()));
                        _refresh();
                      },
                    ),
                    _ActionCard(
                      icon: Icons.settings_rounded,
                      title: 'Settings',
                      subtitle: 'Notifications and reminders',
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        _refresh();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionTitle(title: 'Status & Sync'),
                const SizedBox(height: 10),
                _ActionStrip(
                  primaryLabel: 'Sync notifications',
                  onPrimary: _sync,
                  secondaryLabel: 'Edit timetable',
                  onSecondary: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableScreen()));
                    _refresh();
                  },
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(_status, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _countdownLabel(Duration duration) {
    if (duration.isNegative) {
      return 'In progress';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) {
      return '$minutes min remaining';
    }
    return '${hours}h ${minutes}m remaining';
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _HeroCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF164E63)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F766E).withOpacity(0.24), blurRadius: 30, offset: const Offset(0, 16)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.86))),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF667085))),
          const SizedBox(height: 6),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionTitle({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        if (action != null) action!,
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyStateCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F2F1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E)),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _LectureCard extends StatelessWidget {
  final ScheduledLecture lecture;
  final ScheduleService scheduleService;

  const _LectureCard({required this.lecture, required this.scheduleService});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB7185)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text('P${lecture.slot.periodNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lecture.entry.className, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(scheduleService.formatRange(lecture), style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F2F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF0F766E)),
              ),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionStrip extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  const _ActionStrip({required this.primaryLabel, required this.onPrimary, required this.secondaryLabel, required this.onSecondary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onPrimary,
            icon: const Icon(Icons.notifications_active_rounded),
            label: Text(primaryLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onSecondary,
            icon: const Icon(Icons.edit_rounded),
            label: Text(secondaryLabel),
          ),
        ),
      ],
    );
  }
}
