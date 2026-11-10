import 'package:flutter/material.dart';

/// Podium palette: stadium navy surfaces with gold, silver, and bronze
/// taken from the podium itself.
class PodiumColors {
  static const navy = Color(0xFF14213D);
  static const deep = Color(0xFF111C34); // bottom bars, sunken wells
  static const field = Color(0xFF1D2B4F); // cards
  static const raised = Color(0xFF243560); // selected / pressed surfaces
  static const line = Color(0xFF2E3E66);
  static const gold = Color(0xFFE3B23C);
  static const goldBright = Color(0xFFF0C75E);
  static const goldTint = Color(0x24E3B23C);
  static const silver = Color(0xFFB8C2D1);
  static const silverTint = Color(0x24B8C2D1);
  static const bronze = Color(0xFFC07A45);
  static const bronzeText = Color(0xFFD9915A); // bronze that passes contrast as text
  static const bronzeTint = Color(0x29C07A45);
  static const chalk = Color(0xFFF2F4F8);
  static const muted = Color(0xFF9AA5B8);
  static const danger = Color(0xFFFF6B6B);
  static const dangerText = Color(0xFFFF8A8A);
  static const dangerTint = Color(0x26FF6B6B);

  /// Gold, silver, bronze for ranks 1-3; null after that.
  static Color? medal(int rank) => switch (rank) {
        1 => gold,
        2 => silver,
        3 => bronze,
        _ => null,
      };
}

/// Corner radii used across the app.
class PodiumRadii {
  static const card = 20.0;
  static const tile = 16.0;
  static const control = 14.0;
  static const pill = 999.0;
}

/// Font families bundled in pubspec.yaml.
class PodiumFonts {
  static const body = 'Inter';
  static const numbers = 'BarlowCondensed';
}

