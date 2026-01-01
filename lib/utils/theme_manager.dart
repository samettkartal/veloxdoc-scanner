import 'package:flutter/material.dart';

class ThemeManager extends ValueNotifier<bool> {
  // Singleton
  static final ThemeManager instance = ThemeManager._();
  
  ThemeManager._() : super(false); // Default: Light Mode (false)

  bool get isDarkMode => value;

  void toggleTheme() {
    value = !value;
  }
}
