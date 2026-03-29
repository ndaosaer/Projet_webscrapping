import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'isDarkMode';
  bool _isDarkMode = true;
  late SharedPreferences _prefs;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs.getBool(_themeKey) ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  ThemeData get theme => _isDarkMode ? _darkTheme : _lightTheme;

  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF00E5A0),
      secondary: const Color(0xFF4A9EFF),
      surface: const Color(0xFF111318),
      surfaceContainerHighest: const Color(0xFF0A0C10),
      error: const Color(0xFFFF6B4A),
    ),
    scaffoldBackgroundColor: const Color(0xFF0A0C10),
    cardTheme: CardThemeData(
      color: const Color(0xFF111318),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E2330), width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A0C10),
      elevation: 0,
    ),
  );

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF00C17D),
      secondary: const Color(0xFF2E7FE8),
      surface: Colors.white,
      surfaceContainerHighest: const Color(0xFFF5F7FA),
      error: const Color(0xFFE63946),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: Colors.black87,
    ),
  );
}
