// Blocco C.3: vocabolario unico. Il gestore pubblica "serate", chi partecipa
// è un "ospite". Le parole che confondono o fanno sembrare Ecora un servizio
// di incontri non devono tornare. Controllo sui sorgenti, righe di commento
// escluse.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final lines = <String, List<String>>{
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart'))
        f.path: [
          for (final l in f.readAsLinesSync())
            if (!l.trimLeft().startsWith('//')) l.toLowerCase(),
        ],
  };

  const banned = [
    'tavol',
    'consolle',
    'ispettore',
    'scudo',
    'stanze del club',
    'creatore',
    'incontro riservato',
    "protocollo d'ingresso",
    'screening',
  ];

  test('i sorgenti sono stati trovati', () {
    expect(lines, isNotEmpty);
  });

  for (final word in banned) {
    test('nessuna parola "$word"', () {
      final hits = [
        for (final f in lines.entries)
          if (f.value.any((l) => l.contains(word))) f.key,
      ];
      expect(hits, isEmpty);
    });
  }
}
