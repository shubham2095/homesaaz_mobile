// lib/app/theme.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Gentle fade + rise transition used for every pushed route, replacing the
/// stock Android "fade through" with something a touch softer/branded.
class _HsPageTransitionsBuilder extends PageTransitionsBuilder {
  const _HsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Hs.curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// HomeSaaz theme — Inter type, signature yellow ground, blue primary
/// actions, red brand accent. Tuned for tight, consistent spacing.
ThemeData buildTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;

  final scheme =
      ColorScheme.fromSeed(seedColor: Hs.blue, brightness: brightness).copyWith(
        primary: Hs.blue,
        error: Hs.red,
        surface: isLight ? Hs.surface : null,
      );

  final base = ThemeData(brightness: brightness);
  final text = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    titleLarge: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: Hs.ink,
      height: 1.2,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Hs.ink,
    ),
    bodyMedium: GoogleFonts.inter(fontSize: 14, height: 1.4, color: Hs.inkSoft),
    bodySmall: GoogleFonts.inter(fontSize: 12.5, color: Hs.muted),
    labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: isLight ? Hs.yellow : null,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _HsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      backgroundColor: isLight ? Hs.surface : scheme.surface,
      foregroundColor: isLight ? Hs.ink : scheme.onSurface,
      titleTextStyle: GoogleFonts.inter(
        color: isLight ? Hs.ink : scheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      shape: const Border(bottom: BorderSide(color: Hs.yellowBorder, width: 2)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: isLight ? Hs.surface : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Hs.radius),
        side: BorderSide(color: isLight ? Hs.border : scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: isLight ? Hs.surface : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: const TextStyle(color: Hs.faint, fontWeight: FontWeight.w400),
      labelStyle: const TextStyle(color: Hs.muted),
      floatingLabelStyle: const TextStyle(color: Hs.blue),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        borderSide: const BorderSide(color: Hs.border),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        borderSide: const BorderSide(color: Hs.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        borderSide: const BorderSide(color: Hs.blue, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Hs.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Hs.radiusSm),
        ),
      ).copyWith(overlayColor: WidgetStateProperty.all(Colors.white24)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Hs.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Hs.blue,
        side: const BorderSide(color: Hs.blue),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Hs.radiusSm),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Hs.blue,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Hs.blue,
      strokeWidth: 2.6,
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      backgroundColor: Hs.surface,
      selectedColor: Hs.blue.withValues(alpha: .12),
      side: const BorderSide(color: Hs.border),
      labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Hs.radiusSm),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Hs.hairline, space: 1),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      titleTextStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Hs.ink,
      ),
      subtitleTextStyle: TextStyle(fontSize: 13, color: Hs.muted, height: 1.35),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Hs.surface : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Hs.radiusSm),
          borderSide: const BorderSide(color: Hs.border),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Hs.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Hs.radiusSm),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Hs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Hs.radiusLg)),
      ),
    ),
  );
}
