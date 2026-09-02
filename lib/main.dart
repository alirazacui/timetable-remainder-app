import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LectureReminderApp());
}

class LectureReminderApp extends StatelessWidget {
  const LectureReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lecture Reminders',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
