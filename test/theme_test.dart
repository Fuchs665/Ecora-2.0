import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/theme.dart';

/// Rapporto di contrasto WCAG 2 tra due colori opachi.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('Contrasto del design system (WCAG 2)', () {
    const grounds = {
      'canvas': EcoraColors.canvas,
      'surface': EcoraColors.surface,
      'elevated': EcoraColors.elevated,
    };
    const texts = {
      'ink': EcoraColors.ink,
      'inkMuted': EcoraColors.inkMuted,
      'inkSubtle': EcoraColors.inkSubtle,
      'brass': EcoraColors.brass,
      'success': EcoraColors.success,
      'danger': EcoraColors.danger,
      'warning': EcoraColors.warning,
    };

    for (final g in grounds.entries) {
      for (final t in texts.entries) {
        test('${t.key} su ${g.key} è almeno 4.5:1', () {
          expect(contrast(t.value, g.value), greaterThanOrEqualTo(4.5));
        });
      }
      test('lineControl su ${g.key} è almeno 3:1 (bordo dei campi)', () {
        expect(contrast(EcoraColors.lineControl, g.value),
            greaterThanOrEqualTo(3));
      });
    }

    test('ink e inkMuted su bottle sono almeno 4.5:1', () {
      expect(contrast(EcoraColors.ink, EcoraColors.bottle),
          greaterThanOrEqualTo(4.5));
      expect(contrast(EcoraColors.inkMuted, EcoraColors.bottle),
          greaterThanOrEqualTo(4.5));
    });

    test('onBrass su brass e su brassBright è almeno 4.5:1', () {
      expect(contrast(EcoraColors.onBrass, EcoraColors.brass),
          greaterThanOrEqualTo(4.5));
      expect(contrast(EcoraColors.onBrass, EcoraColors.brassBright),
          greaterThanOrEqualTo(4.5));
    });

    test('ink su copertina ambra con coverScrim è almeno 4.5:1', () {
      final ground =
          Color.alphaBlend(EcoraColors.coverScrim, EcoraColors.lightAmber);
      expect(contrast(EcoraColors.ink, ground), greaterThanOrEqualTo(4.5));
    });

    test('success e danger si distinguono anche senza il colore', () {
      // Tonalità lontane dall'asse rosso-verde: success è blu, non verde.
      final successHue = HSLColor.fromColor(EcoraColors.success).hue;
      expect(successHue, inInclusiveRange(180, 240));
    });
  });

  group('ecoraTheme', () {
    final theme = ecoraTheme();

    test('usa brass come accento e canvas come fondo', () {
      expect(theme.colorScheme.primary, EcoraColors.brass);
      expect(theme.colorScheme.onPrimary, EcoraColors.onBrass);
      expect(theme.scaffoldBackgroundColor, EcoraColors.canvas);
    });

    test('titoli in EcoraDisplay corsivo, testo in EcoraUI', () {
      final t = theme.textTheme;
      for (final style in [
        t.displayLarge,
        t.displayMedium,
        t.headlineSmall,
        t.titleLarge,
      ]) {
        expect(style?.fontFamily, 'EcoraDisplay');
        expect(style?.fontStyle, FontStyle.italic);
      }
      for (final style in [t.bodyLarge, t.bodyMedium, t.bodySmall, t.labelLarge]) {
        expect(style?.fontFamily, 'EcoraUI');
      }
    });

    test('nessun testo sotto i 12px tranne labelSmall (overline)', () {
      final t = theme.textTheme;
      for (final style in [
        t.displayLarge,
        t.displayMedium,
        t.headlineSmall,
        t.titleLarge,
        t.labelLarge,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
      ]) {
        expect(style?.fontSize, greaterThanOrEqualTo(12));
      }
      expect(theme.textTheme.titleLarge?.fontSize, greaterThanOrEqualTo(20));
    });
  });

  group('File dei caratteri', () {
    test('ogni font dichiarato in pubspec.yaml esiste', () {
      const files = [
        'assets/fonts/BodoniModa-MediumItalic.ttf',
        'assets/fonts/HankenGrotesk-Regular.ttf',
        'assets/fonts/HankenGrotesk-Medium.ttf',
        'assets/fonts/HankenGrotesk-SemiBold.ttf',
        'assets/fonts/HankenGrotesk-Bold.ttf',
      ];
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final f in files) {
        expect(pubspec.contains(f), isTrue, reason: '$f non è in pubspec.yaml');
        expect(File(f).existsSync(), isTrue, reason: '$f manca');
      }
    });
  });
}
