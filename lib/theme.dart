import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// --- ECORA DESIGN SYSTEM v2 ---
// Unica fonte di verità per colori, tipografia, spaziature, raggi,
// movimento e profondità. Specifica: design system "Ecora" su claude.ai
// (https://claude.ai/artifact/A2MsQoNJfUDiyyN5849dgW), direzione
// "Club privato": verde bottiglia, ottone, Bodoni Moda corsivo, Hanken Grotesk.
// Le schermate si migrano ai token qui sotto una alla volta (blocchi C/D).

/// Palette v2. I nomi coincidono con i token del design system.
abstract class EcoraColors {
  // Fondi, dal più basso al più alto.
  static const Color canvas = Color(0xFF0E1814);
  static const Color surface = Color(0xFF14211C);
  static const Color elevated = Color(0xFF1C2D27);

  // Verde del marchio: grandi campi d'identità, mai fondo di testo piccolo.
  static const Color bottle = Color(0xFF1F3A30);
  static const Color bottleLight = Color(0xFF2A4D40);

  // Bordi: line e lineStrong sono decorativi, lineControl è ≥3:1 per i campi.
  static const Color line = Color(0x21EDE8DC);
  static const Color lineStrong = Color(0x38EDE8DC);
  static const Color lineControl = Color(0xFF6B7A72);

  // Testo. inkSubtle solo su canvas, surface ed elevated.
  static const Color ink = Color(0xFFEDE8DC);
  static const Color inkMuted = Color(0xFFA1ABA3);
  static const Color inkSubtle = Color(0xFF8A968D);

  // L'unico accento. brassDeep è solo decorativo.
  static const Color brass = Color(0xFFC3A56C);
  static const Color brassBright = Color(0xFFD9BE86);
  static const Color brassDeep = Color(0xFF8C7443);
  static const Color onBrass = Color(0xFF0E1814);

  // Copertina Luce: solo copertine, testo sempre su coverScrim.
  static const Color lightBase = Color(0xFF0C221B);
  static const Color lightAmber = Color(0xFFD4A857);
  static const Color lightEmerald = Color(0xFF2F8F6E);
  static const Color lightTeal = Color(0xFF1B5A48);
  static const Color coverScrim = Color(0x8006100C);

