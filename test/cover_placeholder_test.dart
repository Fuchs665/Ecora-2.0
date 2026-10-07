import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/cover_placeholder.dart';
import 'package:ecora/models.dart';
import 'package:ecora/motion.dart';

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('EcoraNetworkImage', () {
    for (final reduced in [false, true]) {
      testWidgets('URL vuoto mostra il placeholder (animazioni ridotte: $reduced)',
          (tester) async {
        await tester.pumpWidget(_host(
          const SizedBox(
            width: 120,
            height: 80,
            child: EcoraNetworkImage(url: '', width: 120, height: 80),
          ),
          reduced: reduced,
        ));
        expect(find.byType(CoverPlaceholder), findsOneWidget);
        expect(tester.getSize(find.byType(CoverPlaceholder)),
            const Size(120, 80));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('dentro un EcoraHero non rompe il volo', (tester) async {
      await tester.pumpWidget(_host(
        const EcoraHero(
          tag: 'event-cover-x',
          child: EcoraNetworkImage(url: '  ', width: 64, height: 64),
        ),
      ));
      expect(find.byType(Hero), findsOneWidget);
      expect(find.byType(CoverPlaceholder), findsOneWidget);
    });
  });

  group('Luce generata (Blocco D.3)', () {
    test('stesso id, stessa luce', () {
      expect(LuceSeed.fromId('abc-123'), LuceSeed.fromId('abc-123'));
    });

    test('id diversi, luci diverse', () {
      final ids = List.generate(50, (i) => 'serata-$i');
      final seeds = ids.map(LuceSeed.fromId).toSet();
      expect(seeds.length, ids.length);
    });

    test('bagliori sempre tra il 20% e il 90%', () {
      for (var i = 0; i < 200; i++) {
        final s = LuceSeed.fromId('f0194d85-$i-4ecf-84e4-af2c1e7bc6db');
        for (final o in [s.amber, s.emerald, s.teal]) {
          expect(o.dx, inInclusiveRange(0.2, 0.9));
          expect(o.dy, inInclusiveRange(0.2, 0.9));
        }
      }
    });

    test('il painter ridisegna solo se cambiano seme o fase', () {
      final a = LucePainter(seed: LuceSeed.fromId('a'));
      expect(a.shouldRepaint(LucePainter(seed: LuceSeed.fromId('a'))), isFalse);
      expect(a.shouldRepaint(LucePainter(seed: LuceSeed.fromId('b'))), isTrue);
      expect(
          a.shouldRepaint(LucePainter(seed: LuceSeed.fromId('a'), phase: 0.5)),
          isTrue);
    });

    Future<void> pumpCover(WidgetTester tester,
        {required bool animated, required bool reduced}) {
      return tester.pumpWidget(_host(
        EcoraNetworkImage(
          url: '',
          width: 200,
          height: 120,
          seedId: 'e1',
          animated: animated,
        ),
        reduced: reduced,
      ));
    }

    LucePainter painter(WidgetTester tester) => tester
        .widget<CustomPaint>(find.descendant(
            of: find.byType(CoverPlaceholder),
            matching: find.byType(CustomPaint)))
        .painter as LucePainter;

    testWidgets('la copertina usa la luce della serata', (tester) async {
      await pumpCover(tester, animated: false, reduced: false);
      expect(painter(tester).seed, LuceSeed.fromId('e1'));
    });

    testWidgets('luce viva: si muove nel tempo', (tester) async {
      await pumpCover(tester, animated: true, reduced: false);
      final before = painter(tester).phase;
      await tester.pump(const Duration(seconds: 3));
      expect(painter(tester).phase, isNot(before));
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('animazioni ridotte: luce ferma', (tester) async {
      await pumpCover(tester, animated: true, reduced: true);
      expect(tester.hasRunningAnimations, isFalse);
      expect(painter(tester).phase, 0);
    });

    testWidgets('nelle liste: luce ferma', (tester) async {
      await pumpCover(tester, animated: false, reduced: false);
      expect(tester.hasRunningAnimations, isFalse);
    });

    test('ciclo di 13 secondi', () {
      expect(kLuceCycle, const Duration(seconds: 13));
    });
  });

  test('senza image_url la serata non usa foto hardcoded', () {
    final e = SupabaseEvent.fromStats({'id': '1', 'title': 't'});
    expect(e.imageUrl, '');
  });

  test('nessuna foto Unsplash hardcoded in lib/', () {
    final hits = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('unsplash'))
        .map((f) => f.path)
        .toList();
    expect(hits, isEmpty);
  });
}
