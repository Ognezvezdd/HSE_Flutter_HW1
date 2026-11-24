import 'package:flutter/material.dart';

ThemeData createAppTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xFF176B60),
    primary: const Color(0xFF176B60),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFDFEEE7),
    onPrimaryContainer: const Color(0xFF184C44),
    secondary: const Color(0xFFA64E3C),
    secondaryContainer: const Color(0xFFFFE5DA),
    surface: const Color(0xFFFFFDFA),
    onSurface: const Color(0xFF203B35),
    onSurfaceVariant: const Color(0xFF586C65),
    outlineVariant: const Color(0xFFDCE5DE),
  );
  final base = ThemeData(colorScheme: colors, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF6F5F0),
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 27,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 23,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF6F5F0),
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: colors.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: BorderSide(color: colors.outlineVariant),
        backgroundColor: colors.surface,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.primary,
      unselectedLabelColor: colors.onSurfaceVariant,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      dividerColor: colors.outlineVariant,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1),
  );
}
