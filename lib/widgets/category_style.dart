import 'package:flutter/material.dart';

import '../theme.dart';

/// Line icon and soft tint for each topic (A1–A20, H1–H12) and mood (M1–M16).
class CategoryStyle {
  const CategoryStyle(this.tint, this.icon);

  /// 0 rose, 1 sand, 2 sky, 3 mint, 4 lilac.
  final int tint;
  final IconData icon;

  Tint tintOf(Palette p) => p.tints[tint];
  Color background(Palette p) => tintOf(p).background;
  Color foreground(Palette p) => tintOf(p).foreground;
  Color bubble(Palette p) => tintOf(p).background;

  static const _styles = <String, CategoryStyle>{
    'A1': CategoryStyle(1, Icons.wb_sunny_outlined), // Hope
    'A2': CategoryStyle(2, Icons.hourglass_empty_rounded), // Patience
    'A3': CategoryStyle(3, Icons.shield_outlined), // Trust
    'A4': CategoryStyle(4, Icons.favorite_border_rounded), // Peace of heart
    'A5': CategoryStyle(3, Icons.volunteer_activism_outlined), // Dua
    'A6': CategoryStyle(1, Icons.trending_up_rounded), // Effort
    'A7': CategoryStyle(2, Icons.water_drop_outlined), // Repentance
    'A8': CategoryStyle(3, Icons.local_florist_outlined), // Gratitude
    'A9': CategoryStyle(0, Icons.healing_outlined), // Comfort in grief
    'A10': CategoryStyle(2, Icons.explore_outlined), // Purpose
    'A11': CategoryStyle(4, Icons.nights_stay_outlined), // Worry & fear
    'A12': CategoryStyle(3, Icons.eco_outlined), // Provision
    'A13': CategoryStyle(1, Icons.sentiment_satisfied_outlined), // Good character
    'A14': CategoryStyle(0, Icons.family_restroom_outlined), // Parents & family
    'A15': CategoryStyle(2, Icons.menu_book_outlined), // Knowledge
    'A16': CategoryStyle(1, Icons.schedule_outlined), // Time & Hereafter
    'A17': CategoryStyle(3, Icons.park_outlined), // Hope for Jannah
    'A18': CategoryStyle(3, Icons.mosque_outlined), // Salah
    'A19': CategoryStyle(4, Icons.self_improvement_outlined), // Humility
    'A20': CategoryStyle(2, Icons.verified_outlined), // Honesty
    'H1': CategoryStyle(4, Icons.favorite_outline_rounded), // Intention & heart
    'H2': CategoryStyle(1, Icons.wb_twilight_outlined),
    'H3': CategoryStyle(0, Icons.healing_outlined),
    'H4': CategoryStyle(3, Icons.shield_outlined),
    'H5': CategoryStyle(2, Icons.water_drop_outlined),
    'H6': CategoryStyle(3, Icons.volunteer_activism_outlined),
    'H7': CategoryStyle(3, Icons.all_inclusive_rounded),
    'H8': CategoryStyle(1, Icons.stairs_outlined),
    'H9': CategoryStyle(3, Icons.spa_outlined),
    'H10': CategoryStyle(1, Icons.sentiment_satisfied_outlined),
    'H11': CategoryStyle(0, Icons.diversity_3_outlined),
    'H12': CategoryStyle(2, Icons.public_outlined),
    // Moods
    'M1': CategoryStyle(2, Icons.cloud_outlined), // Sad
    'M2': CategoryStyle(1, Icons.wb_sunny_outlined), // Happy / grateful
    'M3': CategoryStyle(0, Icons.healing_outlined), // Sick
    'M4': CategoryStyle(4, Icons.person_outline_rounded), // Lonely
    'M5': CategoryStyle(1, Icons.battery_2_bar_rounded), // Demotivated
    'M6': CategoryStyle(2, Icons.air_rounded), // Anxious / afraid
    'M7': CategoryStyle(0, Icons.local_fire_department_outlined), // Angry
    'M8': CategoryStyle(4, Icons.water_drop_outlined), // Guilty
    'M9': CategoryStyle(0, Icons.heart_broken_outlined), // Hurt by someone
    'M10': CategoryStyle(4, Icons.spa_outlined), // Loss of a loved one
    'M11': CategoryStyle(3, Icons.account_balance_wallet_outlined), // Money worries
    'M12': CategoryStyle(2, Icons.school_outlined), // Exams, job, future
    'M13': CategoryStyle(3, Icons.volunteer_activism_outlined), // Dua unanswered
    'M14': CategoryStyle(1, Icons.local_florist_outlined), // Weak iman
    'M15': CategoryStyle(4, Icons.self_improvement_outlined), // Feeling worthless
    'M16': CategoryStyle(2, Icons.bedtime_outlined), // Before sleep
  };

  static CategoryStyle of(String id) =>
      _styles[id] ?? const CategoryStyle(3, Icons.auto_awesome_outlined);
}
