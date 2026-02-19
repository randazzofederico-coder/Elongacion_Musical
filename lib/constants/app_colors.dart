import 'package:flutter/material.dart';

class AppColors {
  // Main Backgrounds
  static const Color background = Color(0xFF121212); // Deep dark background
  static const Color surface = Color(0xFF1E1E1E);    // Panel/Module background
  static const Color surfaceHighlight = Color(0xFF2A2A2A); // Slightly lighter panel

  // Accents
  static const Color accentCyan = Colors.cyanAccent;
  static const Color accentRed = Colors.redAccent;
  static const Color accentAmber = Colors.amber;

  // UI Elements
  static const Color border = Color(0xFF333333);
  static const Color textPrimary = Colors.white70;
  static const Color textSecondary = Colors.white38;

  // Control Specific
  static const Color faderTrack = Colors.black45;
  static const Color knobFill = Color(0xFF222222);
  
  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFB74D);
  
  // Aliases for compatibility
  static const Color primary = accentCyan;
  static const Color divider = border;
}
