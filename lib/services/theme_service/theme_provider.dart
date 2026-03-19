import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  static const String _key = "theme_mode";

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_key, mode.index);
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModeIndex = prefs.getInt(_key);
    if (savedModeIndex != null) {
      _themeMode = ThemeMode.values[savedModeIndex];
      notifyListeners();
    }
  }
}
