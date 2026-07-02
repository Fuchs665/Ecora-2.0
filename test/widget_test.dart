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

  group('SupabaseEvent.fromStats', () {
    test('maps real DB keys (host_id, max_guests, approved_count)', () {
      final e = SupabaseEvent.fromStats({
        'id': 'abc',
        'host_id': 'host-1',
        'title': 'Serata',
        'description': 'desc',
        'event_date': '2026-07-10T21:00:00+00:00',
        'max_guests': 12,
        'status': 'published',
        'latitude': 43.7,
        'longitude': 11.2,
        'image_url': 'https://example.com/x.jpg',
        'location_name': 'Villa X',
        'approved_count': 4,
      });
      expect(e.organizerId, 'host-1');
      expect(e.maxParticipants, 12);
      expect(e.currentApprovedCount, 4);
      expect(e.imageUrl, 'https://example.com/x.jpg');
      expect(e.locationName, 'Villa X');
      expect(e.tableCompletionPercentage, closeTo(4 / 12, 0.0001));
    });

    test('null image/location/counters fall back to safe defaults', () {
      final e = SupabaseEvent.fromStats({
        'id': 'abc',
        'host_id': 'h',
        'title': 't',
        'description': null,
        'event_date': '2026-07-10T21:00:00+00:00',
        'max_guests': null,
        'latitude': null,
        'longitude': null,
        'image_url': null,
        'location_name': null,
        'approved_count': null,
      });
      expect(e.imageUrl, contains('unsplash'));
      expect(e.locationName, 'Località riservata');
      expect(e.maxParticipants, 0);
      expect(e.currentApprovedCount, 0);
      expect(e.tableCompletionPercentage, 0.0);
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

  group('SupabaseProfile.fromRow', () {
    test('maps real profiles row and derives gender from profile_type', () {
      final p = SupabaseProfile.fromRow({
        'id': 'u-1',
        'nickname': 'AlexSofia',
        'role': 'gestore',
        'profile_type': 'Coppia U/D',
        'privacy_level': 'ghost',
        'generic_location': 'Firenze',
        'is_verified': false,
      });
      expect(p.id, 'u-1');
      expect(p.fullName, 'AlexSofia');
      expect(p.role, 'gestore');
      expect(p.gender, 'Coppia');
      expect(p.profileType, 'Coppia U/D');
      expect(p.privacyLevel, 'ghost');
    });

    test('null nickname/role/profile_type fall back to safe defaults', () {
      final p = SupabaseProfile.fromRow({'id': 'u-2'});
      expect(p.fullName, 'Utente Anonimo');
      expect(p.role, 'cliente');
      expect(p.gender, 'Coppia');
      expect(p.profileType, isNull);
    });

    test('single profile types derive Donna/Uomo', () {
      expect(
        SupabaseProfile.fromRow(
            {'id': 'x', 'profile_type': 'Donna Singola'}).gender,
        'Donna',
      );
      expect(
        SupabaseProfile.fromRow(
            {'id': 'x', 'profile_type': 'Uomo Singolo'}).gender,
        'Uomo',
      );
    });
  });

  group('SupabaseParticipationRequest.fromRow', () {
    test('maps real event_requests row', () {
      final r = SupabaseParticipationRequest.fromRow({
        'id': 'req-1',
        'event_id': 'ev-9',
        'user_id': 'u-7',
        'status': 'approved',
        'created_at': '2026-07-01T10:00:00+00:00',
      });
      expect(r.id, 'req-1');
      expect(r.eventId, 'ev-9');
      expect(r.userId, 'u-7');
      expect(r.status, 'approved');
    });

    test('null status defaults to pending', () {
      final r = SupabaseParticipationRequest.fromRow(
          {'id': 'x', 'event_id': 'e', 'user_id': 'u'});
      expect(r.status, 'pending');
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
