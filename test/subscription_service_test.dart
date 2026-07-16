import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:ecora/subscription_service.dart';

void main() {
  group('SubscriptionStatus.fromRow', () {
    test('maps a full row from the subscriptions table', () {
      final status = SubscriptionStatus.fromRow({
        'user_id': 'abc-123',
        'product_id': 'ecora_gestore_monthly',
        'purchase_token': 'tok',
        'expiry_time': '2026-08-16T10:00:00+00:00',
        'auto_renewing': true,
        'last_verified_at': '2026-07-16T10:00:00+00:00',
      });

      expect(status.productId, 'ecora_gestore_monthly');
      expect(status.expiryTime, DateTime.parse('2026-08-16T10:00:00+00:00'));
      expect(status.autoRenewing, isTrue);
      expect(
          status.lastVerifiedAt, DateTime.parse('2026-07-16T10:00:00+00:00'));
    });

    test('tolerates missing or malformed fields', () {
      final status = SubscriptionStatus.fromRow({
        'expiry_time': 'non-una-data',
        'auto_renewing': null,
      });

      expect(status.productId, kSubscriptionProductId);
      expect(status.expiryTime, isNull);
      expect(status.autoRenewing, isFalse);
      expect(status.lastVerifiedAt, isNull);
      expect(status.isActiveAt(DateTime.now()), isFalse);
    });
  });

  group('SubscriptionStatus.isActiveAt', () {
    SubscriptionStatus withExpiry(DateTime expiry) => SubscriptionStatus(
          productId: kSubscriptionProductId,
          expiryTime: expiry,
          autoRenewing: false,
          lastVerifiedAt: null,
        );

    test('active when expiry is in the future', () {
      final now = DateTime.utc(2026, 7, 16, 12);
      expect(withExpiry(DateTime.utc(2026, 7, 17)).isActiveAt(now), isTrue);
    });

    test('inactive when expiry is in the past or equal to now', () {
      final now = DateTime.utc(2026, 7, 16, 12);
      expect(withExpiry(DateTime.utc(2026, 7, 15)).isActiveAt(now), isFalse);
      expect(withExpiry(now).isActiveAt(now), isFalse);
    });
  });

  group('shouldVerifyPurchase', () {
    test('true for our product in purchased or restored state', () {
      expect(
          shouldVerifyPurchase(
              kSubscriptionProductId, PurchaseStatus.purchased),
          isTrue);
      expect(
          shouldVerifyPurchase(
              kSubscriptionProductId, PurchaseStatus.restored),
          isTrue);
    });

    test('false for pending, error, canceled or other products', () {
      expect(
          shouldVerifyPurchase(kSubscriptionProductId, PurchaseStatus.pending),
          isFalse);
      expect(
          shouldVerifyPurchase(kSubscriptionProductId, PurchaseStatus.error),
          isFalse);
      expect(
          shouldVerifyPurchase(
              kSubscriptionProductId, PurchaseStatus.canceled),
          isFalse);
      expect(shouldVerifyPurchase('altro_prodotto', PurchaseStatus.purchased),
          isFalse);
    });
  });
}
