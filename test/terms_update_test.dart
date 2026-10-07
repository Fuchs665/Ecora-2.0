import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/consent_text.dart';
import 'package:ecora/terms_update.dart';
import 'package:ecora/theme.dart';

void main() {
  group('signupConsentCovers', () {
    const version = '2026-10-06';

    test('caselle spuntate e iscrizione con la versione in vigore', () {
      expect(
          signupConsentCovers(
              metadata: {'terms_consent': true},
              createdAt: '2026-10-07T09:00:00.000000Z',
              version: version),
          isTrue);
      expect(
          signupConsentCovers(
              metadata: {'terms_consent': true},
              createdAt: '2026-10-06T00:00:00Z',
              version: version),
          isTrue,
          reason: 'lo stesso giorno della versione');
    });

    test('app prima di E.4b: timestamp nei metadati', () {
      expect(
          signupConsentCovers(
              metadata: {'terms_accepted_at': '2026-10-06T10:00:00Z'},
              createdAt: '2026-10-06T10:00:00Z',
              version: version),
          isTrue);
    });

    test('iscritto prima della versione: si chiede di nuovo', () {
      expect(
          signupConsentCovers(
              metadata: {'terms_consent': true},
              createdAt: '2026-10-05T23:59:59Z',
              version: version),
          isFalse);
    });

    test('senza consenso o con date illeggibili: si chiede', () {
      expect(
          signupConsentCovers(
              metadata: null, createdAt: '2026-10-07T00:00:00Z', version: version),
          isFalse);
      expect(
          signupConsentCovers(
              metadata: {'terms_consent': 'true'},
              createdAt: '2026-10-07T00:00:00Z',
              version: version),
          isFalse);
      expect(
          signupConsentCovers(
              metadata: {'terms_consent': true}, createdAt: '', version: version),
          isFalse);
      expect(
          signupConsentCovers(
              metadata: {'terms_consent': true},
              createdAt: '2026-10-07T00:00:00Z',
              version: 'v2'),
          isFalse);
    });
  });

  test('messaggi di accept_terms dai codici di Postgres', () {
    expect(acceptTermsErrorMessage('22023'),
        'I Termini sono stati aggiornati di nuovo. Rileggili e accetta.');
    expect(acceptTermsErrorMessage('P0002'), 'Salvataggio non riuscito. Riprova.');
    expect(acceptTermsErrorMessage(null), 'Salvataggio non riuscito. Riprova.');
  });

  test('versione della 0020 uguale alla data di docs/terms.html', () {
    final sql =
        File('supabase/migrations/0020_consenso_lato_server.sql').readAsStringSync();
    final version =
        RegExp(r"select '(\d{4}-\d{2}-\d{2})'::text").firstMatch(sql)!.group(1)!;
    final html = File('docs/terms.html').readAsStringSync();
    const mesi = [
      'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio',
      'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'
    ];
    final m = RegExp(r'Ultimo aggiornamento: (\d{1,2}) (\w+) (\d{4})')
        .firstMatch(html)!;
    final date = DateTime(int.parse(m.group(3)!),
        mesi.indexOf(m.group(2)!) + 1, int.parse(m.group(1)!));
    expect(DateTime.parse(version), date);
  });

  group('TermsUpdateScreen', () {
    late Completer<String?> result;
    late int accepts, logouts, deletes, terms, privacy;

    Future<void> pump(WidgetTester tester) async {
      result = Completer<String?>();
      accepts = logouts = deletes = terms = privacy = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ecoraTheme(),
        home: TermsUpdateScreen(
          onAccept: () {
            accepts++;
            return result.future;
          },
          onLogout: () => logouts++,
          onDeleteAccount: () => deletes++,
          onOpenTerms: () => terms++,
          onOpenPrivacy: () => privacy++,
        ),
      ));
    }

    ElevatedButton acceptButton(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    Future<void> tickAll(WidgetTester tester) async {
      for (final c in find.byType(Checkbox).evaluate().toList()) {
        await tester.tap(find.byWidget(c.widget));
      }
      await tester.pump();
    }

    testWidgets('testi approvati e tre caselle', (tester) async {
      await pump(tester);
      expect(find.text(kTermsUpdateTitle), findsOneWidget);
      expect(find.text(kTermsUpdateBody), findsOneWidget);
      expect(find.text(kAgeConsentText), findsOneWidget);
      expect(find.text(kSensitiveConsentText), findsOneWidget);
      expect(find.byType(ConsentText), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(find.text('Accetta e continua'), findsOneWidget);
      expect(find.text('Esci'), findsOneWidget);
      expect(find.text("Elimina l'account"), findsOneWidget);
    });

    testWidgets('Accetta spento finché manca una casella', (tester) async {
      await pump(tester);
      expect(acceptButton(tester).onPressed, isNull);
      await tester.tap(find.text(kAgeConsentText));
      await tester.tap(find.text(kSensitiveConsentText));
      await tester.pump();
      expect(acceptButton(tester).onPressed, isNull,
          reason: 'manca la casella dei Termini');
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      expect(acceptButton(tester).onPressed, isNotNull);
    });

    testWidgets('accetta: una sola chiamata, errore mostrato', (tester) async {
      await pump(tester);
      await tickAll(tester);
      await tester.tap(find.text('Accetta e continua'));
      await tester.pump();
      expect(accepts, 1);
      expect(acceptButton(tester).onPressed, isNull, reason: 'in salvataggio');
      result.complete(kTermsChangedAgain);
      await tester.pump();
      expect(find.text(kTermsChangedAgain), findsOneWidget);
      expect(acceptButton(tester).onPressed, isNotNull);
    });

    testWidgets('Esci ed Elimina l\'account', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Esci'));
      await tester.tap(find.text("Elimina l'account"));
      expect(logouts, 1);
      expect(deletes, 1);
      expect(accepts, 0);
    });
  });

  testWidgets('TermsCheckErrorScreen: Riprova ed Esci', (tester) async {
    var retries = 0, logouts = 0;
    await tester.pumpWidget(MaterialApp(
      theme: ecoraTheme(),
      home: TermsCheckErrorScreen(
          onRetry: () => retries++, onLogout: () => logouts++),
    ));
    expect(find.text(kTermsCheckFailed), findsOneWidget);
    await tester.tap(find.text('Riprova'));
    await tester.tap(find.text('Esci'));
    expect(retries, 1);
    expect(logouts, 1);
  });
}
