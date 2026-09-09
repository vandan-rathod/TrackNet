import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const primaryInk = Color(0xff18181b),
    mutedInk = Color(0xff71717a),
    neutralFill = Color(0xffe4e4e7),
    warningAccent = Color(0xffb45309),
    critical = Color(0xffdc2626),
    successAccent = Color(0xff15803d);

ThemeData appTheme() {
  const border = BorderSide(color: neutralFill);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  const scheme = ColorScheme.light(
    primary: primaryInk,
    onPrimary: Colors.white,
    secondary: Color(0xfff4f4f5),
    onSecondary: primaryInk,
    surface: Colors.white,
    onSurface: primaryInk,
    surfaceContainerHighest: Color(0xfff4f4f5),
    onSurfaceVariant: mutedInk,
    outline: neutralFill,
    outlineVariant: neutralFill,
    error: critical,
    primaryContainer: Color(0xfff4f4f5),
    onPrimaryContainer: primaryInk,
    secondaryContainer: Color(0xfff4f4f5),
    onSecondaryContainer: primaryInk,
    surfaceTint: Colors.transparent,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xfffafafa),
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: primaryInk, displayColor: primaryInk),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: border,
      ),
    ),
    dividerTheme: const DividerThemeData(color: neutralFill, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: mutedInk, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: border,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: border,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryInk, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryInk,
        backgroundColor: Colors.white,
        side: border,
        shape: shape,
        minimumSize: const Size(36, 36),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        minimumSize: const Size(36, 36),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: shape),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: primaryInk, shape: shape),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: border,
      backgroundColor: Colors.white,
      selectedColor: const Color(0xfff4f4f5),
      checkmarkColor: primaryInk,
      shape: shape,
      labelStyle: const TextStyle(fontSize: 12, color: primaryInk),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(Color(0xfffafafa)),
      headingTextStyle: TextStyle(
        color: mutedInk,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      dataTextStyle: TextStyle(color: primaryInk, fontSize: 12),
      dividerThickness: 1,
      horizontalMargin: 14,
      columnSpacing: 26,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: border,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: border,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xfff4f4f5),
      height: 64,
    ),
  );
}
