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
