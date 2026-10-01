import 'package:flutter/material.dart';

/// Big titles.
const titleFont = 'NotoSerifBengali';

/// Bangla text and UI.
const banglaFont = 'HindSiliguri';
const headingFont = banglaFont;
const arabicFont = 'AmiriQuran';

/// Hind Siliguri covers Bangla and Latin; Noto Sans Bengali and Amiri Quran
/// fill any gaps (rare Bangla signs, Arabic letters inside Bangla text).
const fontFallback = ['NotoSansBengali', arabicFont];

/// Brand colours that do not change with light/dark mode.
class Brand {
  static const green = Color(0xFF14553F);
  static const greenDark = Color(0xFF0E3B2C);
  static const gold = Color(0xFFF1DDA8);
  static const goldText = Color(0xFF7A5A14);
  static const cream = Color(0xFFFFFBF0);

  /// Lighter greens for the always-dark splash, share card and pattern gradients.
  static const greenBright = Color(0xFF14704F);
  static const greenShare = Color(0xFF12684A);
  static const greenPattern = Color(0xFF1B7A55);

  /// Kaaba drawing on the Qibla compass.
  static const kaaba = Color(0xFF1B1B1B);
  static const kaabaBand = Color(0xFFE2BE62);
  static const kaabaDoor = Color(0xFFB8963F);

  /// Warnings (missing permissions); readable on light and dark.
  static const warn = Color(0xFFE0851B);

  // Older names, still used by a few widgets.
  static const emerald = green;
  static const deepEmerald = greenDark;
  static const night = Color(0xFF0A1511);
  static const lightGold = gold;
}

