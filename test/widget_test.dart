// Baseline smoke tests: pure logic only (no plugins, no network),
// so the suite stays green on any machine.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/main.dart';

void main() {
  group('SupabaseEvent', () {
    SupabaseEvent buildEvent({int max = 10, int approved = 5}) {
      return SupabaseEvent(
        id: 'e1',
        title: 'Test',
        description: 'desc',
        organizerId: 'org1',
        latitude: 43.7695,
        longitude: 11.2558,
        imageUrl: 'https://example.com/img.jpg',
        eventDate: '2026-07-10T21:00:00',
        maxParticipants: max,
        currentApprovedCount: approved,
      );
    }

    test('tableCompletionPercentage is approved/max', () {
      expect(buildEvent(max: 10, approved: 5).tableCompletionPercentage, 0.5);
    });

    test('tableCompletionPercentage is 0 when maxParticipants is 0', () {
      expect(buildEvent(max: 0, approved: 3).tableCompletionPercentage, 0.0);
    });

    test('copyWith preserves unchanged fields', () {
      final copy = buildEvent().copyWith(title: 'Nuovo titolo');
      expect(copy.title, 'Nuovo titolo');
      expect(copy.id, 'e1');
      expect(copy.maxParticipants, 10);
    });
  });

  group('Haversine distance', () {
    test('distance to self is zero', () {
      final d = SupabaseClient.instance
          .calculateHaversineDistance(43.7695, 11.2558, 43.7695, 11.2558);
      expect(d, 0.0);
    });

    test('Florence to Rome is roughly 230 km', () {
      final d = SupabaseClient.instance
          .calculateHaversineDistance(43.7695, 11.2558, 41.9028, 12.4964);
      expect(d, greaterThan(200));
      expect(d, lessThan(260));
    });
  });

  group('SupabaseProfile', () {
    test('copyWith updates only requested fields', () {
      final p = SupabaseProfile(
        id: 'u1',
        fullName: 'Alex & Sofia',
        role: 'cliente',
        age: 32,
        gender: 'Coppia',
      );
      final updated = p.copyWith(noShows: 2);
      expect(updated.noShows, 2);
      expect(updated.fullName, 'Alex & Sofia');
      expect(updated.role, 'cliente');
    });
  });
}
