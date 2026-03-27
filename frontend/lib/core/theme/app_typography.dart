import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppTypography implements an Apple-like SaaS design using the Inter font.
class AppTypography {
  static TextTheme get textTheme {
    return GoogleFonts.interTextTheme(
      const TextTheme(
        // Display / Page Heroes
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700, // 700 for headings
          letterSpacing: -1.0,
          height: 1.2,
        ),
        // Hero Balances
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        // Section Headings
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600, // 600 for sub-headings
          height: 1.3,
        ),
        // Card Titles
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600, 
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        // Body Text
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          height: 1.5,
        ),
        // Secondary Content
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        // Subtitle / Subtext
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        // Labels / Captions / Buttons
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
    );
  }
}
