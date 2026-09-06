import 'package:flutter/material.dart';

PageRoute<T> buildPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final slide = Tween<Offset>(begin: const Offset(0.06, 0.02), end: Offset.zero).animate(fade);

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
  );
}

Color dayAccentColor(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return const Color(0xFF0F766E);
    case DateTime.tuesday:
      return const Color(0xFF2563EB);
    case DateTime.wednesday:
      return const Color(0xFF7C3AED);
    case DateTime.thursday:
      return const Color(0xFFF97316);
    case DateTime.friday:
      return const Color(0xFFDB2777);
    default:
      return const Color(0xFF64748B);
  }
}

Color periodAccentColor(int periodNumber) {
  const palette = [
    Color(0xFF0F766E),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFF97316),
    Color(0xFFDB2777),
    Color(0xFF059669),
    Color(0xFFE11D48),
    Color(0xFF0EA5E9),
  ];

  if (periodNumber <= 0) {
    return const Color(0xFF64748B);
  }
  return palette[(periodNumber - 1) % palette.length];
}
