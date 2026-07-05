import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ---------------------------------------------------------------------------
/// WashDesk design tokens.
///
/// One source of truth for color, spacing, radius and type. Screens and
/// widgets import these instead of inventing values, so the app stays
/// coherent as it grows. Change a token here, the whole app follows.
/// ---------------------------------------------------------------------------
class Wd {
  Wd._();

  // --- Color -----------------------------------------------------------
  /// Deep water blue. The single brand accent — used for primary actions,
  /// selected states and key figures. Everything else stays quiet.
  static const Color primary = Color(0xFF0C7BA1);
  static const Color primaryDeep = Color(0xFF085E7D);
  static const Color primarySoft = Color(0xFFE4F2F8); // tinted chips/surfaces

  /// Ink scale for text.
  static const Color ink = Color(0xFF10222E); // headings, figures
  static const Color inkMuted = Color(0xFF5A6B76); // labels, captions
  static const Color inkFaint = Color(0xFF93A2AC); // hints, disabled

  /// Surfaces.
  static const Color canvas = Color(0xFFF4F8FB); // page background
  static const Color surface = Colors.white; // cards
  static const Color border = Color(0xFFE2EAEF); // hairline card borders

  /// Semantic (used sparingly).
  static const Color success = Color(0xFF1B8A5A);
  static const Color successSoft = Color(0xFFE4F4EC);
  static const Color warning = Color(0xFFB7791F);
  static const Color warningSoft = Color(0xFFFAF0DD);
  static const Color danger = Color(0xFFC2413B);
  static const Color dangerSoft = Color(0xFFFAE7E6);

  // --- Spacing (4pt grid) ------------------------------------------------
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;

  /// Standard page gutter.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: 18);

  // --- Radius ------------------------------------------------------------
  /// One radius family. Cards 20, controls 14, chips 10.
  static const double rCard = 20;
  static const double rControl = 14;
  static const double rChip = 10;

  static final BorderRadius cardRadius = BorderRadius.circular(rCard);
  static final BorderRadius controlRadius = BorderRadius.circular(rControl);
  static final BorderRadius chipRadius = BorderRadius.circular(rChip);

  // --- Elevation -----------------------------------------------------------
  /// Cards sit on a hairline border + one soft ambient shadow. No stacking
  /// of elevations; hierarchy comes from tint and type, not shadow depth.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0C7BA1).withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  /// Money and counts always use tabular figures so columns line up.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];
}

ThemeData buildTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Wd.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: Wd.primary,
    onPrimary: Colors.white,
    primaryContainer: Wd.primarySoft,
    onPrimaryContainer: Wd.primaryDeep,
    surface: Wd.surface,
    onSurface: Wd.ink,
    onSurfaceVariant: Wd.inkMuted,
    outlineVariant: Wd.border,
    error: Wd.danger,
  );

  // Manrope for reading, Space Grotesk for display and figures.
  final body = GoogleFonts.manropeTextTheme();
  TextStyle display(double size, {FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: Wd.ink,
        height: 1.15,
        letterSpacing: -0.3,
      );

  final textTheme = body.copyWith(
    displaySmall: display(34),
    headlineLarge: display(30),
    headlineMedium: display(26),
    headlineSmall: display(22),
    titleLarge: display(20),
    titleMedium: GoogleFonts.manrope(
        fontSize: 16, fontWeight: FontWeight.w700, color: Wd.ink),
    titleSmall: GoogleFonts.manrope(
        fontSize: 14, fontWeight: FontWeight.w700, color: Wd.ink),
    bodyLarge:
        GoogleFonts.manrope(fontSize: 16, color: Wd.ink, height: 1.45),
    bodyMedium:
        GoogleFonts.manrope(fontSize: 14, color: Wd.ink, height: 1.45),
    bodySmall: GoogleFonts.manrope(
        fontSize: 12.5, color: Wd.inkMuted, height: 1.4),
    labelLarge: GoogleFonts.manrope(
        fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1),
    labelMedium: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Wd.inkMuted,
        letterSpacing: 0.1),
    labelSmall: GoogleFonts.manrope(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: Wd.inkFaint,
        letterSpacing: 0.2),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Wd.canvas,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,

    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      toolbarHeight: 84,
      backgroundColor: Wd.canvas,
      foregroundColor: Wd.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: display(21),
      iconTheme: const IconThemeData(color: Wd.ink, size: 26),
      actionsIconTheme: const IconThemeData(color: Wd.ink, size: 26),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Wd.primary,
        foregroundColor: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: Wd.s5, vertical: Wd.s4),
        shape: RoundedRectangleBorder(borderRadius: Wd.controlRadius),
        elevation: 0,
        textStyle: textTheme.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Wd.surface,
        foregroundColor: Wd.primaryDeep,
        padding:
            const EdgeInsets.symmetric(horizontal: Wd.s4, vertical: Wd.s3),
        shape: RoundedRectangleBorder(
          borderRadius: Wd.controlRadius,
          side: const BorderSide(color: Wd.border),
        ),
        elevation: 0,
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Wd.primaryDeep,
        padding:
            const EdgeInsets.symmetric(horizontal: Wd.s4, vertical: Wd.s3),
        shape: RoundedRectangleBorder(borderRadius: Wd.controlRadius),
        side: const BorderSide(color: Wd.border),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Wd.primaryDeep,
        textStyle: textTheme.labelLarge,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Wd.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Wd.s4, vertical: Wd.s4),
      border: OutlineInputBorder(
        borderRadius: Wd.controlRadius,
        borderSide: const BorderSide(color: Wd.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: Wd.controlRadius,
        borderSide: const BorderSide(color: Wd.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: Wd.controlRadius,
        borderSide: const BorderSide(color: Wd.primary, width: 1.6),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(color: Wd.inkMuted),
      hintStyle: textTheme.bodyMedium?.copyWith(color: Wd.inkFaint),
      floatingLabelStyle: textTheme.labelMedium?.copyWith(color: Wd.primary),
    ),

    cardTheme: CardThemeData(
      color: Wd.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: Wd.s2),
      shape: RoundedRectangleBorder(
        borderRadius: Wd.cardRadius,
        side: const BorderSide(color: Wd.border),
      ),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: Wd.primary,
      shape: RoundedRectangleBorder(borderRadius: Wd.cardRadius),
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: Wd.s4),
    ),

    chipTheme: ChipThemeData(
      padding: const EdgeInsets.symmetric(horizontal: Wd.s3, vertical: Wd.s2),
      shape: RoundedRectangleBorder(
        borderRadius: Wd.chipRadius,
        side: BorderSide.none,
      ),
      backgroundColor: Wd.primarySoft,
      selectedColor: Wd.primary,
      labelStyle: textTheme.labelMedium?.copyWith(color: Wd.primaryDeep),
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: Colors.white),
    ),

    dividerTheme: const DividerThemeData(color: Wd.border, thickness: 1),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Wd.ink,
      contentTextStyle:
          textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: Wd.controlRadius),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Wd.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: Wd.cardRadius),
      extendedTextStyle: textTheme.labelLarge,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Wd.surface.withValues(alpha: 0.96),
      elevation: 0,
      indicatorColor: Wd.primarySoft,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          color: selected ? Wd.primaryDeep : Wd.inkMuted,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
            color: selected ? Wd.primaryDeep : Wd.inkMuted);
      }),
    ),

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
