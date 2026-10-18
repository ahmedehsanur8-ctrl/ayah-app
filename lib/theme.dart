import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Big titles.
const titleFont = 'NotoSerifBengali';

/// Bangla text and UI.
const banglaFont = 'HindSiliguri';
const headingFont = banglaFont;
const arabicFont = 'AmiriQuran';

/// Hind Siliguri covers Bangla and Latin; Noto Sans Bengali and Amiri Quran
/// fill any gaps (rare Bangla signs, Arabic letters inside Bangla text).
const fontFallback = ['NotoSansBengali', arabicFont];

/// "Night & Gold" colours that do not change with light/dark mode.
/// Every colour in the app comes from here or from [Palette]; screens never
/// write colour values themselves.
class Brand {
  /// Night: header and hero surfaces (light mode).
  static const night = Color(0xFF14213D);
  static const nightDeep = Color(0xFF0E1830);

  /// Night in dark mode.
  static const nightDark = Color(0xFF0A1222);
  static const nightDarkDeep = Color(0xFF070D19);

  /// Gold: ornament, the current prayer, numbers on dark surfaces.
  static const gold = Color(0xFFD4AF37);

  /// Gold for text on light backgrounds.
  static const goldText = Color(0xFF7A5A00);

  /// Emerald: every main action, the active tab, the playing ayah.
  static const emerald = Color(0xFF0B6B55);

  /// Text on night surfaces.
  static const onNight = Color(0xFFFFFFFF);

  /// Arabic text on night surfaces (a warm white).
  static const cream = Color(0xFFFBF6E9);

  /// Kaaba drawing on the Qibla compass.
  static const kaaba = Color(0xFF1B1B1B);
  static const kaabaBand = Color(0xFFE2BE62);
  static const kaabaDoor = Color(0xFFB8963F);

  /// Warnings (missing permissions); readable on light and dark.
  static const warn = Color(0xFFE0851B);

