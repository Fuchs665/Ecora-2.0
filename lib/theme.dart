import 'package:flutter/material.dart';

// --- PREMIUM DESIGN SYSTEM TOKENS ---
// Unica fonte di verità per colori e stili condivisi. Le schermate
// vengono migrate una alla volta ai builder qui sotto (blocchi Fase 2).

const Color matteDark = Color(0xFF1A1A1A);
const Color slateSurface = Color(0xFF2A2A2A);
const Color premiumGold = Color(0xFFD4AF37);
const Color textPrimary = Color(0xFFFFFFFF);
const Color textSecondary = Color(0xFFA0A0A0);

/// Decorazione standard per i campi di testo del design system:
/// bordo dorato al focus, sfondo semi-trasparente, etichetta oro.
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
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: premiumGold),
    ),
    filled: true,
    fillColor: (fillColor ?? slateSurface).withValues(alpha: 0.5),
  );
}

/// Decorazione standard per le card del design system (superficie scura,
/// bordo sottile, angoli arrotondati).
BoxDecoration ecoraCardDecoration({double borderRadius = 12}) {
  return BoxDecoration(
    color: slateSurface,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
  );
}

/// Stile standard per i bottoni primari dorati.
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

/// Stile standard per i bottoni secondari (contorno dorato).
ButtonStyle ecoraSecondaryButtonStyle({double borderRadius = 24}) {
  return OutlinedButton.styleFrom(
    side: const BorderSide(color: premiumGold, width: 1.5),
    foregroundColor: premiumGold,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
  );
}