/// A soft background colour with its matching text colour.
@immutable
class Tint {
  const Tint(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

/// Colours that change between light and dark mode. Use it with `context.palette`.
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
    required this.onPrimary,
    required this.greenCard,
    required this.greenCardDark,
    required this.gold,
    required this.goldText,
    required this.pill,
    required this.arabic,
    required this.tints,
    required this.isDark,
  });

  final Color background;
  final Color surface;

  /// Slightly darker than [surface], for boxes inside cards.
  final Color surfaceSoft;
  final Color border;
  final Color text;
  final Color muted;

  /// Buttons, links, active icons.
  final Color primary;
  final Color onPrimary;

  /// The deep green of the ayah card and the player.
  final Color greenCard;
  final Color greenCardDark;

  /// Gold on green (buttons, divider).
  final Color gold;

  /// Gold text on a light background.
  final Color goldText;

  /// Light green pill behind the active tab.
  final Color pill;
  final Color arabic;

  /// rose, sand, sky, mint, lilac.
  final List<Tint> tints;
  final bool isDark;

  Tint get rose => tints[0];
  Tint get sand => tints[1];
  Tint get sky => tints[2];
  Tint get mint => tints[3];
  Tint get lilac => tints[4];

  /// Filled heart (প্রিয়), the north letter on the compass, the lesson stars.
  Color get heart => isDark ? const Color(0xFFF2788E) : const Color(0xFFD6455F);
  Color get north => isDark ? const Color(0xFFF07563) : const Color(0xFFC0392B);
  Color get star => isDark ? const Color(0xFFE9C25A) : const Color(0xFFD9A93A);

  // Older names, still used by a few screens.
  Color get accent => goldText;
  Color get heroStart => greenCard;
  Color get heroEnd => greenCardDark;
  Color get readingTop => background;
  Color get readingBottom => background;
  Color get pattern => isDark ? gold : primary;

  static const light = Palette(
    background: Color(0xFFF5F2EA),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF8F6F0),
    border: Color(0xFFE6E1D6),
    text: Color(0xFF1E2A24),
    muted: Color(0xFF6E6A5E),
    primary: Brand.green,
    onPrimary: Colors.white,
    greenCard: Brand.green,
    greenCardDark: Brand.greenDark,
    gold: Brand.gold,
    goldText: Brand.goldText,
    pill: Color(0xFFE1EFE7),
    arabic: Color(0xFF14231C),
    tints: [
      Tint(Color(0xFFF6E7E4), Color(0xFF7A2E26)),
      Tint(Color(0xFFF5ECD9), Color(0xFF6A4B10)),
      Tint(Color(0xFFE2EBF4), Color(0xFF1E4568)),
      Tint(Color(0xFFE1EFE7), Color(0xFF1C5A3F)),
      Tint(Color(0xFFECE5F3), Color(0xFF4A3370)),
    ],
    isDark: false,
  );

  static const dark = Palette(
    background: Color(0xFF0F1512),
    surface: Color(0xFF18201C),
    surfaceSoft: Color(0xFF1E2823),
    border: Color(0xFF2A352F),
    text: Color(0xFFECE8DD),
    muted: Color(0xFFA6A99E),
    primary: Color(0xFF6CC79D),
    onPrimary: Color(0xFF0A1511),
    greenCard: Color(0xFF123F2F),
    greenCardDark: Color(0xFF0B2A1F),
    gold: Brand.gold,
    goldText: Color(0xFFE3C77F),
    pill: Color(0xFF1F3A2D),
    arabic: Color(0xFFF3ECD8),
    tints: [
      Tint(Color(0xFF3A2624), Color(0xFFF2BFB6)),
      Tint(Color(0xFF362D1C), Color(0xFFEACD8E)),
      Tint(Color(0xFF1E2C3A), Color(0xFFAFCBEA)),
      Tint(Color(0xFF1C3127), Color(0xFFA9DABF)),
      Tint(Color(0xFF2C253C), Color(0xFFD1BEEE)),
    ],
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

const radiusL = 26.0;
const radiusM = 18.0;

/// Smallest touch target.
const minTouch = 44.0;

/// Style for big serif titles.
TextStyle titleStyle(Palette p, {double size = 24}) => TextStyle(
  fontFamily: titleFont,
  fontFamilyFallback: fontFallback,
  fontWeight: FontWeight.w600,
  fontSize: size,
  height: 1.35,
  color: p.text,
);

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.green,
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    surface: p.surface,
  );
  const ui = TextStyle(fontFamily: banglaFont, fontFamilyFallback: fontFallback);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: banglaFont,
    fontFamilyFallback: fontFallback,
    scaffoldBackgroundColor: p.background,
    extensions: [p],
    materialTapTargetSize: MaterialTapTargetSize.padded,
    textTheme: TextTheme(
      headlineSmall: titleStyle(p, size: 24),
      titleLarge: titleStyle(p, size: 20),
      titleMedium: ui.copyWith(fontSize: 16.5, color: p.text, fontWeight: FontWeight.w600),
      bodyLarge: ui.copyWith(fontSize: 16, color: p.text, height: 1.6),
      bodyMedium: ui.copyWith(fontSize: 14.5, color: p.text, height: 1.55),
      bodySmall: ui.copyWith(fontSize: 14, color: p.muted, height: 1.45),
      labelLarge: ui.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: titleStyle(p, size: 21),
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
        foregroundColor: p.onPrimary,
        minimumSize: const Size(minTouch, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
        textStyle: ui.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.primary,
        minimumSize: const Size(minTouch, minTouch),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: ui.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        minimumSize: const Size(minTouch, minTouch),
        textStyle: ui.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(minTouch, minTouch)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.pill,
      indicatorShape: const StadiumBorder(),
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.primary : p.muted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => ui.copyWith(
          fontSize: 14,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
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
    listTileTheme: ListTileThemeData(
      iconColor: p.primary,
      textColor: p.text,
      minVerticalPadding: 10,
    ),
    dividerTheme: DividerThemeData(color: p.border, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusL)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusL)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: BorderSide(color: p.primary, width: 1.5),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