  // Older names, still used by a few widgets (splash, share card, pattern).
  static const green = emerald;
  static const greenDark = night;
  static const greenBright = Color(0xFF1D2E52);
  static const greenShare = Color(0xFF1A2A4A);
  static const greenPattern = Color(0xFF223660);
  static const deepEmerald = night;
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
/// All text pairs are at least 4.5:1 (checked in test/widget_test.dart).
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
    required this.action,
    required this.night,
    required this.nightDeep,
    required this.gold,
    required this.goldText,
    required this.pill,
    required this.arabic,
    required this.isDark,
  });

  /// Ground: the page background.
  final Color background;

  /// Cards and sheets.
  final Color surface;

  /// Slightly darker than [surface], for boxes inside cards.
  final Color surfaceSoft;

  /// Lines.
  final Color border;

  /// Ink: main text.
  final Color text;
  final Color muted;

  /// Emerald for text, icons and links (lighter in dark mode, for contrast).
  final Color primary;

  /// Text on [action].
  final Color onPrimary;

  /// Emerald fill of the main buttons (white text in both modes).
  final Color action;

  /// Night: headers and hero surfaces.
  final Color night;
  final Color nightDeep;

  /// Gold on night surfaces (ornament, numbers, the current prayer).
  final Color gold;

  /// Gold text on light surfaces.
  final Color goldText;

  /// Soft emerald: behind the active tab, the playing ayah, icon squares.
  final Color pill;
  final Color arabic;
  final bool isDark;

  /// White text on night surfaces, and its softer version.
  Color get onNight => Brand.onNight;
  Color get onNightMuted => Brand.onNight.withValues(alpha: 0.8);

  /// Arabic on night surfaces.
  Color get arabicOnNight => Brand.cream;

  /// Faint lines and fills on night surfaces.
  Color get nightLine => Brand.onNight.withValues(alpha: 0.14);

  /// Emerald icon on a soft emerald square (one style for every icon box).
  Tint get iconTint => Tint(pill, primary);

  // Older names: every tint is the same emerald square now (no pastel cards).
  Tint get rose => iconTint;
  Tint get sand => iconTint;
  Tint get sky => iconTint;
  Tint get mint => iconTint;
  Tint get lilac => iconTint;
  List<Tint> get tints => [iconTint, iconTint, iconTint, iconTint, iconTint];

  /// Filled heart (প্রিয়), the north letter on the compass, the lesson stars.
  Color get heart => isDark ? const Color(0xFFF2788E) : const Color(0xFFC23A55);
  Color get north => isDark ? const Color(0xFFF07563) : const Color(0xFFC0392B);

  /// The north letter on a night surface.
  Color get northOnNight => const Color(0xFFF07563);
  Color get star => gold;

  // Older names, still used by a few screens.
  Color get greenCard => night;
  Color get greenCardDark => nightDeep;
  Color get accent => goldText;
  Color get heroStart => night;
  Color get heroEnd => nightDeep;
  Color get readingTop => background;
  Color get readingBottom => background;
  Color get pattern => gold;

  static const light = Palette(
    background: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF7F8FB),
    border: Color(0xFFDDE2EC),
    text: Color(0xFF13203A),
    muted: Color(0xFF4E5A70),
    primary: Brand.emerald,
    onPrimary: Colors.white,
    action: Brand.emerald,
    night: Brand.night,
    nightDeep: Brand.nightDeep,
    gold: Brand.gold,
    goldText: Brand.goldText,
    pill: Color(0xFFE3F1EC),
    arabic: Color(0xFF13203A),
    isDark: false,
  );

  static const dark = Palette(
    background: Color(0xFF0E1628),
    surface: Color(0xFF172238),
    surfaceSoft: Color(0xFF1C2942),
    border: Color(0xFF2A3650),
    text: Color(0xFFE9EDF5),
    muted: Color(0xFFA9B3C6),
    primary: Color(0xFF5CC9A7),
    onPrimary: Colors.white,
    action: Brand.emerald,
    night: Brand.nightDark,
    nightDeep: Brand.nightDarkDeep,
    gold: Brand.gold,
    goldText: Brand.gold,
    pill: Color(0xFF12352D),
    arabic: Color(0xFFF3EEDF),
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
const radiusM = 16.0;

/// Buttons: 14–18 radius.
const radiusButton = 16.0;

/// Smallest touch target.
const minTouch = 48.0;

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
    seedColor: Brand.emerald,
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
      bodyLarge: ui.copyWith(fontSize: 16.5, color: p.text, height: 1.6),
      bodyMedium: ui.copyWith(fontSize: 16, color: p.text, height: 1.55),
      bodySmall: ui.copyWith(fontSize: 14, color: p.muted, height: 1.45),
      labelLarge: ui.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      labelMedium: ui.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    // Every sub-page gets the compact night header (white text, gold accents).
    appBarTheme: AppBarTheme(
      backgroundColor: p.night,
      foregroundColor: p.onNight,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: p.onNight),
      actionsIconTheme: IconThemeData(color: p.onNight),
      titleTextStyle: titleStyle(
        p,
        size: 20,
      ).copyWith(color: p.onNight, fontWeight: FontWeight.w700),
    ),
    // The only tab bar sits in a night app bar (প্রিয়).
    tabBarTheme: TabBarThemeData(
      labelColor: p.onNight,
      unselectedLabelColor: p.onNightMuted,
      indicatorColor: p.gold,
      dividerColor: Colors.transparent,
      labelStyle: ui.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      unselectedLabelStyle: ui.copyWith(fontSize: 16),
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
    // Primary: emerald, white text, 48 high.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.action,
        foregroundColor: p.onPrimary,
        disabledBackgroundColor: p.border,
        disabledForegroundColor: p.muted,
        minimumSize: const Size(minTouch, minTouch),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
        textStyle: ui.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    // Secondary: surface with a line border.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.primary,
        backgroundColor: p.surface,
        minimumSize: const Size(minTouch, minTouch),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
        textStyle: ui.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        minimumSize: const Size(minTouch, minTouch),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
        textStyle: ui.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
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
      height: 72,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
    sliderTheme: SliderThemeData(
      activeTrackColor: p.primary,
      thumbColor: p.primary,
      inactiveTrackColor: p.border,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary, linearTrackColor: p.pill),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.pill,
      side: BorderSide(color: p.border),
      shape: const StadiumBorder(),
      labelStyle: ui.copyWith(fontSize: 14, color: p.text, fontWeight: FontWeight.w600),
      checkmarkColor: p.primary,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: p.surface,
        foregroundColor: p.muted,
        selectedBackgroundColor: p.pill,
        selectedForegroundColor: p.primary,
        side: BorderSide(color: p.border),
        minimumSize: const Size(minTouch, minTouch),
        textStyle: ui.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
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
