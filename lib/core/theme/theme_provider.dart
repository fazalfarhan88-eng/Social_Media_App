import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = "theme_mode";
  static const String _colorKey = "primary_color";
  
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = const Color(0xFF6366F1); // Default Indigo

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, _themeMode.index);
  }

  void setPrimaryColor(Color color) async {
    _primaryColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, color.value);
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Theme Mode
    final savedMode = prefs.getInt(_themeKey);
    if (savedMode != null) {
      _themeMode = ThemeMode.values[savedMode];
    }
    
    // Load Primary Color
    final savedColor = prefs.getInt(_colorKey);
    if (savedColor != null) {
      _primaryColor = Color(savedColor);
    }
    
    notifyListeners();
  }
}