  // Stati, sempre accompagnati da una parola. success è blu di proposito:
  // il verde è del marchio e verde/rosso si confondono per chi è daltonico.
  static const Color success = Color(0xFF7DBFE0);
  static const Color danger = Color(0xFFEC7F72);
  static const Color warning = Color(0xFFE2B25C);
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

/// Parametri dei tre momenti in 3D (copertina che segue il telefono, pass
/// che si gira, luce viva). Prospettiva in Flutter:
/// `Matrix4.identity()..setEntry(3, 2, 1 / EcoraDepth.perspectiveScreen)`.
/// Tutto spento quando `MediaQuery.disableAnimationsOf(context)` è vero.
abstract class EcoraDepth {
  static const double perspectiveScreen = 1100;
  static const double perspectivePass = 1000;
  static const double tiltMaxDegrees = 12;
  static const double parallaxCover = 18;
  static const double parallaxLayer = 5;
}

const String _kDisplayFont = 'EcoraDisplay';
const String _kUiFont = 'EcoraUI';

/// Scala tipografica. I titoli (display*, headlineSmall, titleLarge) sono in
/// Bodoni Moda corsivo e mai sotto i 20px; tutto il resto in Hanken Grotesk.
/// Nessun testo sotto i 12px tranne labelSmall (overline, sempre maiuscolo).
/// Mappa verso i token del design system: displayLarge = display-lg,
/// displayMedium = display-md, headlineSmall = cover-title, titleLarge = title,
/// labelLarge = button, labelSmall = overline.
const TextTheme ecoraTextTheme = TextTheme(
  displayLarge: TextStyle(
    fontFamily: _kDisplayFont,
    fontSize: 40,
    height: 46 / 40,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    letterSpacing: -0.5,
    color: EcoraColors.ink,
  ),
  displayMedium: TextStyle(
    fontFamily: _kDisplayFont,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    color: EcoraColors.ink,
  ),
  headlineSmall: TextStyle(
    fontFamily: _kDisplayFont,
    fontSize: 30,
    height: 1,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    color: EcoraColors.ink,
  ),
  titleLarge: TextStyle(
    fontFamily: _kDisplayFont,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    color: EcoraColors.ink,
  ),
  labelLarge: TextStyle(
    fontFamily: _kUiFont,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    color: EcoraColors.ink,
  ),
  labelSmall: TextStyle(
    fontFamily: _kUiFont,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: EcoraColors.inkMuted,
  ),
  bodyLarge: TextStyle(
    fontFamily: _kUiFont,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: EcoraColors.ink,
  ),
  bodyMedium: TextStyle(
    fontFamily: _kUiFont,
    fontSize: 14,
    height: 21 / 14,
    fontWeight: FontWeight.w400,
    color: EcoraColors.ink,
  ),
  bodySmall: TextStyle(
    fontFamily: _kUiFont,
    fontSize: 12,
    height: 17 / 12,
    fontWeight: FontWeight.w500,
    color: EcoraColors.inkMuted,
  ),
);

/// Stili fuori dalla TextTheme di Material.
abstract class EcoraTextStyles {
  /// Il nome del marchio finché non esiste un logo: "ECORA", in brass.
  static const TextStyle wordmark = TextStyle(
    fontFamily: _kUiFont,
    fontSize: 12,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 3.6,
    color: EcoraColors.brass,
  );
}

const TextStyle _kButtonText = TextStyle(
  fontFamily: _kUiFont,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w600,
);

/// `ThemeData` completo del design system. Le schermate leggono gli stili
/// da `Theme.of(context)` invece di stilizzare a mano.
ThemeData ecoraTheme() {
  const colorScheme = ColorScheme.dark(
    primary: EcoraColors.brass,
    onPrimary: EcoraColors.onBrass,
    secondary: EcoraColors.bottle,
    onSecondary: EcoraColors.ink,
    surface: EcoraColors.surface,
    onSurface: EcoraColors.ink,
    error: EcoraColors.danger,
    onError: EcoraColors.canvas,
    outline: EcoraColors.lineControl,
    outlineVariant: EcoraColors.lineStrong,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: EcoraColors.canvas,
    fontFamily: _kUiFont,
    textTheme: ecoraTextTheme,
    dividerColor: EcoraColors.line,
    dividerTheme: const DividerThemeData(
      color: EcoraColors.line,
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
        side: const BorderSide(color: EcoraColors.line),
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
      contentTextStyle: ecoraTextTheme.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EcoraRadius.card),
        side: const BorderSide(color: EcoraColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: EcoraColors.elevated,
      labelStyle: const TextStyle(
        color: EcoraColors.inkMuted,
        fontFamily: _kUiFont,
        fontSize: 12,
      ),
      floatingLabelStyle: const TextStyle(
        color: EcoraColors.brass,
        fontFamily: _kUiFont,
      ),
      hintStyle: const TextStyle(
        color: EcoraColors.inkSubtle,
        fontFamily: _kUiFont,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: EcoraSpace.s12,
        vertical: EcoraSpace.s12,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcoraRadius.control),
        borderSide: const BorderSide(color: EcoraColors.lineControl),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcoraRadius.control),
        borderSide: const BorderSide(color: EcoraColors.brass, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcoraRadius.control),
        borderSide: const BorderSide(color: EcoraColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcoraRadius.control),
        borderSide: const BorderSide(color: EcoraColors.danger, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: EcoraColors.onBrass,
        disabledForegroundColor: EcoraColors.inkSubtle,
        elevation: 0,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: EcoraSpace.s24,
          vertical: EcoraSpace.s12,
        ),
        textStyle: _kButtonText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EcoraRadius.control),
        ),
      ).copyWith(
        // Premuto: brassBright. Disattivato: elevated con bordo lineStrong.
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return EcoraColors.elevated;
          if (states.contains(WidgetState.pressed)) return EcoraColors.brassBright;
          return EcoraColors.brass;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const BorderSide(color: EcoraColors.lineStrong);
          }
          return BorderSide.none;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EcoraColors.brass,
        disabledForegroundColor: EcoraColors.inkSubtle,
        side: const BorderSide(color: EcoraColors.brass),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: EcoraSpace.s24,
          vertical: EcoraSpace.s12,
        ),
        textStyle: _kButtonText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EcoraRadius.control),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: EcoraColors.inkMuted,
        minimumSize: const Size(48, 44),
        textStyle: _kButtonText.copyWith(
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: EcoraColors.inkMuted,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EcoraRadius.control),
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: EcoraColors.surface,
      selectedItemColor: EcoraColors.brass,
      unselectedItemColor: EcoraColors.inkMuted,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      selectedLabelStyle: TextStyle(
        fontFamily: _kUiFont,
        fontSize: 12,
        fontWeight: FontWeight.w600,
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
const Color premiumGold = EcoraColors.brass;
const Color textPrimary = EcoraColors.ink;
const Color textSecondary = EcoraColors.inkMuted;

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
      borderSide: const BorderSide(color: EcoraColors.line),
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
    border: Border.all(color: EcoraColors.line),
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
