import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/subscription_panel.dart';
import 'package:ecora/subscription_service.dart';

SubscriptionStatus _status({
  required DateTime? expiry,
  bool autoRenewing = false,
}) {
  return SubscriptionStatus(
    productId: kSubscriptionProductId,
    expiryTime: expiry,
    autoRenewing: autoRenewing,
    lastVerifiedAt: null,
  );
}

void main() {
  tearDown(() {
    // I notifier sono su un singleton: si ripuliscono tra un test e l'altro.
    EcoraSubscriptionService.instance.reset();
  });

  group('formatExpiryDate', () {
    test('null becomes an em dash', () {
      expect(formatExpiryDate(null), '—');
    });

    test('formats as dd/mm/yyyy with zero padding', () {
      expect(formatExpiryDate(DateTime(2026, 8, 16)), '16/08/2026');
      expect(formatExpiryDate(DateTime(2026, 1, 5)), '05/01/2026');
    });
  });

  group('subscriptionStatusLabel', () {
    final now = DateTime(2026, 7, 16, 12);

    test('null or expired status reads as inactive', () {
      expect(subscriptionStatusLabel(null, now), 'Nessun abbonamento attivo');
      expect(
        subscriptionStatusLabel(_status(expiry: DateTime(2026, 7, 1)), now),
        'Nessun abbonamento attivo',
      );
    });

    test('active with auto renew mentions the renewal date', () {
      expect(
        subscriptionStatusLabel(
            _status(expiry: DateTime(2026, 8, 16), autoRenewing: true), now),
        'Attivo • si rinnova il 16/08/2026',
      );
    });

    test('active without auto renew mentions the end date', () {
      expect(
        subscriptionStatusLabel(_status(expiry: DateTime(2026, 8, 16)), now),
        'Attivo fino al 16/08/2026',
      );
    });
  });

  group('subscriptionActiveLine', () {
    test('con rinnovo automatico indica la data del rinnovo', () {
      expect(
        subscriptionActiveLine(
            _status(expiry: DateTime(2026, 8, 16), autoRenewing: true)),
        'Abbonamento attivo · si rinnova il 16 agosto',
      );
    });

    test('senza rinnovo indica la scadenza, con l\'articolo giusto', () {
      expect(subscriptionActiveLine(_status(expiry: DateTime(2026, 11, 12))),
          'Abbonamento attivo fino al 12 novembre');
      expect(subscriptionActiveLine(_status(expiry: DateTime(2026, 11, 8))),
          "Abbonamento attivo fino all'8 novembre");
    });

    test('senza data resta solo lo stato', () {
      expect(subscriptionActiveLine(_status(expiry: null)),
          'Abbonamento attivo');
    });
  });

  test('il link "Gestisci" apre gli abbonamenti Play di Ecora', () {
    expect(kManageSubscriptionUri.host, 'play.google.com');
    expect(kManageSubscriptionUri.path, '/store/account/subscriptions');
    expect(kManageSubscriptionUri.queryParameters, {
      'sku': kSubscriptionProductId,
      'package': 'com.ecora.app',
    });
  });

  group('SubscriptionStatusCard', () {
    Future<void> pumpCard(WidgetTester tester) {
      return tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SubscriptionStatusCard()),
      ));
    }

    testWidgets('without subscription shows the purchase CTA',
        (tester) async {
      EcoraSubscriptionService.instance.statusNotifier.value = null;
      await pumpCard(tester);

      expect(find.text('ABBONAMENTO GESTORE'), findsOneWidget);
      expect(find.text('Nessun abbonamento attivo'), findsOneWidget);
      expect(find.text('Abbonati'), findsOneWidget);
      expect(find.text('Ripristina'), findsOneWidget);
    });

    testWidgets('with active subscription becomes a discreet line',
        (tester) async {
      EcoraSubscriptionService.instance.statusNotifier.value = _status(
        expiry: DateTime.now().add(const Duration(days: 30)),
        autoRenewing: true,
      );
      await pumpCard(tester);

      expect(find.textContaining('Abbonamento attivo · si rinnova'),
          findsOneWidget);
      expect(find.text('Gestisci'), findsOneWidget);
      expect(find.text('ABBONAMENTO GESTORE'), findsNothing);
      expect(find.text('Abbonati'), findsNothing);
    });

    testWidgets('feedback is shown under the active line too',
        (tester) async {
      EcoraSubscriptionService.instance.statusNotifier.value = _status(
        expiry: DateTime.now().add(const Duration(days: 30)),
      );
      EcoraSubscriptionService.instance.feedbackNotifier.value =
          'Abbonamento ripristinato.';
      await pumpCard(tester);

      expect(find.text('Abbonamento ripristinato.'), findsOneWidget);
    });

    testWidgets('feedback from the purchase flow is shown and dismissable',
        (tester) async {
      EcoraSubscriptionService.instance.feedbackNotifier.value =
          'Pagamento in corso...';
      await pumpCard(tester);

      expect(find.text('Pagamento in corso...'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.text('Pagamento in corso...'), findsNothing);
      expect(
          EcoraSubscriptionService.instance.feedbackNotifier.value, isNull);
    });
  });
}
