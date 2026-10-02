import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/gestore_metrics.dart';
import 'package:ecora/italian_dates.dart';
import 'package:ecora/models.dart';
import 'package:ecora/theme.dart';

SupabaseEvent _event({
  String id = 'e',
  String host = 'h1',
  required String date,
  int max = 10,
  int approved = 0,
}) {
  return SupabaseEvent(
    id: id,
    title: 'Serata $id',
    description: '',
    organizerId: host,
    latitude: 0,
    longitude: 0,
    imageUrl: '',
    eventDate: date,
    maxParticipants: max,
    currentApprovedCount: approved,
  );
}

SupabaseParticipationRequest _request(DateTime? created,
    {String status = 'pending'}) {
  return SupabaseParticipationRequest(
    id: 'r',
    userId: 'u',
    eventId: 'e',
    status: status,
    createdAt: created,
  );
}

String _iso(int y, int m, int d, [int h = 22, int min = 30]) =>
    DateTime(y, m, d, h, min).toIso8601String();

void main() {
  // Mercoledì 14 ottobre 2026, ore 18.
  final now = DateTime(2026, 10, 14, 18);

  group('Date in italiano', () {
    test('mese e giorno della settimana', () {
      expect(italianMonthName(DateTime(2026, 10, 17)), 'ottobre');
      expect(italianWeekdayName(DateTime(2026, 10, 17)), 'sabato');
      expect(italianWeekdayName(DateTime(2026, 10, 19)), 'lunedì');
    });

    test("articolo con elisione e primo del mese", () {
      expect(italianDayMonth(DateTime(2026, 10, 17)), 'il 17 ottobre');
      expect(italianDayMonth(DateTime(2026, 10, 8)), "l'8 ottobre");
      expect(italianDayMonth(DateTime(2026, 10, 11)), "l'11 ottobre");
      expect(italianDayMonth(DateTime(2026, 10, 1)), 'il 1° ottobre');
    });

    test('preposizione articolata con afterA', () {
      expect(italianDayMonth(DateTime(2026, 11, 12), afterA: true),
          'al 12 novembre');
      expect(italianDayMonth(DateTime(2026, 11, 8), afterA: true),
          "all'8 novembre");
      expect(italianDayMonth(DateTime(2026, 11, 1), afterA: true),
          'al 1° novembre');
    });
  });

  group('requestsMonthLabel', () {
    test('"a" davanti ai mesi, "ad" solo davanti ad a-', () {
      expect(requestsMonthLabel(DateTime(2026, 10, 3)), 'richieste a ottobre');
      expect(requestsMonthLabel(DateTime(2026, 4, 3)), 'richieste ad aprile');
      expect(requestsMonthLabel(DateTime(2026, 8, 3)), 'richieste ad agosto');
    });
  });

  group('nextEventLabel', () {
    test('nessuna serata', () {
      expect(nextEventLabel(null, now), 'nessuna serata in programma');
    });

    test('oggi, entro 6 giorni, oltre', () {
      expect(nextEventLabel(DateTime(2026, 10, 14, 22, 30), now),
          'confermati stasera');
      expect(nextEventLabel(DateTime(2026, 10, 17, 22, 30), now),
          'confermati sabato');
      expect(nextEventLabel(DateTime(2026, 10, 20, 22, 30), now),
          'confermati martedì');
      expect(nextEventLabel(DateTime(2026, 10, 21, 22, 30), now),
          'confermati il 21 ottobre');
    });

    test('il cambio d\'ora non sposta i giorni', () {
      // In Italia l'ora legale inizia domenica 29 marzo 2026.
      final saturday = DateTime(2026, 3, 28, 12);
      expect(nextEventLabel(DateTime(2026, 3, 29, 22), saturday),
          'confermati domenica');
      expect(nextEventLabel(DateTime(2026, 3, 30, 22), saturday),
          'confermati lunedì');
    });
  });

  group('eventsHostedBy', () {
    test('tiene solo le serate del gestore', () {
      final events = [
        _event(id: 'a', host: 'h1', date: _iso(2026, 10, 17)),
        _event(id: 'b', host: 'altro', date: _iso(2026, 10, 18)),
        _event(id: 'c', host: 'h1', date: _iso(2026, 10, 30)),
      ];
      expect(eventsHostedBy(events, 'h1').map((e) => e.id), ['a', 'c']);
    });
  });

  group('computeGestoreMetrics', () {
    test('richieste: solo il mese corrente, di qualunque stato', () {
      final requests = [
        _request(DateTime(2026, 10, 1)),
        _request(DateTime(2026, 10, 31, 23, 59)),
        _request(DateTime(2026, 10, 10), status: 'rejected'),
        _request(DateTime(2026, 9, 30, 23, 59)),
        _request(DateTime(2026, 11, 1)),
        _request(DateTime(2025, 10, 10)),
        _request(null),
      ];
      final m = computeGestoreMetrics(
          hostEvents: const [], requests: requests, now: now);
      expect(m.requestsThisMonth, 3);
      expect(m.requestsValue, '3');
      expect(m.requestsLabel, 'richieste a ottobre');
    });

    test('riempimento: media delle serate concluse, con tetto al 100%', () {
      final events = [
        _event(id: 'a', date: _iso(2026, 10, 3), max: 10, approved: 8),
        _event(id: 'b', date: _iso(2026, 10, 10), max: 10, approved: 10),
        _event(id: 'c', date: _iso(2026, 9, 26), max: 10, approved: 12),
        _event(id: 'd', date: _iso(2026, 9, 19), max: 0, approved: 0),
        _event(id: 'e', date: _iso(2026, 10, 17), max: 10, approved: 1),
      ];
      final m = computeGestoreMetrics(
          hostEvents: events, requests: const [], now: now);
      expect(m.averageFill, closeTo((0.8 + 1 + 1) / 3, 1e-9));
      expect(m.fillValue, '93%');
      expect(m.fillLabel, 'riempimento medio');
    });

    test('riempimento senza serate concluse è un trattino', () {
      final m = computeGestoreMetrics(
        hostEvents: [_event(date: _iso(2026, 10, 17), approved: 5)],
        requests: const [],
        now: now,
      );
      expect(m.averageFill, isNull);
      expect(m.fillValue, '—');
    });

    test('prossima serata: la futura più vicina', () {
      final events = [
        _event(id: 'lontana', date: _iso(2026, 10, 30), max: 20),
        _event(id: 'passata', date: _iso(2026, 10, 10), max: 20),
        _event(id: 'sabato', date: _iso(2026, 10, 17), max: 32, approved: 28),
        _event(id: 'rotta', date: 'non-una-data', max: 20),
      ];
      final m = computeGestoreMetrics(
          hostEvents: events, requests: const [], now: now);
      expect(m.nextEvent?.id, 'sabato');
      expect(m.nextValue, '28/32');
      expect(m.nextLabel, 'confermati sabato');
    });

    test('senza serate: zero richieste e trattini', () {
      final m = computeGestoreMetrics(
          hostEvents: const [], requests: const [], now: now);
      expect(m.requestsValue, '0');
      expect(m.fillValue, '—');
      expect(m.nextValue, '—');
      expect(m.nextLabel, 'nessuna serata in programma');
    });
  });

  group('GestoreMetricsStrip', () {
    Future<void> pumpStrip(WidgetTester tester, GestoreMetrics metrics) {
      return tester.pumpWidget(MaterialApp(
        theme: ecoraTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: GestoreMetricsStrip(metrics: metrics),
          ),
        ),
      ));
    }

    testWidgets('mostra i tre numeri con le etichette', (tester) async {
      final m = computeGestoreMetrics(
        hostEvents: [
          _event(id: 'a', date: _iso(2026, 10, 3), max: 10, approved: 9),
          _event(id: 'b', date: _iso(2026, 10, 17), max: 32, approved: 28),
        ],
        requests: [_request(DateTime(2026, 10, 2))],
        now: now,
      );
      await pumpStrip(tester, m);

      expect(find.text('1'), findsOneWidget);
      expect(find.text('richieste a ottobre'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('riempimento medio'), findsOneWidget);
      expect(find.text('28/32'), findsOneWidget);
      expect(find.text('confermati sabato'), findsOneWidget);
    });

    testWidgets('senza dati mostra i trattini', (tester) async {
      await pumpStrip(
        tester,
        computeGestoreMetrics(
            hostEvents: const [], requests: const [], now: now),
      );
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('nessuna serata in programma'), findsOneWidget);
    });

    testWidgets('numeri lunghi su schermo stretto non sforano',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final m = computeGestoreMetrics(
        hostEvents: [
          _event(date: _iso(2026, 10, 17), max: 150, approved: 128),
        ],
        requests: List.generate(1200, (_) => _request(DateTime(2026, 10, 2))),
        now: now,
      );
      await pumpStrip(tester, m);

      expect(tester.takeException(), isNull);
      expect(find.text('128/150'), findsOneWidget);
      expect(find.text('1200'), findsOneWidget);
    });
  });
}
