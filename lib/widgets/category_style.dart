import 'package:flutter/material.dart';

import '../theme.dart';

/// Colour and icon for each ayah category (A1–A20) and hadith theme (H1–H12).
class CategoryStyle {
  const CategoryStyle(this.hue, this.icon);

  /// Hue on the colour wheel (0–360).
  final double hue;
  final IconData icon;

  Color background(Palette p) => p.isDark
      ? HSLColor.fromAHSL(1, hue, 0.28, 0.17).toColor()
      : HSLColor.fromAHSL(1, hue, 0.55, 0.92).toColor();

  Color foreground(Palette p) => p.isDark
      ? HSLColor.fromAHSL(1, hue, 0.60, 0.72).toColor()
      : HSLColor.fromAHSL(1, hue, 0.55, 0.30).toColor();

  Color bubble(Palette p) => p.isDark
      ? HSLColor.fromAHSL(1, hue, 0.35, 0.24).toColor()
      : HSLColor.fromAHSL(1, hue, 0.60, 0.84).toColor();

  static const _styles = <String, CategoryStyle>{
    'A1': CategoryStyle(42, Icons.wb_sunny_rounded), // Hope
    'A2': CategoryStyle(200, Icons.hourglass_bottom_rounded), // Patience
    'A3': CategoryStyle(215, Icons.shield_rounded), // Trust
    'A4': CategoryStyle(345, Icons.favorite_rounded), // Peace of heart
    'A5': CategoryStyle(160, Icons.volunteer_activism_rounded), // Dua
    'A6': CategoryStyle(24, Icons.trending_up_rounded), // Effort
    'A7': CategoryStyle(188, Icons.water_drop_rounded), // Repentance
    'A8': CategoryStyle(88, Icons.local_florist_rounded), // Gratitude
    'A9': CategoryStyle(268, Icons.healing_rounded), // Comfort in grief
    'A10': CategoryStyle(230, Icons.explore_rounded), // Purpose
    'A11': CategoryStyle(250, Icons.nights_stay_rounded), // Worry & fear
    'A12': CategoryStyle(120, Icons.eco_rounded), // Provision
    'A13': CategoryStyle(32, Icons.emoji_people_rounded), // Good character
    'A14': CategoryStyle(8, Icons.family_restroom_rounded), // Parents & family
    'A15': CategoryStyle(205, Icons.menu_book_rounded), // Knowledge
    'A16': CategoryStyle(52, Icons.schedule_rounded), // Time & Hereafter
    'A17': CategoryStyle(140, Icons.park_rounded), // Hope for Jannah
    'A18': CategoryStyle(170, Icons.mosque_rounded), // Salah
    'A19': CategoryStyle(290, Icons.self_improvement_rounded), // Humility
    'A20': CategoryStyle(178, Icons.verified_rounded), // Honesty
    'H1': CategoryStyle(300, Icons.favorite_border_rounded), // Intention & heart
    'H2': CategoryStyle(42, Icons.wb_twilight_rounded), // Hope in mercy
    'H3': CategoryStyle(268, Icons.healing_rounded), // Hardship & patience
    'H4': CategoryStyle(215, Icons.shield_rounded), // Tawakkul
    'H5': CategoryStyle(188, Icons.water_drop_rounded), // Repentance
    'H6': CategoryStyle(160, Icons.volunteer_activism_rounded), // Dua
    'H7': CategoryStyle(140, Icons.all_inclusive_rounded), // Dhikr
    'H8': CategoryStyle(24, Icons.stairs_rounded), // Consistency
    'H9': CategoryStyle(88, Icons.spa_rounded), // Contentment
    'H10': CategoryStyle(32, Icons.emoji_people_rounded), // Good character
    'H11': CategoryStyle(8, Icons.diversity_3_rounded), // People & family
    'H12': CategoryStyle(230, Icons.public_rounded), // This world & the next
  };

  static CategoryStyle of(String id) =>
      _styles[id] ?? const CategoryStyle(150, Icons.auto_awesome_rounded);
}
