import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/attendance.dart';
import 'package:ecora/models.dart';

SupabaseEvent _event(String id, DateTime date, {int approved = 3}) {
  return SupabaseEvent(
    id: id,
    title: 'Serata $id',
    description: '',
    organizerId: 'h1',
    latitude: 0,
    longitude: 0,
    imageUrl: '',
    eventDate: date.toIso8601String(),
    maxParticipants: 10,
    currentApprovedCount: approved,
  );
}

void main() {
  final now = DateTime(2026, 10, 14, 18);

  group('isAttendanceOpen', () {
    test('dall\'inizio della serata a 7 giorni dopo', () {
      final start = DateTime(2026, 10, 10, 22);
      expect(isAttendanceOpen(start, DateTime(2026, 10, 10, 21, 59)), isFalse);
      expect(isAttendanceOpen(start, start), isTrue);
      expect(isAttendanceOpen(start, DateTime(2026, 10, 17, 22)), isTrue);
      expect(isAttendanceOpen(start, DateTime(2026, 10, 17, 22, 1)), isFalse);
    });
  });

  group('eventsAwaitingAttendance', () {
    test('solo serate iniziate da non più di 7 giorni e con ospiti', () {
      final events = [
        _event('ieri', DateTime(2026, 10, 13, 22)),
        _event('futura', DateTime(2026, 10, 17, 22)),
        _event('vecchia', DateTime(2026, 10, 1, 22)),
        _event('vuota', DateTime(2026, 10, 12, 22), approved: 0),
        _event('settimana', DateTime(2026, 10, 8, 22)),
        _event('rotta', DateTime(2026, 10, 13)).copyWith(eventDate: 'boh'),
      ];
      expect(eventsAwaitingAttendance(events, now).map((e) => e.id),
          ['ieri', 'settimana']);
    });
  });

  group('GuestReliability', () {
    test('legge la riga della funzione SQL', () {
      final r = GuestReliability.fromRow(
          {'user_id': 'u', 'attended': 4, 'no_shows': 1});
      expect(r.attended, 4);
      expect(r.noShows, 1);
      expect(r.hasHistory, isTrue);
    });

    test('0/0 vuol dire nessuno storico', () {
      expect(GuestReliability.fromRow({'user_id': 'u'}).hasHistory, isFalse);
    });
  });

  group('AttendanceSheet', () {
    late List<List<Object>> calls;
    late Completer<String?> result;

    Future<void> pump(WidgetTester tester, Map<String, bool> existing) async {
      calls = [];
      result = Completer<String?>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AttendanceSheet(
            eventTitle: 'Notte in Bianco',
            guests: const [
              AttendanceGuest(requestId: 'r1', name: 'Alex & Sofia'),
              AttendanceGuest(requestId: 'r2', name: 'Marta'),
            ],
            loadMarks: () async => existing,
            onMark: (id, attended) {
              calls.add([id, attended]);
              return result.future;
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Set<bool> selectedFor(WidgetTester tester, int index) => tester
        .widget<SegmentedButton<bool>>(
            find.byType(SegmentedButton<bool>).at(index))
        .selected;

    testWidgets('mostra le presenze già segnate', (tester) async {
      await pump(tester, {'r1': true});
      expect(find.text('Notte in Bianco'), findsOneWidget);
      expect(selectedFor(tester, 0), {true});
      expect(selectedFor(tester, 1), isEmpty);
      expect(find.text('Segnati 1 su 2'), findsOneWidget);
    });

    testWidgets('segnare un assente salva subito', (tester) async {
      await pump(tester, {});
      await tester.tap(find.text('Assente').at(1));
      await tester.pump();

      expect(calls, [
        ['r2', false]
      ]);
      expect(selectedFor(tester, 1), {false});
      result.complete(null);
      await tester.pumpAndSettle();
      expect(selectedFor(tester, 1), {false});
      expect(find.text('Segnati 1 su 2'), findsOneWidget);
    });

    testWidgets('se il salvataggio fallisce la scelta torna com\'era',
        (tester) async {
      await pump(tester, {'r1': true});
      await tester.tap(find.text('Assente').at(0));
      await tester.pump();
      expect(selectedFor(tester, 0), {false});

      result.complete('Sono passati più di 7 giorni dalla serata');
      await tester.pumpAndSettle();
      expect(selectedFor(tester, 0), {true});
      expect(find.text('Sono passati più di 7 giorni dalla serata'),
          findsOneWidget);
    });

    testWidgets('durante il salvataggio la riga non accetta altri tocchi',
        (tester) async {
      await pump(tester, {});
      await tester.tap(find.text('Presente').at(0));
      await tester.pump();
      await tester.tap(find.text('Assente').at(0));
      await tester.pump();
      expect(calls, [
        ['r1', true]
      ]);
    });
  });
}
