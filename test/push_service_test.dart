// Block 4.3a: pure-logic tests for push token registration.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/push_service.dart';

void main() {
  group('deviceTokenRow', () {
    test('maps to the device_tokens columns', () {
      final row = deviceTokenRow('uid1', 'tok123', 'android');
      expect(row, {
        'user_id': 'uid1',
        'token': 'tok123',
        'platform': 'android',
      });
    });

    test('keeps arbitrary platform labels as-is', () {
      expect(deviceTokenRow('u', 't', 'iOS')['platform'], 'iOS');
    });
  });
}
