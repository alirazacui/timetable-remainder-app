import 'package:flutter/material.dart';

import '../services/schedule_service.dart';

class WeeklyScheduleScreen extends StatefulWidget {
  const WeeklyScheduleScreen({super.key});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  final _scheduleService = ScheduleService();
  bool _loading = true;
  final Map<int, List<ScheduledLecture>> _week = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = <int, List<ScheduledLecture>>{};
    final today = DateTime.now();
    final weekStart = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - DateTime.monday));

    for (int offset = 0; offset < 5; offset++) {
      final day = weekStart.add(Duration(days: offset));
      data[day.weekday] = await _scheduleService.loadScheduleForDay(day);
    }
    setState(() {
      _week
        ..clear()
        ..addAll(data);
      _loading = false;
    });
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
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _HeaderCard(
                      title: 'Weekly Schedule',
                      subtitle: 'A clean view of Monday to Friday.',
                      icon: Icons.view_week_rounded,
                    ),
                    const SizedBox(height: 16),
                    ...[
                      DateTime.monday,
                      DateTime.tuesday,
                      DateTime.wednesday,
                      DateTime.thursday,
                      DateTime.friday,
                    ].map((weekday) {
                      final lectures = _week[weekday] ?? const <ScheduledLecture>[];
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
                            child: Center(child: Text(_dayShort(weekday), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F766E)))),
                          ),
                          title: Text(_weekdayName(weekday), style: Theme.of(context).textTheme.titleMedium),
                          subtitle: Text('${lectures.length} lecture${lectures.length == 1 ? '' : 's'}'),
                          children: lectures.isEmpty
                              ? [
                                  const _EmptyWeekCard(),
                                ]
                              : lectures
                                  .map(
                                    (lecture) => Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB7185)]),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Center(child: Text('P${lecture.slot.periodNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(lecture.entry.className, style: Theme.of(context).textTheme.titleSmall),
                                                const SizedBox(height: 2),
                                                Text(_scheduleService.formatRange(lecture), style: Theme.of(context).textTheme.bodyMedium),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      );
                    }),
                  ],
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
      default:
        return '';
    }
  }

  String _dayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mo';
      case DateTime.tuesday:
        return 'Tu';
      case DateTime.wednesday:
        return 'We';
      case DateTime.thursday:
        return 'Th';
      case DateTime.friday:
        return 'Fr';
      default:
        return '--';
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

class _EmptyWeekCard extends StatelessWidget {
  const _EmptyWeekCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Text('No classes stored for this day yet.'),
    );
  }
}