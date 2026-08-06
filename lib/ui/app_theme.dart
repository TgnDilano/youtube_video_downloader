import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tubemate v2 · Media Transport design system.
///
/// Mirrors the palette and typography from the redesign mockups.
class TColors {
  TColors._();

  static const Color bg = Color(0xFF14120F);
  static const Color panel = Color(0xFF1E1B17);
  static const Color panel2 = Color(0xFF24211C);
  static const Color counterBg = Color(0xFF1A1712);
  static const Color jackBg = Color(0xFF100E0B);
  static const Color line = Color(0xFF322D26);
  static const Color lineSoft = Color(0xFF26221D);
  static const Color text = Color(0xFFF2EDE4);
  static const Color textMuted = Color(0xFF8A8477);
  static const Color textDim = Color(0xFF5C574C);
  static const Color amber = Color(0xFFFF8A3D);
  static const Color amberBright = Color(0xFFFFA35E);
  static const Color amberDim = Color(0xFF7A4A26);
  static const Color green = Color(0xFF7FD858);
  static const Color greenDim = Color(0xFF3E5A2E);
  static const Color red = Color(0xFFE1573F);
  static const Color thumbGradA = Color(0xFF3A2A5C);
  static const Color thumbGradB = Color(0xFFC23B7A);
  static const Color thumbGradC = Color(0xFFFF8A3D);
}

/// Typography helpers for the three design families.
class TText {
  TText._();

  static TextStyle display(
    BuildContext context, {
    double size = 30,
    FontWeight weight = FontWeight.w700,
    Color color = TColors.text,
  }) =>
      GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, color: color);

  static TextStyle body(
    BuildContext context, {
    double size = 13.5,
    FontWeight weight = FontWeight.w400,
    Color color = TColors.text,
  }) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  static TextStyle mono(
    BuildContext context, {
    double size = 11,
    FontWeight weight = FontWeight.w400,
    Color color = TColors.text,
    double letterSpacing = 0.06,
  }) =>
      GoogleFonts.jetBrainsMono(
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
    colorScheme: const ColorScheme.dark(
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
    dividerTheme: const DividerThemeData(
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
