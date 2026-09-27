import 'package:flutter/material.dart';

const banglaFont = 'NotoSansBengali';
const headingFont = 'HindSiliguri';
const arabicFont = 'AmiriQuran';

/// Noto Sans Bengali has no Latin punctuation or Arabic letters, so fall back
/// to Hind Siliguri (Bangla + Latin) and then Amiri Quran (Arabic).
const fontFallback = [headingFont, arabicFont];

/// Brand colours that do not change with light/dark mode.
class Brand {
  static const emerald = Color(0xFF0F5C3E);
  static const deepEmerald = Color(0xFF0A3D2A);
  static const night = Color(0xFF06231A);
  static const gold = Color(0xFFC9A24B);
  static const lightGold = Color(0xFFE9D39A);
  static const cream = Color(0xFFFBF6E9);
}

/// Colours that change between light and dark mode.
/// Use it with `context.palette`.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.border,
    required this.text,
    required this.muted,
    required this.primary,
    required this.accent,
    required this.arabic,
    required this.heroStart,
    required this.heroEnd,
    required this.readingTop,
    required this.readingBottom,
    required this.pattern,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color border;
  final Color text;
  final Color muted;
  final Color primary;
  final Color accent;
  final Color arabic;
  final Color heroStart;
  final Color heroEnd;
  final Color readingTop;
  final Color readingBottom;
  final Color pattern;
  final bool isDark;

  static const light = Palette(
    background: Color(0xFFF6F7F2),
    surface: Colors.white,
    surfaceSoft: Color(0xFFEFF5EF),
    border: Color(0xFFE2EAE3),
    text: Color(0xFF1B2A22),
    muted: Color(0xFF66766D),
    primary: Brand.emerald,
    accent: Color(0xFFB08A35),
    arabic: Color(0xFF0A3D2A),
    heroStart: Color(0xFF0F5C3E),
    heroEnd: Color(0xFF1E7A55),
    readingTop: Color(0xFFFBF7EC),
    readingBottom: Color(0xFFEAF3EC),
    pattern: Color(0xFF0F5C3E),
    isDark: false,
  );

  static const dark = Palette(
    background: Color(0xFF09130F),
    surface: Color(0xFF111F18),
    surfaceSoft: Color(0xFF172920),
    border: Color(0xFF223529),
    text: Color(0xFFE7EFEA),
    muted: Color(0xFF9BAFA4),
    primary: Color(0xFF4CC195),
    accent: Color(0xFFDDBD6C),
    arabic: Color(0xFFF3E7C6),
    heroStart: Color(0xFF0B3325),
    heroEnd: Color(0xFF12503A),
    readingTop: Color(0xFF07130E),
    readingBottom: Color(0xFF0E2219),
    pattern: Color(0xFFDDBD6C),
    isDark: true,
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension PaletteX on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}

const radiusL = 24.0;
const radiusM = 18.0;

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.emerald,
    brightness: brightness,
    primary: p.primary,
    surface: p.surface,
  );
  const heading = TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w700);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: banglaFont,
    fontFamilyFallback: fontFallback,
    scaffoldBackgroundColor: p.background,
    extensions: [p],
    textTheme: TextTheme(
      headlineSmall: heading.copyWith(fontSize: 24, color: p.text),
      titleLarge: heading.copyWith(fontSize: 20, color: p.text),
      titleMedium: heading.copyWith(fontSize: 17, color: p.text, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16, color: p.text, height: 1.6),
      bodyMedium: TextStyle(fontSize: 14.5, color: p.text, height: 1.55),
      bodySmall: TextStyle(fontSize: 12.5, color: p.muted, height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: heading.copyWith(fontSize: 22, color: p.text),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusM),
        side: BorderSide(color: p.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.isDark ? Brand.night : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
        textStyle: heading.copyWith(fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.primary,
        side: BorderSide(color: p.primary.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: heading.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        textStyle: heading.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.primary.withValues(alpha: 0.14),
      height: 70,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.primary : p.muted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: headingFont,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? p.primary : p.muted,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : null,
      ),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: p.primary, thumbColor: p.primary),
    listTileTheme: ListTileThemeData(iconColor: p.primary, textColor: p.text),
    dividerTheme: DividerThemeData(color: p.border, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusL)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusL)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
