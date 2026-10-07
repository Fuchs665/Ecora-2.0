import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/report_sheet.dart';
import 'package:ecora/reports.dart';

/// Apre il foglio come fanno chat, dettaglio serata e scheda candidato;
/// registra le chiamate e lascia decidere al test quando rispondono.
class _Harness {
  final submitted = <List<String>>[];
  int blockCalls = 0;
  Completer<ReportResult> submitResult = Completer<ReportResult>();
  Completer<String?> blockResult = Completer<String?>();
  bool? closedWith;
  bool closed = false;

  Future<void> open(WidgetTester tester,
      {ReportTargetType type = ReportTargetType.message}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              closedWith = await showReportSheet(
                context,
                type: type,
                blockName: 'Marco',
                onSubmit: (reason, note) {
                  submitted.add([reason, note]);
                  return submitResult.future;
                },
                onBlock: () {
                  blockCalls++;
                  return blockResult.future;
                },
              );
              closed = true;
            },
            child: const Text('apri'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  Finder get submitButton => find.widgetWithText(ElevatedButton, kReportSubmit);
  Finder get blockButton => find.widgetWithText(ElevatedButton, kReportBlock);

  Future<void> chooseAndSubmit(WidgetTester tester, String label,
      {String note = ''}) async {
    await tester.tap(find.text(label));
    await tester.pump();
    if (note.isNotEmpty) {
      await tester.enterText(find.byType(TextField), note);
    }
    await tester.tap(submitButton);
    await tester.pump();
  }
}

bool _enabled(WidgetTester tester, Finder button) =>
    tester.widget<ElevatedButton>(button).onPressed != null;

/// Motivi ammessi per tipo, letti dal check `reports_reason_check` della
/// migrazione 0019.
Map<String, Set<String>> _reasonsInMigration() {
  final sql =
      File('supabase/migrations/0019_segnalazioni.sql').readAsStringSync();
  final block = RegExp(
      r"target_type = '(\w+)' and reason in\s*\(([^)]*)\)",
      multiLine: true);
  return {
    for (final m in block.allMatches(sql))
      m.group(1)!: RegExp(r"'(\w+)'")
          .allMatches(m.group(2)!)
          .map((c) => c.group(1)!)
          .toSet(),
  };
}

void main() {
  group('logica', () {
    test('i motivi dell\'app sono esattamente quelli ammessi dal database', () {
      final db = _reasonsInMigration();
      expect(db.keys.toSet(), {'message', 'user', 'event'});
      for (final type in ReportTargetType.values) {
        expect(kReportReasons[type]!.map((r) => r.code).toSet(), db[type.name],
            reason: type.name);
      }
    });

    test('nessun motivo ripetuto nello stesso foglio', () {
      for (final reasons in kReportReasons.values) {
        expect(reasons.map((r) => r.code).toSet().length, reasons.length);
      }
    });

    test('riga: solo la colonna del proprio bersaglio, nota ripulita', () {
      expect(
        reportRow(const ReportTarget(ReportTargetType.message, 'm1'),
            'threats', '  attenzione  '),
        {
          'target_type': 'message',
          'target_message_id': 'm1',
          'reason': 'threats',
          'note': 'attenzione',
        },
      );
      expect(
        reportRow(const ReportTarget(ReportTargetType.user, 'u1'), 'underage',
            '   '),
        {'target_type': 'user', 'target_user_id': 'u1', 'reason': 'underage'},
      );
      expect(
        reportRow(const ReportTarget(ReportTargetType.event, 'e1'),
            'not_a_venue', ''),
        {
          'target_type': 'event',
          'target_event_id': 'e1',
          'reason': 'not_a_venue',
        },
      );
    });

    test('riga: mai le colonne che decide il server', () {
      final row = reportRow(
          const ReportTarget(ReportTargetType.message, 'm1'), 'spam', 'x');
      for (final key in [
        'reporter_id',
        'status',
        'content_snapshot',
        'created_at',
        'resolved_at',
      ]) {
        expect(row.containsKey(key), isFalse, reason: key);
      }
    });

    test('codici d\'errore del database', () {
      expect(reportResultFromCode('23505'), ReportResult.alreadyReported);
      expect(reportResultFromCode('EC429'), ReportResult.rateLimited);
      expect(reportResultFromCode('42501'), ReportResult.failed);
      expect(reportResultFromCode(null), ReportResult.failed);
    });

    test('invio in chat: il filtro ha il suo messaggio', () {
      expect(sendMessageErrorForCode('EC422'), kMessageBlockedTerms);
      expect(sendMessageErrorForCode('42501'), "Invio non riuscito. Riprova.");
      expect(sendMessageErrorForCode(null), "Invio non riuscito. Riprova.");
    });

    test('titoli per tipo', () {
      expect(reportTitle(ReportTargetType.message), kReportMessageTitle);
      expect(reportTitle(ReportTargetType.user), kReportUserTitle);
      expect(reportTitle(ReportTargetType.event), kReportEventTitle);
      expect(reportBlockQuestion('Marco'), "Vuoi anche bloccare Marco?");
    });
  });

  group('foglio', () {
    testWidgets('mostra i motivi del tipo e il sottotitolo', (tester) async {
      await _Harness().open(tester, type: ReportTargetType.user);
      expect(find.text(kReportUserTitle), findsOneWidget);
      expect(find.text(kReportSubtitle), findsOneWidget);
      for (final r in kReportReasons[ReportTargetType.user]!) {
        expect(find.text(r.label), findsOneWidget);
      }
      expect(find.text("Minacce"), findsNothing);
    });

    testWidgets('senza motivo non si invia', (tester) async {
      final h = _Harness();
      await h.open(tester);
      expect(_enabled(tester, h.submitButton), isFalse);
      await tester.tap(find.text("Minacce"));
      await tester.pump();
      expect(_enabled(tester, h.submitButton), isTrue);
    });

    testWidgets('invia codice del motivo e nota', (tester) async {
      final h = _Harness();
      await h.open(tester);
      await h.chooseAndSubmit(tester, "Minacce", note: 'ieri sera');
      expect(h.submitted, [
        ['threats', 'ieri sera'],
      ]);
    });

    testWidgets('durante l\'invio il foglio non si chiude', (tester) async {
      final h = _Harness();
      await h.open(tester);
      await h.chooseAndSubmit(tester, "Minacce");
      // In attesa il pulsante mostra lo spinner al posto del testo.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_enabled(tester, find.byType(ElevatedButton)), isFalse);
      expect(
          tester.widget<TextButton>(find.widgetWithText(TextButton, kReportCancel))
              .onPressed,
          isNull);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(h.closed, isFalse);
      expect(find.text(kReportMessageTitle), findsOneWidget);
    });

    testWidgets('errore: resta nel foglio con il messaggio e si può riprovare',
        (tester) async {
      final h = _Harness();
      await h.open(tester);
      await h.chooseAndSubmit(tester, "Minacce");
      h.submitResult.complete(ReportResult.failed);
      await tester.pumpAndSettle();
      expect(h.closed, isFalse);
      expect(find.text(kReportFailed), findsOneWidget);
      expect(_enabled(tester, h.submitButton), isTrue);

      h.submitResult = Completer<ReportResult>();
      await tester.tap(h.submitButton);
      await tester.pump();
      expect(find.text(kReportFailed), findsNothing);
      expect(h.submitted.length, 2);
    });

    testWidgets('tetto giornaliero: messaggio dedicato, resta nel foglio',
        (tester) async {
      final h = _Harness();
      await h.open(tester);
      await h.chooseAndSubmit(tester, "Minacce");
      h.submitResult.complete(ReportResult.rateLimited);
      await tester.pumpAndSettle();
      expect(find.text(kReportRateLimited), findsOneWidget);
      expect(h.closed, isFalse);
    });

    testWidgets('inviata: conferma con le 24 ore e propone il blocco',
        (tester) async {
      final h = _Harness();
      await h.open(tester);
      await h.chooseAndSubmit(tester, "Minacce");
      h.submitResult.complete(ReportResult.sent);
      await tester.pumpAndSettle();
      expect(find.text(kReportSent), findsOneWidget);
      expect(find.text("Vuoi anche bloccare Marco?"), findsOneWidget);
      expect(h.blockButton, findsOneWidget);
      expect(find.text(kReportNoThanks), findsOneWidget);
    });

    testWidgets('già segnalata: lo dice e propone comunque il blocco',
        (tester) async {
      final h = _Harness();
      await h.open(tester);
      await h.chooseAndSubmit(tester, "Minacce");
      h.submitResult.complete(ReportResult.alreadyReported);
      await tester.pumpAndSettle();
      expect(find.text(kReportAlreadySent), findsOneWidget);
      expect(find.text(kReportSent), findsNothing);
      expect(h.blockButton, findsOneWidget);
    });

    testWidgets('"No, grazie" chiude senza bloccare', (tester) async {
      final h = _Harness();
      await h.open(tester);
      await h.chooseAndSubmit(tester, "Minacce");
      h.submitResult.complete(ReportResult.sent);
      await tester.pumpAndSettle();
      await tester.tap(find.text(kReportNoThanks));
      await tester.pumpAndSettle();
      expect(h.closed, isTrue);
      expect(h.closedWith, isFalse);
      expect(h.blockCalls, 0);
    });

    testWidgets('blocco con errore: resta nel foglio con il messaggio',
        (tester) async {
      final h = _Harness();
      await h.open(tester);
      await h.chooseAndSubmit(tester, "Minacce");
      h.submitResult.complete(ReportResult.sent);
      await tester.pumpAndSettle();
      await tester.tap(h.blockButton);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_enabled(tester, find.byType(ElevatedButton)), isFalse);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(h.closed, isFalse);
      h.blockResult.complete("Blocco non riuscito. Riprova.");
      await tester.pumpAndSettle();
      expect(h.closed, isFalse);
      expect(find.text("Blocco non riuscito. Riprova."), findsOneWidget);
      expect(_enabled(tester, h.blockButton), isTrue);
    });

    testWidgets('blocco riuscito: chiude con true', (tester) async {
      final h = _Harness();
      await h.open(tester);
      await h.chooseAndSubmit(tester, "Minacce");
      h.submitResult.complete(ReportResult.sent);
      await tester.pumpAndSettle();
      await tester.tap(h.blockButton);
      await tester.pump();
      h.blockResult.complete(null);
      await tester.pumpAndSettle();
      expect(h.closed, isTrue);
      expect(h.closedWith, isTrue);
      expect(h.blockCalls, 1);
    });

    testWidgets('"Annulla" chiude senza inviare', (tester) async {
      final h = _Harness();
      await h.open(tester);
      await tester.tap(find.text(kReportCancel));
      await tester.pumpAndSettle();
      expect(h.closed, isTrue);
      expect(h.closedWith, isFalse);
      expect(h.submitted, isEmpty);
    });
  });
}
