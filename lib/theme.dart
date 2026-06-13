import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildTheme() {
  // Fresh coastal palette with crisp typography for the customer app.
  const seed = Color(0xFF0E9ACD);
  final colorScheme =
      ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
  final textTheme = GoogleFonts.manropeTextTheme().copyWith(
    headlineLarge: GoogleFonts.spaceGrotesk(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: GoogleFonts.spaceGrotesk(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: GoogleFonts.spaceGrotesk(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF6FAFE),
    textTheme: textTheme,

    // AppBar: generous top navigation so back/actions remain easy to hit
    // across iPhone and iPad sizes.
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      toolbarHeight: 96,
      backgroundColor: const Color(0xFFF6FAFE),
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22),
      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 30),
      actionsIconTheme: IconThemeData(color: colorScheme.onSurface, size: 30),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(54),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

    // Buttons: rounded, high contrast labels
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        shadowColor: colorScheme.primary.withValues(alpha: 0.18),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 1.5,
        shadowColor: colorScheme.primary.withValues(alpha: 0.15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),

    // Inputs: pill-like, softly tinted fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Cards: glassy rounded blocks with subtle shadow
    cardTheme: CardThemeData(
      color: colorScheme.surface.withValues(alpha: 0.9),
      surfaceTintColor: Colors.transparent,
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),

    chipTheme: ChipThemeData(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor:
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      labelStyle: textTheme.labelMedium,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface.withValues(alpha: 0.95),
      elevation: 0,
      indicatorColor: colorScheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        );
      }),
      height: 72,
    ),

    // Subtle default page transitions
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
