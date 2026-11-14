import 'package:flutter/material.dart';

// ── Palette ──
const navy = Color(0xFF0F1E3D);
const navyDeep = Color(0xFF0A1530);
const navySoft = Color(0xFF1D2F57);
const gold = Color(0xFFC9A24B);
const goldLight = Color(0xFFE2C27A);
const goldDeep = Color(0xFFA9822F);
const ivory = Color(0xFFFAF6EC);
const paper = Color(0xFFF3ECDC);
const ink = Color(0xFF1B2236);
const danger = Color(0xFFB3402F);
const success = Color(0xFF2F7A55);
const creamText = Color(0xFFFDF6E3);

const displayFont = 'Amiri';
const textFont = 'Tajawal';

/// Content widths for wide screens (web / tablets): the UI is centered instead of stretched.
const kMaxContentWidth = 1100.0;
const kMaxReadingWidth = 720.0;

/// Extra colors that Material's scheme has no slot for.
@immutable
class ExtraColors extends ThemeExtension<ExtraColors> {
  const ExtraColors({
    required this.gold,
    required this.goldSoft,
    required this.card,
    required this.paper,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.navyBar,
    required this.isDark,
  });

  final Color gold;
  final Color goldSoft;
  final Color card;
  final Color paper;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color navyBar;
  final bool isDark;

  static const light = ExtraColors(
    gold: goldDeep,
    goldSoft: Color(0xFFF1E3BF),
    card: Color(0xFFFFFDF8),
    paper: Color(0xFFF3ECDC),
    shimmerBase: Color(0xFFEDE4D0),
    shimmerHighlight: Color(0xFFFBF7EE),
    navyBar: navy,
    isDark: false,
  );

  static const dark = ExtraColors(
    gold: Color(0xFFD9B565),
    goldSoft: Color(0xFF3A3220),
    card: Color(0xFF16203A),
    paper: Color(0xFF111A2E),
    shimmerBase: Color(0xFF1A2540),
    shimmerHighlight: Color(0xFF26345A),
    navyBar: Color(0xFF0E1830),
    isDark: true,
  );

  @override
  ExtraColors copyWith() => this;

  @override
  ExtraColors lerp(ThemeExtension<ExtraColors>? other, double t) {
    if (other is! ExtraColors) return this;
    return ExtraColors(
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      card: Color.lerp(card, other.card, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      navyBar: Color.lerp(navyBar, other.navyBar, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension ThemeX on BuildContext {
  ExtraColors get extra => Theme.of(this).extension<ExtraColors>() ?? ExtraColors.light;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: navy,
  onPrimary: ivory,
  primaryContainer: Color(0xFFDDE3F0),
  onPrimaryContainer: navy,
  secondary: goldDeep,
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFF1E3BF),
  onSecondaryContainer: Color(0xFF3B2C08),
  tertiary: gold,
  onTertiary: Colors.white,
  surface: ivory,
  onSurface: ink,
  surfaceContainerHighest: Color(0xFFF0E8D6),
  onSurfaceVariant: Color(0xFF5E6478),
  surfaceContainer: Color(0xFFF5EFE2),
  surfaceContainerHigh: Color(0xFFF0E9DA),
  surfaceContainerLow: Color(0xFFFBF8F0),
  outline: Color(0xFFD5C8AC),
  outlineVariant: Color(0xFFE6DCC6),
  error: danger,
  onError: Colors.white,
  surfaceTint: Colors.transparent,
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFD9B565),
  onPrimary: navyDeep,
  primaryContainer: Color(0xFF243358),
  onPrimaryContainer: Color(0xFFEDE6D6),
  secondary: Color(0xFFD9B565),
  onSecondary: navyDeep,
  secondaryContainer: Color(0xFF3A3220),
  onSecondaryContainer: Color(0xFFF1E3BF),
  tertiary: goldLight,
  onTertiary: navyDeep,
  surface: Color(0xFF0B1220),
  onSurface: Color(0xFFEDE6D6),
  surfaceContainerHighest: Color(0xFF1C2740),
  onSurfaceVariant: Color(0xFFA9B0C0),
  surfaceContainer: Color(0xFF141D30),
  surfaceContainerHigh: Color(0xFF1A2438),
  surfaceContainerLow: Color(0xFF101828),
  outline: Color(0xFF34415F),
  outlineVariant: Color(0xFF263252),
  error: Color(0xFFE38A7A),
  onError: navyDeep,
  surfaceTint: Colors.transparent,
);

TextStyle _s(String family, FontWeight w, double size, double lineHeight) =>
    TextStyle(fontFamily: family, fontWeight: w, fontSize: size, height: lineHeight / size);

TextTheme _textTheme(Color color) {
  const b = FontWeight.bold;
  const n = FontWeight.normal;
  const m = FontWeight.w500;
  return TextTheme(
    displayLarge: _s(displayFont, b, 44, 60),
    displayMedium: _s(displayFont, b, 36, 50),
    displaySmall: _s(displayFont, b, 30, 44),
    headlineLarge: _s(displayFont, b, 28, 42),
    headlineMedium: _s(displayFont, b, 24, 36),
    headlineSmall: _s(displayFont, b, 21, 32),
    titleLarge: _s(displayFont, b, 20, 30),
    titleMedium: _s(textFont, b, 16, 24),
    titleSmall: _s(textFont, b, 14, 20),
    bodyLarge: _s(textFont, n, 16, 27),
    bodyMedium: _s(textFont, n, 14, 22),
    bodySmall: _s(textFont, n, 12, 18),
    labelLarge: _s(textFont, b, 15, 20),
    labelMedium: _s(textFont, m, 13, 18),
    labelSmall: _s(textFont, m, 11, 16),
  ).apply(bodyColor: color, displayColor: color);
}

ThemeData buildTheme({required bool dark}) {
  final scheme = dark ? _darkScheme : _lightScheme;
  final extra = dark ? ExtraColors.dark : ExtraColors.light;
  final text = _textTheme(scheme.onSurface);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: textFont,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    extensions: [extra],
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF1A2438) : navy,
      contentTextStyle: text.bodyMedium?.copyWith(color: ivory),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: extra.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? navyDeep : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? gold : null),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: extra.gold,
      selectionHandleColor: extra.gold,
      selectionColor: extra.gold.withValues(alpha: 0.3),
    ),
  );
}
