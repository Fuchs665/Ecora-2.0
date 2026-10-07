import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/biometric_gate.dart';
import 'package:ecora/theme.dart';

class _FakeAuth implements EcoraAuthenticator {
  bool available;
  int calls = 0;
  Completer<bool> next = Completer<bool>();

  _FakeAuth({this.available = true});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate() {
    calls++;
    return next.future;
  }

  void answer(bool ok) {
    next.complete(ok);
    next = Completer<bool>();
  }
}

/// Contenuto con stato: se viene smontato il contatore riparte da zero.
class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => setState(() => n++),
            child: Text('contenuto $n'),
          ),
        ),
      );
}

void main() {
  group('shouldRelock', () {
    final t0 = DateTime(2026, 10, 7, 12);
    test('mai senza pausa registrata', () {
      expect(shouldRelock(pausedAt: null, now: t0), isFalse);
    });
    test('sotto i 30 secondi no, da 30 in su sì', () {
      expect(
          shouldRelock(
              pausedAt: t0, now: t0.add(const Duration(seconds: 29))),
          isFalse);
      expect(
          shouldRelock(
              pausedAt: t0, now: t0.add(const Duration(seconds: 30))),
          isTrue);
      expect(kRelockAfter, const Duration(seconds: 30));
    });
  });

  group('BiometricGate', () {
    late _FakeAuth auth;
    late DateTime now;

    Future<void> pump(WidgetTester tester) async {
      now = DateTime(2026, 10, 7, 12);
      await tester.pumpWidget(MaterialApp(
        theme: ecoraTheme(),
        builder: (context, child) => BiometricGate(
          authenticator: auth,
          clock: () => now,
          child: child!,
        ),
        home: const _Counter(),
      ));
      await tester.pump();
    }

    Future<void> lifecycle(WidgetTester tester, AppLifecycleState s) async {
      tester.binding.handleAppLifecycleStateChanged(s);
      await tester.pump();
    }

    Future<void> background(WidgetTester tester, Duration d) async {
      await lifecycle(tester, AppLifecycleState.inactive);
      await lifecycle(tester, AppLifecycleState.hidden);
      await lifecycle(tester, AppLifecycleState.paused);
      now = now.add(d);
      await lifecycle(tester, AppLifecycleState.hidden);
      await lifecycle(tester, AppLifecycleState.inactive);
      await lifecycle(tester, AppLifecycleState.resumed);
    }

    testWidgets('senza biometria non blocca mai', (tester) async {
      auth = _FakeAuth(available: false);
      await pump(tester);
      expect(find.text('contenuto 0'), findsOneWidget);
      await background(tester, const Duration(minutes: 5));
      expect(auth.calls, 0);
      expect(find.text('ACCESSO BLOCCATO'), findsNothing);
    });

    testWidgets('all\'avvio il contenuto non si costruisce prima dello sblocco',
        (tester) async {
      auth = _FakeAuth();
      await pump(tester);
      expect(auth.calls, 1);
      expect(find.textContaining('contenuto'), findsNothing);
      auth.answer(true);
      await tester.pump();
      expect(find.text('contenuto 0'), findsOneWidget);
    });

    testWidgets('sblocco fallito: schermata di blocco e riprova',
        (tester) async {
      auth = _FakeAuth();
      await pump(tester);
      auth.answer(false);
      await tester.pump();
      expect(find.text('ACCESSO BLOCCATO'), findsOneWidget);
      await tester.tap(find.text('RIPROVA LO SBLOCCO'));
      expect(auth.calls, 2);
      auth.answer(true);
      await tester.pump();
      expect(find.text('contenuto 0'), findsOneWidget);
    });

    testWidgets('pausa breve: nessuna richiesta', (tester) async {
      auth = _FakeAuth();
      await pump(tester);
      auth.answer(true);
      await tester.pump();
      await background(tester, const Duration(seconds: 10));
      expect(auth.calls, 1);
      expect(find.text('contenuto 0'), findsOneWidget);
    });

    testWidgets('pausa lunga: si blocca e il contenuto resta montato',
        (tester) async {
      auth = _FakeAuth();
      await pump(tester);
      auth.answer(true);
      await tester.pump();
      await tester.tap(find.text('contenuto 0'));
      await tester.pump();
      expect(find.text('contenuto 1'), findsOneWidget);

      await background(tester, const Duration(seconds: 45));
      expect(auth.calls, 2);
      // Coperto e non toccabile, ma non smontato.
      await tester.tap(find.text('contenuto 1'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('contenuto 1'), findsOneWidget);

      auth.answer(false);
      await tester.pump();
      expect(find.text('ACCESSO BLOCCATO'), findsOneWidget);
      await tester.tap(find.text('RIPROVA LO SBLOCCO'));
      auth.answer(true);
      await tester.pump();
      expect(find.text('ACCESSO BLOCCATO'), findsNothing);
      expect(find.text('contenuto 1'), findsOneWidget,
          reason: 'stato conservato');
    });

    testWidgets('i cambi di stato durante il dialogo di sblocco si ignorano',
        (tester) async {
      auth = _FakeAuth();
      await pump(tester);
      // Il dialogo è aperto (prima chiamata in corso): l'app va in pausa
      // e torna, anche dopo molto.
      await background(tester, const Duration(minutes: 2));
      expect(auth.calls, 1);
      auth.answer(true);
      await tester.pump();
      expect(find.text('contenuto 0'), findsOneWidget);
    });
  });
}
