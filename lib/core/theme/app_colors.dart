import 'package:flutter/material.dart';

import '../../features/tenant/domain/tenant.dart';

/// A complete colour palette derived from a tenant's three brand colours
/// (P1 / P2 / P3). Built once per tenant change and applied to [AppColors]
/// by the app shell.
class AppPalette {
  const AppPalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primaryFixed,
    required this.primaryFixedDim,
    required this.onPrimaryFixed,
    required this.onPrimaryFixedVariant,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.secondaryFixed,
    required this.secondaryFixedDim,
    required this.onSecondaryFixed,
    required this.onSecondaryFixedVariant,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.tertiaryFixed,
    required this.tertiaryFixedDim,
    required this.onTertiaryFixed,
    required this.onTertiaryFixedVariant,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.surfaceBright,
    required this.surfaceDim,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.surfaceTint,
    required this.inverseSurface,
    required this.inverseOnSurface,
    required this.inversePrimary,
    required this.outline,
    required this.outlineVariant,
    required this.cardShadow,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color primaryFixed;
  final Color primaryFixedDim;
  final Color onPrimaryFixed;
  final Color onPrimaryFixedVariant;

  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color secondaryFixed;
  final Color secondaryFixedDim;
  final Color onSecondaryFixed;
  final Color onSecondaryFixedVariant;

  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color tertiaryFixed;
  final Color tertiaryFixedDim;
  final Color onTertiaryFixed;
  final Color onTertiaryFixedVariant;

  final Color background;
  final Color onBackground;
  final Color surface;
  final Color surfaceBright;
  final Color surfaceDim;
  final Color surfaceVariant;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color surfaceTint;
  final Color inverseSurface;
  final Color inverseOnSurface;
  final Color inversePrimary;

  final Color outline;
  final Color outlineVariant;

  final Color cardShadow;

  /// Derive a full palette from a tenant's three brand colours.
  ///
  /// Mapping:
  ///  - P1 (e.g. white)       -> surface/background stack + on-primary inks
  ///  - P2 (e.g. dark navy)   -> primary + navy aliases + inverse surface
  ///  - P3 (e.g. light blue)  -> secondary + accents + fixed/dim variants
  /// Everything else is derived by tinting or lightness adjustments.
  factory AppPalette.fromTenant(Tenant t) {
    final p1 = t.colorP1;
    final p2 = t.colorP2;
    final p3 = t.colorP3;

    // Helpers — operate in HSL for predictable lightness math.
    Color lighten(Color c, double amount) =>
        HSLColor.fromColor(c).withLightness(
              (HSLColor.fromColor(c).lightness + amount).clamp(0.0, 1.0),
            ).toColor();
    Color darken(Color c, double amount) =>
        HSLColor.fromColor(c).withLightness(
              (HSLColor.fromColor(c).lightness - amount).clamp(0.0, 1.0),
            ).toColor();
    Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

    // Surface stack — anchored on P1, tinted very slightly toward P2 as
    // we go up the elevation ladder.
    final surface = p1;
    final surfaceContainerLowest = p1;
    final surfaceContainerLow = mix(p1, p3, 0.04);
    final surfaceContainer = mix(p1, p3, 0.08);
    final surfaceContainerHigh = mix(p1, p3, 0.13);
    final surfaceContainerHighest = mix(p1, p3, 0.18);
    final surfaceVariant = mix(p1, p3, 0.18);
    final surfaceBright = p1;
    final surfaceDim = mix(p1, p3, 0.20);
    final background = p1;

    // Inks — derived from P2 (the primary brand).
    final onSurface = mix(p2, Colors.black, 0.0);
    final onSurfaceVariant = lighten(p2, 0.20);
    final onBackground = onSurface;
    final outline = mix(p2, Colors.white, 0.55);
    final outlineVariant = mix(p2, Colors.white, 0.80);

    return AppPalette(
      // Primary cluster -> P2
      primary: p2,
      onPrimary: p1,
      primaryContainer: lighten(p2, 0.10),
      onPrimaryContainer: mix(p2, Colors.white, 0.45),
      primaryFixed: mix(p2, Colors.white, 0.82),
      primaryFixedDim: mix(p2, Colors.white, 0.66),
      onPrimaryFixed: darken(p2, 0.05),
      onPrimaryFixedVariant: mix(p2, Colors.white, 0.30),

      // Secondary cluster -> P3
      secondary: p3,
      onSecondary: p1,
      secondaryContainer: lighten(p3, 0.05),
      onSecondaryContainer: darken(p2, 0.05),
      secondaryFixed: mix(p3, Colors.white, 0.55),
      secondaryFixedDim: mix(p3, Colors.white, 0.35),
      onSecondaryFixed: darken(p2, 0.10),
      onSecondaryFixedVariant: mix(p2, Colors.white, 0.15),

      // Tertiary cluster -> deep success/accent green (independent of tenant).
      // Held constant so success states stay readable across any branding.
      tertiary: const Color(0xFF001C10),
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: const Color(0xFF003320),
      onTertiaryContainer: const Color(0xFF00A774),
      tertiaryFixed: const Color(0xFF6FFBBE),
      tertiaryFixedDim: const Color(0xFF4EDEA3),
      onTertiaryFixed: const Color(0xFF002113),
      onTertiaryFixedVariant: const Color(0xFF005236),

      // Surface stack
      background: background,
      onBackground: onBackground,
      surface: surface,
      surfaceBright: surfaceBright,
      surfaceDim: surfaceDim,
      surfaceVariant: surfaceVariant,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      surfaceTint: mix(p2, Colors.white, 0.40),
      inverseSurface: darken(p2, 0.05),
      inverseOnSurface: mix(p1, p3, 0.05),
      inversePrimary: mix(p2, Colors.white, 0.55),

      // Outline / lines
      outline: outline,
      outlineVariant: outlineVariant,

      cardShadow: p2.withValues(alpha: 0.05),
    );
  }

