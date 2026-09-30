// Blocco B.3: le frasi che promettevano cose non vere non devono tornare.
// Controllo sui sorgenti, così vale per ogni schermata anche senza
// renderizzarla.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sources = {
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f.path: f.readAsStringSync(),
  };

  // Frase vietata -> perché è falsa.
  const banned = {
    'end-to-end': 'non c\'è cifratura end-to-end',
    'non viene mai registrata': 'device_tokens registra il dispositivo',
    'ALTA AFFIDABILIT': 'nessun dato vero su presenze e assenze (B.2)',
    'alta affidabilità': 'nessun dato vero su presenze e assenze (B.2)',
    'Svelato solo': 'location_name è visibile a tutti gli iscritti',
    'GPS precisi': 'le coordinate arrivano a tutti con get_events_with_stats',
    'non saranno rivelati': 'nickname e zona sono leggibili dagli iscritti',
    '? "45"': 'numero di eventi organizzati inventato',
  };

  test('i sorgenti sono stati trovati', () {
    expect(sources, isNotEmpty);
  });

  for (final entry in banned.entries) {
    test('nessuna scritta "${entry.key}" (${entry.value})', () {
      final hits = [
        for (final s in sources.entries)
          if (s.value.contains(entry.key)) s.key,
      ];
      expect(hits, isEmpty);
    });
  }
}
