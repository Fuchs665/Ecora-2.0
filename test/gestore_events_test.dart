import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecora/gestore_events.dart';
import 'package:ecora/models.dart';

SupabaseEvent ev(String id, String date, {int max = 10, int ok = 4}) =>
    SupabaseEvent(
      id: id,
      title: 'Serata $id',
      description: '',
      organizerId: 'h',
      latitude: 0,
      longitude: 0,
      imageUrl: '',
      eventDate: date,
      maxParticipants: max,
      currentApprovedCount: ok,
    );

void main() {
  final now = DateTime(2026, 10, 1, 12);

  group('splitHostEvents', () {
    test('ordina per data, scarta le passate', () {
      final r = splitHostEvents([
        ev('c', '2026-11-01T21:00:00'),
        ev('old', '2026-09-20T21:00:00'),
        ev('a', '2026-10-03T21:00:00'),
        ev('b', '2026-10-10T21:00:00'),
      ], now);
      expect(r.next!.id, 'a');
      expect([for (final e in r.upcoming) e.id], ['b', 'c']);
    });

    test('data illeggibile in coda, nessuna serata futura -> niente', () {
      final r = splitHostEvents(
          [ev('x', 'boh'), ev('a', '2026-10-03T21:00:00')], now);
      expect(r.next!.id, 'a');
      expect(r.upcoming.single.id, 'x');
      final none = splitHostEvents([ev('old', '2026-09-01T21:00:00')], now);
      expect(none.next, isNull);
      expect(none.upcoming, isEmpty);
    });
  });

  test('eventDateLabel', () {
    expect(eventDateLabel('2026-10-17T21:00:00'), 'sabato 17 ottobre');
    expect(eventDateLabel('boh'), '');
  });

  Future<void> pump(WidgetTester t, Widget w) =>
      t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w))));

  testWidgets('NextEventCard: Valuta solo con richieste in attesa',
      (tester) async {
    var evaluated = 0;
    await pump(
        tester,
        NextEventCard(
            event: ev('a', '2026-10-17T21:00:00'),
            pendingCount: 0,
            onTap: () {},
            onEvaluate: () => evaluated++));
    expect(find.text('Valuta'), findsNothing);
    expect(find.text('PROSSIMA SERATA'), findsOneWidget);
    expect(find.text('4 / 10 coppie confermate'), findsOneWidget);

    await pump(
        tester,
        NextEventCard(
            event: ev('a', '2026-10-17T21:00:00'),
            pendingCount: 2,
            onTap: () {},
            onEvaluate: () => evaluated++));
    expect(find.text('2 richieste da valutare'), findsOneWidget);
    await tester.tap(find.text('Valuta'));
    expect(evaluated, 1);
  });

  testWidgets('UpcomingEventTile: tassello data e tap', (tester) async {
    var taps = 0;
    await pump(
        tester,
        UpcomingEventTile(
            event: ev('b', '2026-11-08T21:00:00'),
            pendingCount: 1,
            onTap: () => taps++));
    expect(find.text('8'), findsOneWidget);
    expect(find.text('NOV'), findsOneWidget);
    expect(find.text('1 richiesta in attesa'), findsOneWidget);
    await tester.tap(find.text('Serata b'));
    expect(taps, 1);
  });
}
