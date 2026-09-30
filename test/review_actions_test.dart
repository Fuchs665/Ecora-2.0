import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/gestore_dashboard.dart';

/// Apre un dialogo con [ReviewActions], come fa la scheda candidato.
class _Harness {
  final decisions = <ReviewDecision>[];
  final done = <ReviewDecision>[];
  Completer<String?> result = Completer<String?>();
  bool confirmBlock = true;

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                content: const Text('Scheda candidato'),
                actions: [
                  ReviewActions(
                    onDecision: (decision) {
                      decisions.add(decision);
                      return result.future;
                    },
                    confirmBlock: () async => confirmBlock,
                    onDone: (decision) {
                      done.add(decision);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }
}

Finder get _approve => find.byType(ElevatedButton);
Finder _text(String label) => find.widgetWithText(TextButton, label);

bool _enabled(WidgetTester tester, Finder button) =>
    tester.widget<ButtonStyleButton>(button).onPressed != null;

void main() {
  testWidgets('durante il salvataggio il dialogo resta aperto e bloccato',
      (tester) async {
    final h = _Harness();
    await h.open(tester);

    await tester.tap(_approve);
    await tester.pump();

    expect(h.decisions, [ReviewDecision.approve]);
    expect(find.text('Scheda candidato'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_enabled(tester, _approve), isFalse);
    expect(_enabled(tester, _text('RIFIUTA')), isFalse);
    expect(_enabled(tester, _text('BLOCCA UTENTE')), isFalse);

    // Né il tocco fuori né "indietro" lo chiudono mentre salva. Si aspetta
    // oltre l'animazione di chiusura (lo spinner vieta pumpAndSettle).
    await tester.tapAt(const Offset(4, 4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Scheda candidato'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Scheda candidato'), findsOneWidget);
  });

  testWidgets('se va a buon fine il dialogo si chiude', (tester) async {
    final h = _Harness();
    await h.open(tester);

    await tester.tap(_text('RIFIUTA'));
    await tester.pump();
    h.result.complete(null);
    await tester.pumpAndSettle();

    expect(h.done, [ReviewDecision.reject]);
    expect(find.text('Scheda candidato'), findsNothing);
  });

  testWidgets('se fallisce il dialogo resta aperto con l\'errore',
      (tester) async {
    final h = _Harness();
    await h.open(tester);

    await tester.tap(_approve);
    await tester.pump();
    h.result.complete('Operazione non riuscita. Riprova.');
    await tester.pumpAndSettle();

    expect(h.done, isEmpty);
    expect(find.text('Scheda candidato'), findsOneWidget);
    expect(find.text('Operazione non riuscita. Riprova.'), findsOneWidget);
    expect(_enabled(tester, _approve), isTrue);

    // Si può riprovare: l'errore sparisce e al secondo tentativo chiude.
    h.result = Completer<String?>();
    await tester.tap(_approve);
    await tester.pump();
    expect(find.text('Operazione non riuscita. Riprova.'), findsNothing);
    h.result.complete(null);
    await tester.pumpAndSettle();
    expect(h.done, [ReviewDecision.approve]);
  });

  testWidgets('il doppio tocco non salva due volte', (tester) async {
    final h = _Harness();
    await h.open(tester);

    await tester.tap(_approve);
    await tester.tap(_approve, warnIfMissed: false);
    await tester.tap(_text('RIFIUTA'), warnIfMissed: false);
    await tester.pump();

    expect(h.decisions, [ReviewDecision.approve]);
  });

  testWidgets('il blocco parte solo dopo la conferma', (tester) async {
    final h = _Harness()..confirmBlock = false;
    await h.open(tester);

    await tester.tap(_text('BLOCCA UTENTE'));
    await tester.pumpAndSettle();
    expect(h.decisions, isEmpty);
    expect(find.text('Scheda candidato'), findsOneWidget);

    h.confirmBlock = true;
    await tester.tap(_text('BLOCCA UTENTE'));
    await tester.pump();
    expect(h.decisions, [ReviewDecision.block]);
    h.result.complete(null);
    await tester.pumpAndSettle();
    expect(h.done, [ReviewDecision.block]);
  });
}
