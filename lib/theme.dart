import 'package:flutter/material.dart';

/// Podium palette: stadium navy surfaces with gold, silver, and bronze
/// taken from the podium itself.
class PodiumColors {
  static const navy = Color(0xFF14213D);
  static const field = Color(0xFF1D2B4F);
  static const line = Color(0xFF2E3E66);
  static const gold = Color(0xFFE3B23C);
  static const silver = Color(0xFFB8C2D1);
  static const bronze = Color(0xFFC07A45);
  static const chalk = Color(0xFFF2F4F8);
  static const muted = Color(0xFF9AA5B8);
  static const danger = Color(0xFFFF6B6B);
  static const dangerTint = Color(0x26FF6B6B);
}

ThemeData buildPodiumTheme() {
  const scheme = ColorScheme.dark(
    primary: PodiumColors.gold,
    onPrimary: PodiumColors.navy,
    secondary: PodiumColors.silver,
    onSecondary: PodiumColors.navy,
    surface: PodiumColors.field,
    onSurface: PodiumColors.chalk,
    error: PodiumColors.danger,
    onError: PodiumColors.navy,
  );

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PodiumColors.navy,
    appBarTheme: const AppBarTheme(
      backgroundColor: PodiumColors.navy,
      foregroundColor: PodiumColors.chalk,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PodiumColors.field,
      labelStyle: const TextStyle(color: PodiumColors.muted),
      border: border(PodiumColors.line),
      enabledBorder: border(PodiumColors.line),
      focusedBorder: border(PodiumColors.gold, 2),
      errorBorder: border(PodiumColors.danger),
      focusedErrorBorder: border(PodiumColors.danger, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: PodiumColors.chalk,
        side: const BorderSide(color: PodiumColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: PodiumColors.gold),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
