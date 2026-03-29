import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ocean_colors.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;

  bool get isDarkMode => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  ThemeData get theme => _isDark ? _darkTheme : _lightTheme;

  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: GoogleFonts.poppins().fontFamily,
    scaffoldBackgroundColor: OceanColors.darkBg1,
    colorScheme: const ColorScheme.dark(
      primary: OceanColors.cyan, secondary: OceanColors.teal,
      tertiary: OceanColors.positive, error: OceanColors.negative,
      surface: OceanColors.darkBg2,
      surfaceContainerHighest: OceanColors.darkBg1,
      onPrimary: OceanColors.darkBg1, onSecondary: OceanColors.darkBg1,
      onSurface: Colors.white, onSurfaceVariant: OceanColors.w70,
    ),
    cardTheme: CardThemeData(color: OceanColors.w15, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: OceanColors.w30, width: 1))),
    appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0,
      titleTextStyle: GoogleFonts.poppins(fontSize: 20,
          fontWeight: FontWeight.w700, color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white)),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: OceanColors.w08,
      indicatorColor: OceanColors.cyan.withOpacity(0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? GoogleFonts.poppins(fontSize: 10, color: OceanColors.cyan, fontWeight: FontWeight.w600)
              : GoogleFonts.poppins(fontSize: 10, color: OceanColors.w50)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? OceanColors.cyan : OceanColors.w50))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: OceanColors.w08,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OceanColors.w30)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OceanColors.w30)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OceanColors.cyan, width: 1.5)),
      hintStyle: const TextStyle(color: OceanColors.w50),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
    textTheme: TextTheme(
      headlineLarge:  GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
      headlineMedium: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
      titleLarge:     GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
      titleMedium:    GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      bodyLarge:      GoogleFonts.poppins(fontSize: 15, color: OceanColors.w90),
      bodyMedium:     GoogleFonts.poppins(fontSize: 13, color: OceanColors.w70),
      bodySmall:      GoogleFonts.poppins(fontSize: 11, color: OceanColors.w50),
      labelLarge:     GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    chipTheme: ChipThemeData(backgroundColor: OceanColors.w15,
      selectedColor: OceanColors.cyan.withOpacity(0.25),
      side: const BorderSide(color: OceanColors.w30),
      labelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    sliderTheme: const SliderThemeData(
      activeTrackColor: OceanColors.cyan, thumbColor: OceanColors.cyan,
      inactiveTrackColor: OceanColors.w30),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: OceanColors.cyan),
  );

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: GoogleFonts.poppins().fontFamily,
    scaffoldBackgroundColor: OceanColors.lightBg,
    colorScheme: ColorScheme.light(
      primary: OceanColors.lightBlue, secondary: OceanColors.lightCyan,
      tertiary: OceanColors.positive, error: OceanColors.negative,
      surface: OceanColors.lightSurface,
      surfaceContainerHighest: const Color(0xFFE0EFFF),
      onPrimary: Colors.white, onSecondary: Colors.white,
      onSurface: OceanColors.lightText, onSurfaceVariant: OceanColors.lightMuted,
    ),
    cardTheme: CardThemeData(color: Colors.white, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: OceanColors.lightBlue.withOpacity(0.15), width: 1))),
    appBarTheme: AppBarTheme(backgroundColor: Colors.white, elevation: 0,
      titleTextStyle: GoogleFonts.poppins(fontSize: 20,
          fontWeight: FontWeight.w700, color: OceanColors.lightText),
      iconTheme: const IconThemeData(color: OceanColors.lightText)),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: OceanColors.lightBlue.withOpacity(0.12),
      elevation: 8,
      labelTextStyle: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? GoogleFonts.poppins(fontSize: 10, color: OceanColors.lightBlue, fontWeight: FontWeight.w600)
              : GoogleFonts.poppins(fontSize: 10, color: OceanColors.lightMuted)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? OceanColors.lightBlue : OceanColors.lightMuted))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: OceanColors.lightSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: OceanColors.lightBlue.withOpacity(0.2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: OceanColors.lightBlue.withOpacity(0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OceanColors.lightBlue, width: 1.5)),
      hintStyle: const TextStyle(color: OceanColors.lightMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
    textTheme: TextTheme(
      headlineLarge:  GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: OceanColors.lightText),
      headlineMedium: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: OceanColors.lightText),
      titleLarge:     GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: OceanColors.lightText),
      titleMedium:    GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: OceanColors.lightText),
      bodyLarge:      GoogleFonts.poppins(fontSize: 15, color: OceanColors.lightText),
      bodyMedium:     GoogleFonts.poppins(fontSize: 13, color: OceanColors.lightMuted),
      bodySmall:      GoogleFonts.poppins(fontSize: 11, color: OceanColors.lightMuted),
      labelLarge:     GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: OceanColors.lightText),
    ),
    chipTheme: ChipThemeData(backgroundColor: OceanColors.lightSurface,
      selectedColor: OceanColors.lightBlue.withOpacity(0.15),
      side: BorderSide(color: OceanColors.lightBlue.withOpacity(0.2)),
      labelStyle: GoogleFonts.poppins(fontSize: 12, color: OceanColors.lightText),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    sliderTheme: const SliderThemeData(
      activeTrackColor: OceanColors.lightBlue, thumbColor: OceanColors.lightBlue,
      inactiveTrackColor: Color(0xFFCFDFF5)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: OceanColors.lightBlue),
  );
}
