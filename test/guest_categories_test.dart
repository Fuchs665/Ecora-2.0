import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/attendance.dart';
import 'package:ecora/category_limits_field.dart';
import 'package:ecora/gestore_events.dart';
import 'package:ecora/guest_categories.dart';
import 'package:ecora/models.dart';
import 'package:ecora/theme.dart';

SupabaseEvent _event({
  int? couples,
  int? women,
  int? men,
  int approvedCouples = 0,
  int approvedWomen = 0,
  int approvedMen = 0,
  String? date,
}) =>
    SupabaseEvent(
      id: 'e1',
      title: 'Serata',
      description: '',
      organizerId: 'h1',
      latitude: 0,
      longitude: 0,
      imageUrl: '',
      eventDate: date ?? DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      maxParticipants: 10,
      currentApprovedCount: 4,
      maxCouples: couples,
      maxWomen: women,
      maxMen: men,
      approvedCouples: approvedCouples,
      approvedWomen: approvedWomen,
      approvedMen: approvedMen,
    );

void main() {
  group('guestCategoryOf', () {
    test('stesse tipologie della registrazione e della 0022', () {
      expect(guestCategoryOf('Coppia U/D'), GuestCategory.coppia);
      expect(guestCategoryOf('Coppia D/D'), GuestCategory.coppia);
      expect(guestCategoryOf('Coppia U/U'), GuestCategory.coppia);
      expect(guestCategoryOf('Donna Singola'), GuestCategory.donna);
      expect(guestCategoryOf('Uomo Singolo'), GuestCategory.uomo);
      expect(guestCategoryOf(null), isNull);
      expect(guestCategoryOf('Altro'), isNull);
    });

    test('la migrazione usa gli stessi valori', () {
      final sql = File('supabase/migrations/0022_posti_per_tipologia.sql')
          .readAsStringSync();
      for (final t in [
        'Coppia U/D', 'Coppia D/D', 'Coppia U/U', 'Donna Singola',
        'Uomo Singolo'
      ]) {
        expect(sql, contains("'$t'"), reason: t);
      }
    });

    test('la registrazione offre solo tipologie riconosciute', () {
      final main = File('lib/main.dart').readAsStringSync();
      final block = RegExp(r'_profileTypes = \[(.*?)\];', dotAll: true)
          .firstMatch(main)!
          .group(1)!;
      final types = RegExp(r'"([^"]+)"').allMatches(block).map((m) => m[1]);
      expect(types, isNotEmpty);
      for (final t in types) {
        expect(guestCategoryOf(t), isNotNull, reason: t);
      }
    });
  });

  group('categoryLimitsLabel', () {
    test('solo le categorie con limite', () {
      expect(
          categoryLimitsLabel(_event(
              couples: 6, women: 2, men: 2,
              approvedCouples: 3, approvedWomen: 1)),
          'Coppie 3/6 · Donne 1/2 · Uomini 0/2');
      expect(categoryLimitsLabel(_event(women: 2, approvedWomen: 1)),
          'Donne 1/2');
      expect(categoryLimitsLabel(_event()), '');
    });

    test('letto da get_events_with_stats', () {
      final e = SupabaseEvent.fromStats({
        'id': 'e',
        'max_guests': 8,
        'approved_count': 3,
        'max_couples': 4,
        'max_women': null,
        'max_men': 0,
        'approved_couples': 2,
        'approved_women': 1,
        'approved_men': 0,
      });
      expect(e.maxCouples, 4);
      expect(e.maxWomen, isNull);
      expect(e.maxMen, 0);
      expect(categoryLimitsLabel(e), 'Coppie 2/4 · Uomini 0/0');
      final old = SupabaseEvent.fromStats({'id': 'e', 'max_guests': 8});
      expect(categoryLimitsLabel(old), '', reason: 'feed di prima della 0022');
    });
  });

  test('messaggi dai codici del trigger', () {
    expect(capacityErrorMessage('EC001'), 'Serata al completo.');
    expect(capacityErrorMessage('EC002'), 'Posti per le coppie esauriti.');
    expect(capacityErrorMessage('EC003'), 'Posti per le donne esauriti.');
    expect(capacityErrorMessage('EC004'), 'Posti per gli uomini esauriti.');
    expect(capacityErrorMessage('42501'), isNull);
  });

  test('i codici della migrazione sono quelli gestiti dall\'app', () {
    final sql = File('supabase/migrations/0022_posti_per_tipologia.sql')
        .readAsStringSync();
    for (final code in ['EC001', 'EC002', 'EC003', 'EC004']) {
      expect(sql, contains("'$code'"));
      expect(capacityErrorMessage(code), isNotNull);
    }
  });

  group('contatori', () {
    test('più e meno', () {
      expect(incrementLimit(null, 8), 1);
      expect(incrementLimit(3, 8), 4);
      expect(incrementLimit(8, 8), 8, reason: 'mai oltre il totale');
      expect(decrementLimit(1), 0);
      expect(decrementLimit(0), isNull, reason: 'da 0 a nessun limite');
      expect(decrementLimit(null), isNull);
    });

    test('il totale che scende trascina i limiti', () {
      expect(clampLimit(10, 6), 6);
      expect(clampLimit(3, 6), 3);
      expect(clampLimit(null, 6), isNull);
    });
  });

  group('Porta', () {
    final start = DateTime(2026, 10, 10, 22);
    SupabaseEvent at(DateTime d) => _event(date: d.toIso8601String());

    test('dall\'inizio fino a 12 ore dopo', () {
      expect(isAtDoor(at(start), start.subtract(const Duration(minutes: 1))),
          isFalse);
      expect(isAtDoor(at(start), start), isTrue);
      expect(isAtDoor(at(start), start.add(const Duration(hours: 11))), isTrue);
      expect(isAtDoor(at(start), start.add(const Duration(hours: 12))), isFalse);
      expect(kDoorButton, 'Porta');
    });
  });

  testWidgets('CategoryLimitsField: testi e contatori', (tester) async {
    final limits = <GuestCategory, int?>{
      GuestCategory.coppia: null,
      GuestCategory.donna: 2,
      GuestCategory.uomo: 0,
    };
    final changes = <String>[];
    await tester.pumpWidget(MaterialApp(
      theme: ecoraTheme(),
      home: Scaffold(
        body: CategoryLimitsField(
          total: 2,
          limits: limits,
          onChanged: (c, v) => changes.add('${c.name}=$v'),
        ),
      ),
    ));
    expect(find.text('Posti per tipologia (facoltativo)'), findsOneWidget);
    expect(find.text('Lascia "Nessun limite" se ti basta il totale.'),
        findsOneWidget);
    expect(find.text('Coppie'), findsOneWidget);
    expect(find.text('Donne'), findsOneWidget);
    expect(find.text('Uomini'), findsOneWidget);
    expect(find.text('Nessun limite'), findsOneWidget);

    final adds = find.byIcon(Icons.add);
    final removes = find.byIcon(Icons.remove);
    // Coppie: nessun limite -> "meno" spento, "più" porta a 1.
    expect(tester.widget<IconButton>(find.ancestor(of: removes.at(0), matching: find.byType(IconButton))).onPressed, isNull);
    await tester.tap(adds.at(0));
    // Donne a 2 su 2: "più" spento.
    expect(tester.widget<IconButton>(find.ancestor(of: adds.at(1), matching: find.byType(IconButton))).onPressed, isNull);
    // Uomini a 0: "meno" torna a nessun limite.
    await tester.tap(removes.at(2));
    expect(changes, ['coppia=1', 'uomo=null']);
  });

  testWidgets('NextEventCard mostra i posti per tipologia', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ecoraTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: NextEventCard(
            event: _event(couples: 6, approvedCouples: 3),
            pendingCount: 0,
            onTap: () {},
            onEvaluate: () {},
          ),
        ),
      ),
    ));
    expect(find.text('Coppie 3/6'), findsOneWidget);
  });
}
