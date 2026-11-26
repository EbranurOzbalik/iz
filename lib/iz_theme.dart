import 'package:flutter/material.dart';

ThemeData izTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xff755397),
    brightness: brightness,
    surface: dark ? const Color(0xff1c1b20) : const Color(0xfffaf8f5),
    primary: dark ? const Color(0xffc3a5e5) : const Color(0xff755397),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: colors);
  TextStyle? editorial(TextStyle? style) => style?.copyWith(
    fontFamily: 'Georgia',
    fontFamilyFallback: ['Times New Roman', 'serif'],
    fontWeight: FontWeight.w400,
  );
  return base.copyWith(
    scaffoldBackgroundColor: colors.surface,
    textTheme: base.textTheme.copyWith(
      headlineLarge: editorial(
        base.textTheme.headlineLarge,
      )?.copyWith(height: 1.08, letterSpacing: -.5),
      headlineMedium: editorial(
        base.textTheme.headlineMedium,
      )?.copyWith(height: 1.12, letterSpacing: -.35),
      headlineSmall: editorial(
        base.textTheme.headlineSmall,
      )?.copyWith(height: 1.18),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.25,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 20,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.primary, width: 1.8),
      ),
      filled: true,
      fillColor: colors.surfaceContainerLowest.withValues(alpha: .78),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide(color: colors.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      labelStyle: base.textTheme.labelLarge,
      selectedColor: colors.primaryContainer,
      checkmarkColor: colors.onPrimaryContainer,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      elevation: 0,
      indicatorColor: colors.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => base.textTheme.labelMedium?.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? colors.onSurface
              : colors.onSurfaceVariant,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1),
  );
}
