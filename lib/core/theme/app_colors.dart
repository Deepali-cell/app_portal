import 'package:flutter/material.dart';

/// Material 3 tonal palette for the TCB Employee Portal, derived around the
/// brand navy (#031635). Light-mode only — every colour below is tuned for a
/// light surface stack; we never switch to dark.
class AppColors {
  AppColors._();

  // Primary / on-primary
  static const Color primary = Color(0xFF031635);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF1A2B4B);
  static const Color onPrimaryContainer = Color(0xFF8293B8);
  static const Color primaryFixed = Color(0xFFD8E2FF);
  static const Color primaryFixedDim = Color(0xFFB6C6EF);
  static const Color onPrimaryFixed = Color(0xFF081B3A);
  static const Color onPrimaryFixedVariant = Color(0xFF364768);

  // Secondary / on-secondary
  static const Color secondary = Color(0xFF0058BE);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF2170E4);
  static const Color onSecondaryContainer = Color(0xFFFEFCFF);
  static const Color secondaryFixed = Color(0xFFD8E2FF);
  static const Color secondaryFixedDim = Color(0xFFADC6FF);
  static const Color onSecondaryFixed = Color(0xFF001A42);
  static const Color onSecondaryFixedVariant = Color(0xFF004395);

  // Tertiary (accent / success-leaning)
  static const Color tertiary = Color(0xFF001C10);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF003320);
  static const Color onTertiaryContainer = Color(0xFF00A774);
  static const Color tertiaryFixed = Color(0xFF6FFBBE);
  static const Color tertiaryFixedDim = Color(0xFF4EDEA3);
  static const Color onTertiaryFixed = Color(0xFF002113);
  static const Color onTertiaryFixedVariant = Color(0xFF005236);

  // Surface stack
  static const Color background = Color(0xFFF8F9FF);
  static const Color onBackground = Color(0xFF0B1C30);
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceBright = Color(0xFFF8F9FF);
  static const Color surfaceDim = Color(0xFFCBDBF5);
  static const Color surfaceVariant = Color(0xFFD3E4FE);
  static const Color onSurface = Color(0xFF0B1C30);
  static const Color onSurfaceVariant = Color(0xFF44474E);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE5EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color surfaceContainerHighest = Color(0xFFD3E4FE);
  static const Color surfaceTint = Color(0xFF4E5E81);
  static const Color inverseSurface = Color(0xFF213145);
  static const Color inverseOnSurface = Color(0xFFEAF1FF);
  static const Color inversePrimary = Color(0xFFB6C6EF);

  // Outline / lines
  static const Color outline = Color(0xFF75777F);
  static const Color outlineVariant = Color(0xFFC5C6CF);

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Soft elevation shadow used across cards/sheets — matches the mockups.
  static const Color cardShadow = Color(0x0D1A2B4B); // rgba(26,43,75,0.05)

  // ---- Convenience aliases used widely across the existing codebase ----
  // Existing screens reference these names; we keep them as semantic
  // shortcuts into the M3 palette so old code keeps compiling.
  static const Color navy = primary;
  static const Color canvas = background;
  static const Color navyTint = secondaryFixed;
  static const Color navyTintStrong = primaryFixedDim;
  static const Color ink = onSurface;
  static const Color inkMuted = onSurfaceVariant;
  static const Color inkFaint = outline;
  static const Color line = outlineVariant;
  static const Color danger = error;
  static const Color success = onTertiaryContainer;
  static const Color warning = Color(0xFFB54708);
  static const Color navy90 = onPrimaryFixedVariant;
  static const Color surfaceMuted = surfaceContainerLow;
}
