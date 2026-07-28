import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// --- ECORA DESIGN SYSTEM ---
// Unica fonte di verità per colori, tipografia, spaziature, raggi e
// movimento. Specifica: docs/ecora-design-system.html (Blocco B.1).
// Le schermate si migrano ai token qui sotto una alla volta (blocchi C/D).

/// Palette del design system v1 (canvas near-black + oro champagne).
abstract class EcoraColors {
  static const Color canvas = Color(0xFF0E0E11);
  static const Color surface = Color(0xFF17171B);
  static const Color elevated = Color(0xFF1F1F25);
  static const Color hairline = Color(0x12FFFFFF); // rgba(255,255,255,.07)
  static const Color hairlineStrong = Color(0x1FFFFFFF); // rgba(255,255,255,.12)

  static const Color gold = Color(0xFFC9A96A);
  static const Color goldBright = Color(0xFFE6CD97);
  static const Color goldDeep = Color(0xFF8A7343);

  static const Color textPrimary = Color(0xFFF4F1EB);
  static const Color textSecondary = Color(0xFFA19C93);
  static const Color textTertiary = Color(0xFF6F6A62);

  static const Color success = Color(0xFF5BA871);
  static const Color danger = Color(0xFFE0605C);
  static const Color warning = Color(0xFFDDA65A);
}

/// Griglia spaziature da 4pt.
abstract class EcoraSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s56 = 56;
}

/// Raggi: uno per ruolo, non per gusto.
abstract class EcoraRadius {
  static const double control = 8;
  static const double card = 12;
  static const double sheet = 20;
  static const double pill = 999;
}

/// Durate e curve del movimento.
abstract class EcoraMotion {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration enter = Duration(milliseconds: 320);
  static const Duration celebrate = Duration(milliseconds: 520);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve celebrateCurve = Curves.easeOutBack;
}

const String _kDisplayFont = 'EcoraDisplay';
const String _kUiFont = 'EcoraUI';

/// Scala tipografica: displayLarge è l'unico uso lecito del logo/brand.
/// Nessun valore sotto i 12px.
const TextTheme _ecoraTextThemeBase = TextTheme(
  displayLarge: TextStyle(
    fontFamily: _kDisplayFont,
    fontSize: 40,
    height: 46 / 40,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: EcoraColors.textPrimary,
  ),
  displayMedium: TextStyle(
    fontFamily: _kDisplayFont,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w600,
    color: EcoraColors.textPrimary,
  ),
  titleLarge: TextStyle(
    fontFamily: _kDisplayFont,
    fontSize: 19,
    height: 25 / 19,
    fontWeight: FontWeight.w600,
    color: EcoraColors.textPrimary,
  ),
  labelSmall: TextStyle(
    fontFamily: _kUiFont,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: EcoraColors.gold,
  ),
  bodyLarge: TextStyle(
    fontFamily: _kUiFont,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: EcoraColors.textPrimary,
  ),
  bodyMedium: TextStyle(
    fontFamily: _kUiFont,
    fontSize: 14,
    height: 21 / 14,
    fontWeight: FontWeight.w400,
    color: EcoraColors.textSecondary,
  ),
  bodySmall: TextStyle(
    fontFamily: _kUiFont,
    fontSize: 12,
    height: 17 / 12,
    fontWeight: FontWeight.w500,
    color: EcoraColors.textTertiary,
  ),
);

final TextTheme ecoraTextTheme = _ecoraTextThemeBase.apply(fontFamily: _kUiFont);

