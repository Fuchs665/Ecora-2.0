import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/gestore_dashboard.dart';
import 'package:ecora/models.dart';
import 'package:ecora/theme.dart';
import 'package:ecora/venue_status.dart';

SupabaseProfile _host({required bool verified}) => SupabaseProfile(
      id: 'h1',
      fullName: 'Arcadia Club',
      role: 'gestore',
      gender: 'Coppia',
      isVerified: verified,
    );

void main() {
  group('SupabaseProfile.isVerified', () {
    test('letto da is_verified', () {
      expect(SupabaseProfile.fromRow({'id': 'u', 'is_verified': true}).isVerified,
          isTrue);
      expect(
          SupabaseProfile.fromRow({'id': 'u', 'is_verified': false}).isVerified,
          isFalse);
    });

    test('assente o null: non verificato', () {
      expect(SupabaseProfile.fromRow({'id': 'u'}).isVerified, isFalse);
      expect(SupabaseProfile.fromRow({'id': 'u', 'is_verified': null}).isVerified,
          isFalse);
    });

    test('copyWith lo conserva e lo cambia', () {
      final p = _host(verified: true);
      expect(p.copyWith(birthYear: 1990).isVerified, isTrue);
      expect(p.copyWith(isVerified: false).isVerified, isFalse);
    });
  });

  Future<void> pumpDashboard(WidgetTester tester, {required bool verified}) {
    return tester.pumpWidget(MaterialApp(
      theme: ecoraTheme(),
      home: ClubDashboardScreen(
        host: _host(verified: verified),
        events: const [],
        requests: const [],
        onSelectRequestInspector: () {},
        onCreateEvent: () {},
      ),
    ));
  }

  testWidgets('locale non attivo: avviso con i testi approvati', (tester) async {
    await pumpDashboard(tester, verified: false);
    expect(find.byType(VenueInactiveNotice), findsOneWidget);
    expect(find.text('Locale non attivo'), findsOneWidget);
    expect(
        find.text('Il tuo locale non è attivo: non puoi pubblicare serate e '
            'quelle già pubblicate non sono visibili agli iscritti. Se pensi '
            'che sia un errore, scrivici dai contatti indicati nei Termini di '
            'Servizio.'),
        findsOneWidget);
  });

  testWidgets('locale verificato: nessun avviso', (tester) async {
    await pumpDashboard(tester, verified: true);
    expect(find.byType(VenueInactiveNotice), findsNothing);
  });

  testWidgets('foglio di "Crea serata" con il locale non attivo',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ecoraTheme(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showVenueInactiveSheet(context),
          child: const Text('crea'),
        ),
      ),
    ));
    await tester.tap(find.text('crea'));
    await tester.pumpAndSettle();
    expect(find.text(kVenueInactiveTitle), findsOneWidget);
  });
}
