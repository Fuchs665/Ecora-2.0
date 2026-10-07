import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecora/gestore_dashboard.dart';

void main() {
  Future<List<int>> pump(WidgetTester tester, {int pending = 0}) async {
    final taps = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: GestoreBottomNav(
          currentIndex: 0,
          pendingCount: pending,
          onTap: taps.add,
        ),
      ),
    ));
    return taps;
  }

  testWidgets('quattro etichette visibili, nessun FAB', (tester) async {
    await pump(tester);
    for (final l in ['Serate', 'Richieste', 'Chat', 'Profilo']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('il tap su ogni voce passa l\'indice giusto', (tester) async {
    final taps = await pump(tester);
    for (final l in ['Richieste', 'Chat', 'Profilo', 'Serate']) {
      await tester.tap(find.text(l));
    }
    expect(taps, [1, 2, 3, 0]);
  });

  testWidgets('badge solo con richieste in attesa', (tester) async {
    await pump(tester);
    expect(find.text('3'), findsNothing);
    await pump(tester, pending: 3);
    expect(find.text('3'), findsOneWidget);
  });
}
