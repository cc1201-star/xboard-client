import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides the dynamic sidebar/primary color used throughout the app.
/// The panel sets CSS variables from sidebar_color; we do the same in Flutter.
class ThemeColorNotifier extends StateNotifier<Color> {
  ThemeColorNotifier() : super(const Color(0xFF1E293B)) {
    _load();
  }

  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    final hex = prefs.getString('sidebar_color');
    if (hex != null && hex.startsWith('#') && hex.length == 7) {
      final v = int.tryParse(hex.substring(1), radix: 16);
      if (v != null) state = Color(0xFF000000 | v);
    }
  }

  Future<void> _load() => reload();

  Future<void> setColor(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    final hex = '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    await prefs.setString('sidebar_color', hex);
  }
}

final themeColorProvider = StateNotifierProvider<ThemeColorNotifier, Color>((ref) {
  return ThemeColorNotifier();
});
