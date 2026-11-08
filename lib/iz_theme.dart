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
      headlineLarge: editorial(base.textTheme.headlineLarge),
      headlineMedium: editorial(base.textTheme.headlineMedium),
      headlineSmall: editorial(base.textTheme.headlineSmall),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: colors.surfaceContainerLowest,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surfaceContainerLowest,
    ),
  );
}
