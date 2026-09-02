import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A primary/secondary/main accent combo the user can pick in Settings.
class TColorScheme {
  final String id;
  final String label;
  final Color main;
  final Color primary;
  final Color secondary;

  const TColorScheme({
    required this.id,
    required this.label,
    required this.main,
    required this.primary,
    required this.secondary,
  });

  /// Builds a one-off (custom) scheme from three picked colors.
  factory TColorScheme.custom({
    required Color main,
    required Color primary,
    required Color secondary,
  }) {
    return TColorScheme(
      id: 'custom',
      label: 'Custom',
      main: main,
      primary: primary,
      secondary: secondary,
    );
  }
}

/// The default dark structural base used before a load/scheme applies and as
/// the starting value of the custom color picker.
const Color kDefaultMain = Color(0xFF14120F);

/// Available color schemes: `main` drives the structural neutrals, `primary`
/// the amber accents and `secondary` the green ones. Every preset carries its
/// own `main`, so picking a scheme also changes the app's background.
const List<TColorScheme> kColorSchemes = [
  TColorScheme(
    id: 'amber',
    label: 'Amber / Grass',
    main: Color(0xFF14120F),
    primary: Color(0xFFFF8A3D),
    secondary: Color(0xFF7FD858),
  ),
  TColorScheme(
    id: 'ember',
    label: 'Ember / Ice',
    main: Color(0xFF170F13),
    primary: Color(0xFFEF5350),
    secondary: Color(0xFF4DD0E1),
  ),
  TColorScheme(
    id: 'violet',
    label: 'Violet / Gold',
    main: Color(0xFF14101E),
    primary: Color(0xFFB388FF),
    secondary: Color(0xFFFFCB6B),
  ),
  TColorScheme(
    id: 'cyan',
    label: 'Cyan / Magenta',
    main: Color(0xFF0E1416),
    primary: Color(0xFF26A5DA),
    secondary: Color(0xFFEC4E7A),
  ),
  TColorScheme(
    id: 'lime',
    label: 'Lime / Teal',
    main: Color(0xFF12160F),
    primary: Color(0xFFCDDC39),
    secondary: Color(0xFF26A69A),
  ),
  TColorScheme(
    id: 'crimson',
    label: 'Crimson / Emerald',
    main: Color(0xFF1A1111),
    primary: Color(0xFFE53935),
    secondary: Color(0xFF43A047),
  ),
];

TColorScheme? colorSchemeById(String id) {
  for (final s in kColorSchemes) {
    if (s.id == id) return s;
  }
  return null;
}

/// Tubemate v2 · Media Transport design system.
///
/// Mirrors the palette and typography from the redesign mockups.
class TColors {
  TColors._();

  // Structural neutrals are runtime-mutable so the custom "main" color can
  // retint the whole app. They are derived from the scheme's `main` base.
  static Color bg = kDefaultMain;
  static Color panel = const Color(0xFF1E1B17);
  static Color panel2 = const Color(0xFF24211C);
  static Color counterBg = const Color(0xFF1A1712);
  static Color jackBg = const Color(0xFF100E0B);
  static Color line = const Color(0xFF322D26);
  static Color lineSoft = const Color(0xFF26221D);
  static const Color text = Color(0xFFF2EDE4);
  static const Color textMuted = Color(0xFF8A8477);
  static const Color textDim = Color(0xFF5C574C);

  // Accents are runtime-mutable so Settings can swap the color scheme.
  static Color amber = const Color(0xFFFF8A3D);
  static Color amberBright = const Color(0xFFFFA35E);
  static Color amberDim = const Color(0xFF7A4A26);
  static Color green = const Color(0xFF7FD858);
  static Color greenDim = const Color(0xFF3E5A2E);
  static const Color red = Color(0xFFE1573F);
  static const Color thumbGradA = Color(0xFF3A2A5C);
  static const Color thumbGradB = Color(0xFFC23B7A);
  static Color thumbGradC = const Color(0xFFFF8A3D);

  /// Fires whenever [applyScheme] swaps the accents. The app listens and
  /// rebuilds so the new colors take effect immediately.
  static final ValueNotifier<int> accentRevision = ValueNotifier<int>(0);

  static void applyScheme(TColorScheme scheme) {
    // Structural neutrals are a fixed ladder of lightness steps above the
    // scheme's `main` base, which reproduces the original dark palette.
    bg = scheme.main;
    panel = _shift(scheme.main, lighten: 0.035);
    panel2 = _shift(scheme.main, lighten: 0.057);
    counterBg = _shift(scheme.main, lighten: 0.017);
    jackBg = _shift(scheme.main, darken: 0.017);
    line = _shift(scheme.main, lighten: 0.104);
    lineSoft = _shift(scheme.main, lighten: 0.063);

    amber = scheme.primary;
    amberBright = _shift(scheme.primary, lighten: 0.10);
    amberDim = _shift(scheme.primary, darken: 0.28);
    green = scheme.secondary;
    greenDim = _shift(scheme.secondary, darken: 0.28);
    thumbGradC = scheme.primary;
    accentRevision.value++;
  }

  static Color _shift(Color c, {double lighten = 0, double darken = 0}) {
    final hsl = HSLColor.fromColor(c);
    final lightness = (hsl.lightness + lighten - darken).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}

/// Typography helpers for the three design families.
class TText {
  TText._();

  static TextStyle display(
    BuildContext context, {
    double size = 30,
    FontWeight weight = FontWeight.w700,
    Color color = TColors.text,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: weight,
    color: color,
  );

  static TextStyle body(
    BuildContext context, {
    double size = 13.5,
    FontWeight weight = FontWeight.w400,
    Color color = TColors.text,
  }) => GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  static TextStyle mono(
    BuildContext context, {
    double size = 11,
    FontWeight weight = FontWeight.w400,
    Color color = TColors.text,
    double letterSpacing = 0.06,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

/// Base text styles used across the app via ThemeData.
TextTheme _buildTextTheme(BuildContext context) {
  return TextTheme(
    displayLarge: TText.display(context, size: 30),
    headlineMedium: TText.display(context, size: 19, weight: FontWeight.w600),
    titleMedium: TText.body(context, size: 14.5, weight: FontWeight.w500),
    bodyLarge: TText.body(context, size: 13.5),
    bodyMedium: TText.body(context, size: 12.5),
    bodySmall: TText.body(context, size: 11, color: TColors.textMuted),
    labelSmall: TText.mono(context, size: 9.5, color: TColors.textDim),
  );
}

ThemeData buildTubemateTheme(BuildContext context) {
  final base = ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: TColors.bg,
    colorScheme: ColorScheme.dark(
      primary: TColors.amber,
      secondary: TColors.green,
      error: TColors.red,
      surface: TColors.panel,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: _buildTextTheme(context),
    dividerTheme: DividerThemeData(
      color: TColors.lineSoft,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TColors.panel2,
      contentTextStyle: TText.body(context, size: 13),
      actionTextColor: TColors.amber,
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: TText.mono(context, size: 10, color: TColors.text),
      decoration: BoxDecoration(
        color: TColors.jackBg,
        border: Border.all(color: TColors.line),
      ),
    ),
  );
}
