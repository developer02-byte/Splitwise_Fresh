import 'package:flutter/material.dart';

/// AppColors define the raw, semantic color palette matching an Apple-style SaaS.
class AppColors {
  // Brand - Clean and strong Deep Purple / Indigo
  static const Color primary500 = Color(0xFF5E5CE6); // Apple-like primary
  
  // Semantic
  static const Color success = Color(0xFF34C759); // Apple Green
  static const Color warning = Color(0xFFFF9F0A); // Apple Amber
  static const Color error = Color(0xFFFF3B30);   // Apple Red
  
  // Neutral - Light Mode
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color textPrimaryLight = Color(0xFF111827); // High contrast
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // Neutral - Dark Mode
  static const Color backgroundDark = Color(0xFF0F172A); // Deep cool black/blue
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // High contrast
  static const Color textSecondaryDark = Color(0xFF94A3B8);
}
