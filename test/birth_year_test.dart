import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/birth_year.dart';
import 'package:ecora/models.dart';

void main() {
  final now = DateTime(2026, 9, 30);

  group('birthYearError', () {
    test('anno valido', () {
      expect(birthYearError('1990', now), isNull);
      expect(birthYearError(' 2008 ', now), isNull, reason: '18 anni nel 2026');
    });

    test('vuoto', () {
      expect(birthYearError('', now), 'Inserisci il tuo anno di nascita.');
    });

    test('non valido', () {
      const msg = 'Inserisci un anno di nascita valido, ad esempio 1990.';
      expect(birthYearError('90', now), msg);
      expect(birthYearError('1899', now), msg);
      expect(birthYearError('abcd', now), msg);
      expect(birthYearError('2030', now), msg);
    });

    test('minorenne', () {
      expect(birthYearError('2009', now), 'Ecora è riservata ai maggiorenni.');
    });
  });

  group('SupabaseProfile età', () {
    test('legge birth_year e calcola l\'età', () {
      final p = SupabaseProfile.fromRow({'id': 'u', 'birth_year': 1990});
      expect(p.birthYear, 1990);
      expect(p.ageAt(now), 36);
    });

    test('senza anno niente età (nessun valore inventato)', () {
      final p = SupabaseProfile.fromRow({'id': 'u'});
      expect(p.birthYear, isNull);
      expect(p.ageAt(now), isNull);
    });
  });

  group('BirthYearScreen', () {
    late List<int> saved;
    late Completer<String?> result;
    late int logouts;

    Future<void> pump(WidgetTester tester) async {
      saved = [];
      result = Completer<String?>();
      logouts = 0;
      await tester.pumpWidget(MaterialApp(
        home: BirthYearScreen(
          onSave: (year) {
            saved.add(year);
            return result.future;
          },
          onLogout: () => logouts++,
        ),
      ));
    }

    testWidgets('un anno non valido non viene salvato', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '2015');
      await tester.tap(find.text('Continua'));
      await tester.pump();

      expect(saved, isEmpty);
      expect(find.text('Ecora è riservata ai maggiorenni.'), findsOneWidget);
    });

    testWidgets('accetta solo cifre, al massimo 4', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '19a905');
      expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '1990');
    });

    testWidgets('salva l\'anno e mostra l\'errore del database',
        (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '1990');
      await tester.tap(find.text('Continua'));
      await tester.pump();

      expect(saved, [1990]);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      result.complete('Salvataggio non riuscito. Riprova.');
      await tester.pumpAndSettle();
      expect(find.text('Salvataggio non riuscito. Riprova.'), findsOneWidget);
      expect(find.text('Continua'), findsOneWidget);
    });

    testWidgets('"Esci" esce dall\'account', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Esci'));
      expect(logouts, 1);
    });
  });
}
