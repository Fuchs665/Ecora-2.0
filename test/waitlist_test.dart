import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/data_service.dart';
import 'package:ecora/gestore_dashboard.dart';
import 'package:ecora/models.dart';
import 'package:ecora/theme.dart';
import 'package:ecora/waitlist.dart';

SupabaseParticipationRequest _req(String id, String status, int minute,
        {String user = 'u'}) =>
    SupabaseParticipationRequest(
      id: id,
      userId: '$user$id',
      eventId: 'e1',
      status: status,
      createdAt: DateTime(2026, 10, 8, 20, minute),
    );

void main() {
  group('waitlistDetail', () {
    test('con la posizione', () {
      expect(waitlistDetail(3),
          'Sei 3° in lista. Ti avvisiamo se si libera un posto.');
    });
    test('senza posizione: solo l\'avviso', () {
      expect(waitlistDetail(null), 'Ti avvisiamo se si libera un posto.');
      expect(waitlistDetail(0), 'Ti avvisiamo se si libera un posto.');
    });
    test('testi', () {
      expect(kWaitlistStatus, "In lista d'attesa");
      expect(kWaitlistSection, "Lista d'attesa");
    });
  });

  test('waitlistedInOrder: solo la lista, dalla più vecchia', () {
    final list = waitlistedInOrder([
      _req('a', 'waitlisted', 30),
      _req('b', 'pending', 1),
      _req('c', 'waitlisted', 10),
      SupabaseParticipationRequest(
          id: 'd', userId: 'ud', eventId: 'e1', status: 'waitlisted'),
    ]);
    expect(list.map((r) => r.id), ['c', 'a', 'd']);
  });

  testWidgets('Richieste del gestore: sezione Lista d\'attesa sotto le altre',
      (tester) async {
    for (final id in ['p', 'w1', 'w2']) {
      EcoraDataService.instance.addProfile(SupabaseProfile(
        id: 'u$id',
        fullName: 'Ospite $id',
        role: 'cliente',
        gender: 'Coppia',
        birthYear: 1990,
      ));
    }
    final event = SupabaseEvent(
      id: 'e1',
      title: 'Serata',
      description: '',
      organizerId: 'h1',
      latitude: 0,
      longitude: 0,
      imageUrl: '',
      eventDate: DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      maxParticipants: 10,
    );
    await tester.pumpWidget(MaterialApp(
      theme: ecoraTheme(),
      home: RequestInspectorScreen(
        events: [event],
        requests: [
          _req('w2', 'waitlisted', 40),
          _req('p', 'pending', 50),
          _req('w1', 'waitlisted', 20),
        ],
      ),
    ));
    expect(find.text("LISTA D'ATTESA"), findsOneWidget);
    final pending = tester.getTopLeft(find.textContaining('Ospite p')).dy;
    final header = tester.getTopLeft(find.text("LISTA D'ATTESA")).dy;
    final w1 = tester.getTopLeft(find.textContaining('Ospite w1')).dy;
    final w2 = tester.getTopLeft(find.textContaining('Ospite w2')).dy;
    expect(pending, lessThan(header));
    expect(header, lessThan(w1));
    expect(w1, lessThan(w2), reason: 'ordine di arrivo');
  });

  testWidgets('senza lista d\'attesa: nessuna intestazione', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ecoraTheme(),
      home: const RequestInspectorScreen(events: [], requests: []),
    ));
    expect(find.text("LISTA D'ATTESA"), findsNothing);
    expect(find.text('Nessuna richiesta da valutare.'), findsOneWidget);
  });
}
