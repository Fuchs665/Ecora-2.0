// Block 4.1: pure-logic tests for event chat (no plugins, no network).

import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/main.dart';

void main() {
  group('ChatMessage.fromRow', () {
    test('maps a full row from the messages table', () {
      final msg = ChatMessage.fromRow({
        'id': 'm1',
        'event_id': 'e1',
        'sender_id': 'u1',
        'content': 'Ciao a tutti',
        'created_at': '2026-07-04T21:30:00Z',
      });
      expect(msg.id, 'm1');
      expect(msg.eventId, 'e1');
      expect(msg.senderId, 'u1');
      expect(msg.content, 'Ciao a tutti');
      expect(msg.createdAt, isNotNull);
    });

    test('tolerates missing or malformed fields', () {
      final msg = ChatMessage.fromRow({'created_at': 'not-a-date'});
      expect(msg.id, '');
      expect(msg.eventId, '');
      expect(msg.senderId, '');
      expect(msg.content, '');
      expect(msg.createdAt, isNull);
    });
  });

  group('activeChatEventsForClient', () {
    SupabaseEvent buildEvent(String id) => SupabaseEvent(
          id: id,
          title: 'Evento $id',
          description: 'desc',
          organizerId: 'host1',
          latitude: 43.7695,
          longitude: 11.2558,
          imageUrl: 'https://example.com/img.jpg',
          eventDate: '2026-07-10T21:00:00',
          maxParticipants: 10,
        );

    SupabaseParticipationRequest buildRequest(
            String eventId, String userId, String status) =>
        SupabaseParticipationRequest(
            id: '$eventId-$userId',
            userId: userId,
            eventId: eventId,
            status: status);

    final events = [buildEvent('e1'), buildEvent('e2'), buildEvent('e3')];

    test('returns only events with an approved request of the user', () {
      final requests = [
        buildRequest('e1', 'me', 'approved'),
        buildRequest('e2', 'me', 'pending'),
        buildRequest('e3', 'someone-else', 'approved'),
      ];
      final chats = EcoraDataService.instance
          .activeChatEventsForClient(events, requests, 'me');
      expect(chats.map((e) => e.id), ['e1']);
    });

    test('returns empty list when the user has no approved requests', () {
      final requests = [buildRequest('e1', 'me', 'rejected')];
      final chats = EcoraDataService.instance
          .activeChatEventsForClient(events, requests, 'me');
      expect(chats, isEmpty);
    });
  });
}
