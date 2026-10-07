import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/logout_everywhere.dart';
import 'package:ecora/theme.dart';

void main() {
  late Completer<String?> result;
  late int calls;

  Future<void> open(WidgetTester tester) async {
    result = Completer<String?>();
    calls = 0;
    await tester.pumpWidget(MaterialApp(
      theme: ecoraTheme(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => LogoutEverywhereDialog(onConfirm: () {
              calls++;
              return result.future;
            }),
          ),
          child: const Text('apri'),
        ),
      ),
    ));
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  testWidgets('testi approvati', (tester) async {
    await open(tester);
    expect(find.text('Esci da tutti i dispositivi'), findsOneWidget);
    expect(
        find.text('Verrai disconnesso da Ecora su tutti i dispositivi, '
            'compreso questo. Le notifiche smetteranno di arrivare.'),
        findsOneWidget);
    expect(find.text('Esci ovunque'), findsOneWidget);
    expect(find.text('Annulla'), findsOneWidget);
  });

  testWidgets('Annulla chiude senza chiamare il server', (tester) async {
    await open(tester);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(find.byType(LogoutEverywhereDialog), findsNothing);
    expect(calls, 0);
  });

  testWidgets('errore: il dialogo resta aperto con il messaggio',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Esci ovunque'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Esci ovunque'), findsNothing, reason: 'in corso');
    result.complete(kLogoutEverywhereFailed);
    await tester.pumpAndSettle();
    expect(find.byType(LogoutEverywhereDialog), findsOneWidget);
    expect(
        find.text('Non è stato possibile uscire dagli altri dispositivi. '
            'Controlla la connessione e riprova.'),
        findsOneWidget);
  });

  testWidgets('riuscito: il dialogo si chiude', (tester) async {
    await open(tester);
    await tester.tap(find.text('Esci ovunque'));
    result.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(LogoutEverywhereDialog), findsNothing);
  });
}