  /// Built-in default — TCB Infotech's brand. Used before any tenant resolves
  /// (fresh install, first launch).
  static final tcbDefault = AppPalette.fromTenant(Tenant.tcbDefault);
}

/// Globally-readable colour tokens for the app.
///
/// Each field is a mutable static, updated via [apply] when the active tenant
/// changes. The owning `MaterialApp` rebuilds whenever the tenant changes,
/// which in turn re-reads these values during the build pass — so the visual
/// switch is atomic from the user's point of view.
///
/// Fixed colours (error, warning, success) are independent of the tenant —
/// they need to mean the same thing regardless of branding.
class AppColors {
  AppColors._();

  // Primary cluster (P2-derived)
  static Color primary = AppPalette.tcbDefault.primary;
  static Color onPrimary = AppPalette.tcbDefault.onPrimary;
  static Color primaryContainer = AppPalette.tcbDefault.primaryContainer;
  static Color onPrimaryContainer = AppPalette.tcbDefault.onPrimaryContainer;
  static Color primaryFixed = AppPalette.tcbDefault.primaryFixed;
  static Color primaryFixedDim = AppPalette.tcbDefault.primaryFixedDim;
  static Color onPrimaryFixed = AppPalette.tcbDefault.onPrimaryFixed;
  static Color onPrimaryFixedVariant =
      AppPalette.tcbDefault.onPrimaryFixedVariant;

  // Secondary cluster (P3-derived)
  static Color secondary = AppPalette.tcbDefault.secondary;
  static Color onSecondary = AppPalette.tcbDefault.onSecondary;
  static Color secondaryContainer = AppPalette.tcbDefault.secondaryContainer;
  static Color onSecondaryContainer =
      AppPalette.tcbDefault.onSecondaryContainer;
  static Color secondaryFixed = AppPalette.tcbDefault.secondaryFixed;
  static Color secondaryFixedDim = AppPalette.tcbDefault.secondaryFixedDim;
  static Color onSecondaryFixed = AppPalette.tcbDefault.onSecondaryFixed;
  static Color onSecondaryFixedVariant =
      AppPalette.tcbDefault.onSecondaryFixedVariant;

  // Tertiary cluster (fixed, brand-independent)
  static Color tertiary = AppPalette.tcbDefault.tertiary;
  static Color onTertiary = AppPalette.tcbDefault.onTertiary;
  static Color tertiaryContainer = AppPalette.tcbDefault.tertiaryContainer;
  static Color onTertiaryContainer = AppPalette.tcbDefault.onTertiaryContainer;
  static Color tertiaryFixed = AppPalette.tcbDefault.tertiaryFixed;
  static Color tertiaryFixedDim = AppPalette.tcbDefault.tertiaryFixedDim;
  static Color onTertiaryFixed = AppPalette.tcbDefault.onTertiaryFixed;
  static Color onTertiaryFixedVariant =
      AppPalette.tcbDefault.onTertiaryFixedVariant;

