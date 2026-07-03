import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFFCC6820);   // Claude orange

  static const _bg      = Color(0xFF111111);
  static const _surface = Color(0xFF1C1C1C);
  static const _card    = Color(0xFF242424);
  static const _border  = Color(0xFF2E2E2E);
  static const _muted   = Color(0xFF6B6B6B);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: Color(0xFFE8944A),
          surface: _surface,
          onSurface: Colors.white,
          onPrimary: Colors.white,
          surfaceContainerHighest: _card,
          error: Color(0xFFE05555),
        ),
        scaffoldBackgroundColor: _bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: _bg,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: _card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _border, width: 0.5),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: CircleBorder(),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintStyle: const TextStyle(color: _muted),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _surface,
          selectedItemColor: primary,
          unselectedItemColor: _muted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: _border, thickness: 0.5),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Color(0xFFAAAAAA)),
          bodySmall: TextStyle(color: _muted, fontSize: 12),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? primary : Colors.transparent),
          side: const BorderSide(color: _muted, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _card,
          selectedColor: primary.withAlpha(40),
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
          side: const BorderSide(color: _border, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _card,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      );
}