/// `ThemeData` completo del design system. Le schermate leggono gli stili
/// da `Theme.of(context)` invece di stilizzare a mano.
ThemeData ecoraTheme() {
  const colorScheme = ColorScheme.dark(
    primary: EcoraColors.gold,
    onPrimary: EcoraColors.canvas,
    secondary: EcoraColors.goldDeep,
    onSecondary: EcoraColors.textPrimary,
    surface: EcoraColors.surface,
    onSurface: EcoraColors.textPrimary,
    error: EcoraColors.danger,
    onError: EcoraColors.canvas,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: EcoraColors.canvas,
    fontFamily: _kUiFont,
    textTheme: ecoraTextTheme,
    dividerColor: EcoraColors.hairline,
    dividerTheme: const DividerThemeData(
      color: EcoraColors.hairline,
      thickness: 1,
      space: 1,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    cardTheme: CardThemeData(
      color: EcoraColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EcoraRadius.card),
        side: const BorderSide(color: EcoraColors.hairline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: EcoraColors.elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EcoraRadius.sheet),
      ),
      titleTextStyle: ecoraTextTheme.titleLarge,
      contentTextStyle: ecoraTextTheme.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: EcoraColors.elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(EcoraRadius.sheet),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: EcoraColors.elevated,
      contentTextStyle: ecoraTextTheme.bodyMedium?.copyWith(
        color: EcoraColors.textPrimary,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EcoraRadius.card),
        side: const BorderSide(color: EcoraColors.hairline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: EcoraColors.elevated.withValues(alpha: 0.6),
      labelStyle: const TextStyle(
        color: EcoraColors.textSecondary,
        fontFamily: _kUiFont,
        fontSize: 12,
      ),
      floatingLabelStyle: const TextStyle(
        color: EcoraColors.gold,
        fontFamily: _kUiFont,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: EcoraSpace.s16,
        vertical: EcoraSpace.s16,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcoraRadius.card),
        borderSide: const BorderSide(color: EcoraColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcoraRadius.card),
        borderSide: const BorderSide(color: EcoraColors.gold),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcoraRadius.card),
        borderSide: const BorderSide(color: EcoraColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcoraRadius.card),
        borderSide: const BorderSide(color: EcoraColors.danger, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: EcoraColors.gold,
        foregroundColor: EcoraColors.canvas,
        disabledBackgroundColor: EcoraColors.hairlineStrong,
        disabledForegroundColor: EcoraColors.textTertiary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: EcoraSpace.s24,
          vertical: EcoraSpace.s16,
        ),
        textStyle: const TextStyle(
          fontFamily: _kUiFont,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EcoraRadius.pill),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EcoraColors.gold,
        side: const BorderSide(color: EcoraColors.gold, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: EcoraSpace.s24,
          vertical: EcoraSpace.s16,
        ),
        textStyle: const TextStyle(
          fontFamily: _kUiFont,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EcoraRadius.pill),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: EcoraColors.gold,
        textStyle: const TextStyle(
          fontFamily: _kUiFont,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EcoraRadius.pill),
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: EcoraColors.surface,
      selectedItemColor: EcoraColors.gold,
      unselectedItemColor: EcoraColors.textTertiary,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      selectedLabelStyle: TextStyle(
        fontFamily: _kUiFont,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: _kUiFont,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

// --- ALIAS DI COMPATIBILITÀ ---
// LEGACY — non usare in codice nuovo. Puntano ai nuovi token per
// mantenere l'app compilabile mentre le schermate migrano nei blocchi
// C e D. Da rimuovere a fine migrazione, quando gli usi saranno zero.

const Color matteDark = EcoraColors.canvas;
const Color slateSurface = EcoraColors.surface;
const Color premiumGold = EcoraColors.gold;
const Color textPrimary = EcoraColors.textPrimary;
const Color textSecondary = EcoraColors.textSecondary;

/// LEGACY — non usare in codice nuovo. Preferire `ecoraTheme().inputDecorationTheme`.
InputDecoration ecoraInputDecoration(
  String label, {
  IconData? prefixIcon,
  Widget? suffixIcon,
  Color? fillColor,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
    floatingLabelStyle: const TextStyle(color: premiumGold),
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, color: premiumGold, size: 20),
    suffixIcon: suffixIcon,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(EcoraRadius.card),
      borderSide: const BorderSide(color: EcoraColors.hairline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(EcoraRadius.card),
      borderSide: const BorderSide(color: premiumGold),
    ),
    filled: true,
    fillColor: (fillColor ?? slateSurface).withValues(alpha: 0.5),
  );
}

/// LEGACY — non usare in codice nuovo. Preferire `CardTheme` via `Card()`.
BoxDecoration ecoraCardDecoration({double borderRadius = 12}) {
  return BoxDecoration(
    color: slateSurface,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(color: EcoraColors.hairline),
  );
}

/// LEGACY — non usare in codice nuovo. Preferire `ElevatedButtonTheme`.
ButtonStyle ecoraPrimaryButtonStyle({double borderRadius = 24}) {
  return ElevatedButton.styleFrom(
    backgroundColor: premiumGold,
    foregroundColor: matteDark,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
  );
}

/// LEGACY — non usare in codice nuovo. Preferire `OutlinedButtonTheme`.
ButtonStyle ecoraSecondaryButtonStyle({double borderRadius = 24}) {
  return OutlinedButton.styleFrom(
    side: const BorderSide(color: premiumGold, width: 1.5),
    foregroundColor: premiumGold,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
  );
}