  // Surface stack
  static Color background = AppPalette.tcbDefault.background;
  static Color onBackground = AppPalette.tcbDefault.onBackground;
  static Color surface = AppPalette.tcbDefault.surface;
  static Color surfaceBright = AppPalette.tcbDefault.surfaceBright;
  static Color surfaceDim = AppPalette.tcbDefault.surfaceDim;
  static Color surfaceVariant = AppPalette.tcbDefault.surfaceVariant;
  static Color onSurface = AppPalette.tcbDefault.onSurface;
  static Color onSurfaceVariant = AppPalette.tcbDefault.onSurfaceVariant;
  static Color surfaceContainerLowest =
      AppPalette.tcbDefault.surfaceContainerLowest;
  static Color surfaceContainerLow = AppPalette.tcbDefault.surfaceContainerLow;
  static Color surfaceContainer = AppPalette.tcbDefault.surfaceContainer;
  static Color surfaceContainerHigh = AppPalette.tcbDefault.surfaceContainerHigh;
  static Color surfaceContainerHighest =
      AppPalette.tcbDefault.surfaceContainerHighest;
  static Color surfaceTint = AppPalette.tcbDefault.surfaceTint;
  static Color inverseSurface = AppPalette.tcbDefault.inverseSurface;
  static Color inverseOnSurface = AppPalette.tcbDefault.inverseOnSurface;
  static Color inversePrimary = AppPalette.tcbDefault.inversePrimary;

  // Outline / lines
  static Color outline = AppPalette.tcbDefault.outline;
  static Color outlineVariant = AppPalette.tcbDefault.outlineVariant;

  // Fixed brand-independent colours
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color warning = Color(0xFFB54708);

  // Card shadow (tinted by primary)
  static Color cardShadow = AppPalette.tcbDefault.cardShadow;

  // ---- Convenience aliases used widely across the codebase ----
  // Kept for backward compatibility with screens written before P1/P2/P3.
  static Color get navy => primary;
  static Color get canvas => background;
  static Color get navyTint => secondaryFixed;
  static Color get navyTintStrong => primaryFixedDim;
  static Color get ink => onSurface;
  static Color get inkMuted => onSurfaceVariant;
  static Color get inkFaint => outline;
  static Color get line => outlineVariant;
  static Color get danger => error;
  static Color get success => onTertiaryContainer;
  static Color get navy90 => onPrimaryFixedVariant;
  static Color get surfaceMuted => surfaceContainerLow;

  /// Swap the active palette. Called from the app shell whenever the
  /// resolved tenant changes. The MaterialApp rebuild that follows will
  /// re-read all values during build().
  static void apply(AppPalette p) {
    primary = p.primary;
    onPrimary = p.onPrimary;
    primaryContainer = p.primaryContainer;
    onPrimaryContainer = p.onPrimaryContainer;
    primaryFixed = p.primaryFixed;
    primaryFixedDim = p.primaryFixedDim;
    onPrimaryFixed = p.onPrimaryFixed;
    onPrimaryFixedVariant = p.onPrimaryFixedVariant;

    secondary = p.secondary;
    onSecondary = p.onSecondary;
    secondaryContainer = p.secondaryContainer;
    onSecondaryContainer = p.onSecondaryContainer;
    secondaryFixed = p.secondaryFixed;
    secondaryFixedDim = p.secondaryFixedDim;
    onSecondaryFixed = p.onSecondaryFixed;
    onSecondaryFixedVariant = p.onSecondaryFixedVariant;

    tertiary = p.tertiary;
    onTertiary = p.onTertiary;
    tertiaryContainer = p.tertiaryContainer;
    onTertiaryContainer = p.onTertiaryContainer;
    tertiaryFixed = p.tertiaryFixed;
    tertiaryFixedDim = p.tertiaryFixedDim;
    onTertiaryFixed = p.onTertiaryFixed;
    onTertiaryFixedVariant = p.onTertiaryFixedVariant;

    background = p.background;
    onBackground = p.onBackground;
    surface = p.surface;
    surfaceBright = p.surfaceBright;
    surfaceDim = p.surfaceDim;
    surfaceVariant = p.surfaceVariant;
    onSurface = p.onSurface;
    onSurfaceVariant = p.onSurfaceVariant;
    surfaceContainerLowest = p.surfaceContainerLowest;
    surfaceContainerLow = p.surfaceContainerLow;
    surfaceContainer = p.surfaceContainer;
    surfaceContainerHigh = p.surfaceContainerHigh;
    surfaceContainerHighest = p.surfaceContainerHighest;
    surfaceTint = p.surfaceTint;
    inverseSurface = p.inverseSurface;
    inverseOnSurface = p.inverseOnSurface;
    inversePrimary = p.inversePrimary;

    outline = p.outline;
    outlineVariant = p.outlineVariant;

    cardShadow = p.cardShadow;
  }
}
