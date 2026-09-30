import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/dashboard_skeleton.dart';
import 'package:ecora/gestore_dashboard.dart';
import 'package:ecora/gestore_metrics.dart';
import 'package:ecora/models.dart';
import 'package:ecora/subscription_service.dart';
import 'package:ecora/theme.dart';

// Stati della dashboard gestore (Blocco C.2): caricamento, vuoto, con serate.

final _host = SupabaseProfile(
  id: 'h1',
  fullName: 'Arcadia Club',
  role: 'gestore',
  gender: 'Coppia',
  genericLocation: 'Bologna',
);

SupabaseEvent _event(String id, String hostId) {
  return SupabaseEvent(
    id: id,
    title: 'Serata $id',
    description: '',
    organizerId: hostId,
    latitude: 0,
    longitude: 0,
    imageUrl: 'https://example.com/$id.jpg',
    eventDate: DateTime.now().add(const Duration(days: 3)).toIso8601String(),
    maxParticipants: 10,
    currentApprovedCount: 2,
  );
}

void main() {
  late int createCalls;

  tearDown(() {
    // I notifier sono su un singleton: si ripuliscono tra un test e l'altro.
    EcoraSubscriptionService.instance.reset();
  });

  Future<void> pump(
    WidgetTester tester, {
    required bool loading,
    List<SupabaseEvent> events = const [],
    bool disableAnimations = false,
  }) async {
    createCalls = 0;
    await tester.pumpWidget(MaterialApp(
      theme: ecoraTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: ClubDashboardScreen(
        host: _host,
        events: events,
        requests: const [],
        loading: loading,
        onSelectRequestInspector: () {},
        onCreateEvent: () => createCalls++,
      ),
    ));
  }

  /// Opacità dei segnaposto: condividono tutti la stessa animazione.
  double skeletonOpacity(WidgetTester tester) {
    final fade = tester.widget<FadeTransition>(find
        .descendant(
          of: find.byType(DashboardSkeleton),
          matching: find.byType(FadeTransition),
        )
        .first);
    return fade.opacity.value;
  }

  testWidgets('in caricamento: segnaposto, niente lista né stato vuoto',
      (tester) async {
    final semantics = tester.ensureSemantics();
    // Anche con serate già nel notifier (arrivate prima delle altre
    // letture, o rimaste dalla sessione precedente).
    await pump(tester, loading: true, events: [_event('e1', 'h1')]);

    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.bySemanticsLabel('Caricamento delle serate'), findsOneWidget);
    expect(find.text('Le tue serate'), findsOneWidget);
    expect(find.byType(GestoreMetricsStrip), findsNothing);
    expect(find.text('Serata e1'), findsNothing);
    expect(find.text('Nessuna serata in programma'), findsNothing);
    // Lo stato dell'abbonamento non è ancora noto: niente card d'acquisto.
    expect(find.text('ABBONAMENTO GESTORE'), findsNothing);
    semantics.dispose();
  });

  testWidgets('senza serate del gestore: stato vuoto che porta alla creazione',
      (tester) async {
    // Le serate di un altro locale non contano.
    await pump(tester, loading: false, events: [_event('altrui', 'h2')]);

    expect(find.byType(DashboardSkeleton), findsNothing);
    expect(find.byType(GestoreMetricsStrip), findsOneWidget);
    expect(find.text('Nessuna serata in programma'), findsOneWidget);
    expect(find.text('Serata altrui'), findsNothing);
    expect(find.text('I TUOI TAVOLI ATTIVI'), findsNothing);
    expect(find.text('ABBONAMENTO GESTORE'), findsOneWidget);

    final button = find.widgetWithText(ElevatedButton, 'Crea la prima serata');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(createCalls, 1);
  });

  testWidgets('con serate: lista visibile, niente segnaposto', (tester) async {
    await pump(tester, loading: false, events: [_event('e1', 'h1')]);

    expect(find.text('Serata e1'), findsOneWidget);
    expect(find.byType(GestoreMetricsStrip), findsOneWidget);
    expect(find.byType(DashboardSkeleton), findsNothing);
    expect(find.text('Nessuna serata in programma'), findsNothing);
  });

  testWidgets('la pulsazione gira quando le animazioni sono attive',
      (tester) async {
    await pump(tester, loading: true);
    final before = skeletonOpacity(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.hasRunningAnimations, isTrue);
    expect(skeletonOpacity(tester), isNot(before));
  });

  testWidgets('con "rimuovi animazioni" la pulsazione è ferma',
      (tester) async {
    await pump(tester, loading: true, disableAnimations: true);
    final before = skeletonOpacity(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.hasRunningAnimations, isFalse);
    expect(skeletonOpacity(tester), before);
    expect(before, 1.0);
  });
}