/// Text styles that sit outside the Material text theme.
class PodiumText {
  /// Big condensed numerals for scores, coins, ranks, and stat lines.
  static TextStyle score({
    double size = 44,
    Color color = PodiumColors.chalk,
    FontWeight weight = FontWeight.w700,
  }) =>
      TextStyle(
        fontFamily: PodiumFonts.numbers,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// The PODIUM wordmark.
  static TextStyle wordmark({double size = 24}) => TextStyle(
        fontFamily: PodiumFonts.numbers,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: size * 0.14,
        color: PodiumColors.chalk,
        height: 1.0,
      );

  /// Small uppercase label, e.g. "WEEK 10 · SUNDAY".
  static const overline = TextStyle(
    fontFamily: PodiumFonts.body,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: PodiumColors.muted,
  );

  static const caption = TextStyle(
    fontFamily: PodiumFonts.body,
    fontSize: 12,
    color: PodiumColors.muted,
  );
}

ThemeData buildPodiumTheme() {
  const scheme = ColorScheme.dark(
    primary: PodiumColors.gold,
    onPrimary: PodiumColors.navy,
    primaryContainer: PodiumColors.goldTint,
    onPrimaryContainer: PodiumColors.gold,
    secondary: PodiumColors.silver,
    onSecondary: PodiumColors.navy,
    secondaryContainer: PodiumColors.raised,
    onSecondaryContainer: PodiumColors.chalk,
    tertiary: PodiumColors.bronze,
    onTertiary: PodiumColors.navy,
    surface: PodiumColors.field,
    onSurface: PodiumColors.chalk,
    onSurfaceVariant: PodiumColors.muted,
    surfaceContainerLowest: PodiumColors.deep,
    surfaceContainerLow: PodiumColors.field,
    surfaceContainer: PodiumColors.field,
    surfaceContainerHigh: PodiumColors.raised,
    surfaceContainerHighest: PodiumColors.raised,
    outline: PodiumColors.line,
    outlineVariant: PodiumColors.line,
    error: PodiumColors.danger,
    onError: PodiumColors.navy,
    surfaceTint: Colors.transparent,
  );

  const body = PodiumFonts.body;

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(PodiumRadii.control),
        borderSide: BorderSide(color: color, width: width),
      );

  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(PodiumRadii.control),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: body,
    scaffoldBackgroundColor: PodiumColors.navy,
    canvasColor: PodiumColors.navy,
    dividerColor: PodiumColors.line,
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1),
      headlineLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.6),
      headlineSmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontWeight: FontWeight.w600),
      labelLarge: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(height: 1.45),
      bodyMedium: TextStyle(height: 1.45),
    ).apply(bodyColor: PodiumColors.chalk, displayColor: PodiumColors.chalk),
    appBarTheme: const AppBarTheme(
      backgroundColor: PodiumColors.navy,
      foregroundColor: PodiumColors.chalk,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      titleTextStyle: TextStyle(
        fontFamily: body,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: PodiumColors.chalk,
      ),
    ),
    cardTheme: CardThemeData(
      color: PodiumColors.field,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PodiumRadii.tile),
        side: const BorderSide(color: PodiumColors.line),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: PodiumColors.silver,
      textColor: PodiumColors.chalk,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      subtitleTextStyle: TextStyle(fontFamily: body, fontSize: 13, color: PodiumColors.muted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: PodiumColors.field,
      selectedColor: PodiumColors.gold,
      disabledColor: PodiumColors.field,
      side: const BorderSide(color: PodiumColors.line),
      shape: const StadiumBorder(),
      showCheckmark: false,
      labelStyle: const TextStyle(
        fontFamily: body,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: PodiumColors.silver,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: body,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: PodiumColors.navy,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      iconTheme: const IconThemeData(color: PodiumColors.gold, size: 18),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PodiumColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: PodiumColors.muted),
      floatingLabelStyle: const TextStyle(color: PodiumColors.gold, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: PodiumColors.muted),
      prefixIconColor: PodiumColors.muted,
      suffixIconColor: PodiumColors.muted,
      border: border(PodiumColors.line),
      enabledBorder: border(PodiumColors.line),
      focusedBorder: border(PodiumColors.gold, 2),
      errorBorder: border(PodiumColors.danger),
      focusedErrorBorder: border(PodiumColors.danger, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: controlShape,
        disabledBackgroundColor: PodiumColors.line,
        disabledForegroundColor: PodiumColors.muted,
        textStyle: const TextStyle(fontFamily: body, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      // Not full-width: ElevatedButtons also sit in dialog action rows.
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 50),
        backgroundColor: PodiumColors.gold,
        foregroundColor: PodiumColors.navy,
        elevation: 0,
        shape: controlShape,
        textStyle: const TextStyle(fontFamily: body, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: PodiumColors.chalk,
        side: const BorderSide(color: PodiumColors.line),
        shape: controlShape,
        textStyle: const TextStyle(fontFamily: body, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PodiumColors.gold,
        textStyle: const TextStyle(fontFamily: body, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: PodiumColors.chalk),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: PodiumColors.gold,
      foregroundColor: PodiumColors.navy,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: const TextStyle(fontFamily: body, fontSize: 15, fontWeight: FontWeight.w700),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: PodiumColors.field,
        foregroundColor: PodiumColors.muted,
        selectedBackgroundColor: PodiumColors.raised,
        selectedForegroundColor: PodiumColors.chalk,
        side: const BorderSide(color: PodiumColors.line),
        textStyle: const TextStyle(fontFamily: body, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: PodiumColors.chalk,
      unselectedLabelColor: PodiumColors.muted,
      indicatorColor: PodiumColors.gold,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: PodiumColors.line,
      labelStyle: TextStyle(fontFamily: body, fontSize: 14, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontFamily: body, fontSize: 14, fontWeight: FontWeight.w600),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PodiumColors.field,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: PodiumColors.line),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: body,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: PodiumColors.chalk,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PodiumColors.field,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: PodiumColors.line,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: PodiumColors.field,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PodiumRadii.control),
        side: const BorderSide(color: PodiumColors.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PodiumColors.deep,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: PodiumColors.goldTint,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PodiumRadii.control)),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: body,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? PodiumColors.gold : PodiumColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected) ? PodiumColors.gold : PodiumColors.muted,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: PodiumColors.line, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PodiumColors.gold,
      linearTrackColor: PodiumColors.line,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: PodiumColors.gold,
      selectionColor: PodiumColors.goldTint,
      selectionHandleColor: PodiumColors.gold,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PodiumColors.raised,
      contentTextStyle: const TextStyle(fontFamily: body, fontSize: 14, color: PodiumColors.chalk),
      actionTextColor: PodiumColors.gold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PodiumRadii.control)),
    ),
  );
}
