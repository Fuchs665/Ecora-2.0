import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/device_tilt.dart';
import 'package:ecora/theme.dart';

const _flat = Gravity(0, 0, 9.81);

/// Gravità del telefono girato di [deg] gradi verso destra (asse y).
Gravity _right(double deg) {
  final r = deg * math.pi / 180;
  return Gravity(-9.81 * math.sin(r), 0, 9.81 * math.cos(r));
}

/// Gravità del telefono inclinato di [deg] gradi verso l'utente (asse x).
Gravity _towards(double deg) {
  final r = deg * math.pi / 180;
  return Gravity(0, 9.81 * math.sin(r), 9.81 * math.cos(r));
}

void main() {
  group('tiltFrom', () {
    test('fermo: nessuna inclinazione', () {
      expect(tiltFrom(_flat, _flat), Offset.zero);
      expect(tiltFrom(_right(30), _right(30)), Offset.zero,
          reason: 'conta la posizione di partenza, non quella assoluta');
    });

    test('verso destra e verso l\'utente', () {
      final r = tiltFrom(_flat, _right(10));
      expect(r.dx, greaterThan(0));
      expect(r.dy, closeTo(0, 1e-9));
      final t = tiltFrom(_flat, _towards(10));
      expect(t.dy, greaterThan(0));
      expect(t.dx, closeTo(0, 1e-9));
    });

    test('limitata a ±1', () {
      final r = tiltFrom(_flat, _right(80));
      expect(r.dx, 1);
      expect(tiltFrom(_flat, _right(-80)).dx, -1);
    });

    test('gravità nulla non rompe il calcolo', () {
      expect(tiltFrom(const Gravity(0, 0, 0), _flat), Offset.zero);
    });
  });

  test('smoothTilt avvicina senza saltare', () {
    final s = smoothTilt(Offset.zero, const Offset(1, 0));
    expect(s.dx, closeTo(kTiltSmoothing, 1e-9));
  });

  test('coverTiltMatrix: dritta a zero, prospettiva sempre', () {
    final m = coverTiltMatrix(Offset.zero);
    expect(m.entry(3, 2), closeTo(1 / EcoraDepth.perspectiveScreen, 1e-12));
    expect(m.entry(0, 0), 1);
    final tilted = coverTiltMatrix(const Offset(1, 0));
    expect(tilted.entry(0, 0),
        closeTo(math.cos(EcoraDepth.tiltMaxDegrees * math.pi / 180), 1e-9));
  });

  group('DeviceTilt', () {
    late StreamController<Gravity> sensor;
    late int listens;

    Future<void> pump(WidgetTester tester, {bool reduced = false}) async {
      sensor = StreamController<Gravity>.broadcast();
      listens = 0;
      sensor.onListen = () => listens++;
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: DeviceTilt(
              source: () => sensor.stream,
              child: const Column(
                children: [
                  TiltingCover(child: SizedBox(width: 200, height: 100)),
                  TiltParallax(
                    distance: EcoraDepth.parallaxLayer,
                    direction: -1,
                    child: Text('Titolo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    Matrix4 coverMatrix(WidgetTester tester) => tester
        .widget<Transform>(find
            .descendant(
                of: find.byType(TiltingCover), matching: find.byType(Transform))
            .first)
        .transform;

    double titleShift(WidgetTester tester) => tester
        .widget<Transform>(find
            .descendant(
                of: find.byType(TiltParallax), matching: find.byType(Transform))
            .first)
        .transform
        .getTranslation()
        .x;

    testWidgets('la copertina si inclina e il titolo va al contrario',
        (tester) async {
      await pump(tester);
      expect(listens, 1);
      sensor.add(_flat); // posizione di partenza
      for (var i = 0; i < 40; i++) {
        sensor.add(_right(15));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(coverMatrix(tester).entry(0, 0), lessThan(1),
          reason: 'ruotata sull\'asse verticale');
      expect(titleShift(tester), lessThan(0));
      expect(titleShift(tester), greaterThanOrEqualTo(-EcoraDepth.parallaxLayer));
    });

    testWidgets('animazioni ridotte: nessun ascolto, copertina dritta',
        (tester) async {
      await pump(tester, reduced: true);
      expect(listens, 0);
      expect(coverMatrix(tester).entry(0, 0), 1);
      expect(titleShift(tester), 0);
    });

    testWidgets('sensore in errore: nessuna eccezione, copertina dritta',
        (tester) async {
      await pump(tester);
      sensor.add(_flat);
      sensor.add(_right(20));
      await tester.pump();
      sensor.addError(Exception('nessun sensore'));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(sensor.hasListener, isFalse, reason: 'smette di ascoltare');
      expect(coverMatrix(tester).entry(0, 0), 1);
    });

    testWidgets('app in background: smette di ascoltare', (tester) async {
      await pump(tester);
      expect(sensor.hasListener, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(sensor.hasListener, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(sensor.hasListener, isTrue);
    });

    testWidgets('senza DeviceTilt sopra: nessuna inclinazione', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: TiltingCover(child: SizedBox(width: 10, height: 10)),
      ));
      expect(coverMatrix(tester).entry(0, 0), 1);
    });
  });
}
