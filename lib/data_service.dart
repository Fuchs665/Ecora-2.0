import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

// --- REACTIVE EXPERT SUPABASE SIMULATOR (Singleton Object) ---
// Note: This service wraps real Supabase queries in ValueNotifiers for legacy compatibility.
// In the future, this should be refactored to use standard StreamBuilders.

class EcoraDataService {
  static final EcoraDataService instance = EcoraDataService._internal();
  EcoraDataService._internal();

  final ValueNotifier<SupabaseProfile?> currentProfileNotifier =
      ValueNotifier(null);
  final ValueNotifier<List<SupabaseProfile>> profilesNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<SupabaseEvent>> eventsNotifier = ValueNotifier([]);
  final ValueNotifier<List<SupabaseParticipationRequest>> requestsNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<NotificationItem>> notificationsNotifier =
      ValueNotifier([]);
  final ValueNotifier<int> notificationBadgeNotifier = ValueNotifier(0);

  final List<SupabaseProfile> _profiles = [];
  List<SupabaseEvent> _events = [];
  List<SupabaseParticipationRequest> _requests = [];
  List<NotificationItem> _notifications = [];
  int _notificationBadgeCount = 0;

  void addProfile(SupabaseProfile p) {
    if (!_profiles.any((profile) => profile.id == p.id)) {
      _profiles.add(p);
      profilesNotifier.value = List.from(_profiles);
    }
  }

  Future<void> fetchEvents() async {
    try {
      final data =
          await Supabase.instance.client.rpc('get_events_with_stats');

      final List<SupabaseEvent> realEvents = (data as List)
          .map((item) =>
              SupabaseEvent.fromStats(Map<String, dynamic>.from(item as Map)))
          .toList();

      // La lista reale sostituisce completamente lo stato locale:
      // nessun merge con i dati demo. In caso di errore di rete si
      // mantiene l'ultimo elenco caricato.
      _events = realEvents;
      eventsNotifier.value = List.from(_events);
    } catch (e) {
      debugPrint("Errore nel recupero degli eventi reali da Supabase: $e");
    }
  }

  Future<void> logout() async {
    // Prima si sblocca la UI, poi si revoca la sessione in rete:
    // la chiamata HTTP non deve mai tenere l'utente bloccato sulla schermata.
    currentProfileNotifier.value = null;
    try {
      await Supabase.instance.client.auth
          .signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint("Errore durante il logout da Supabase: $e");
    }
  }

  /// Ripristina la sessione Supabase persistita (se presente) e carica
  /// il profilo reale, così l'utente non deve rifare il login a ogni avvio.
  Future<void> restoreSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final row = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', session.user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (row != null) {
        final prof = SupabaseProfile.fromRow(Map<String, dynamic>.from(row));
        addProfile(prof);
        currentProfileNotifier.value = prof;
      }
    } catch (e) {
      debugPrint("Errore ripristino sessione: $e");
    }
  }

  List<SupabaseEvent> getEventsWithinRadius(
      double userLat, double userLon, double maxDistanceKm) {
    return _events.where((event) {
      double dist = calculateHaversineDistance(
          userLat, userLon, event.latitude, event.longitude);
      return dist <= maxDistanceKm;
    }).toList();
  }

  double calculateHaversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371.0;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180.0;
  }

  /// Carica le richieste inviate dall'utente corrente (lato cliente),
  /// per colorare la mappa e gli stati degli eventi. Popola requestsNotifier.
  Future<void> fetchMyRequests() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final rows = await Supabase.instance.client
          .from('event_requests')
          .select()
          .eq('user_id', uid);
      _requests = (rows as List)
          .map((r) => SupabaseParticipationRequest.fromRow(
              Map<String, dynamic>.from(r as Map)))
          .toList();
      requestsNotifier.value = List.from(_requests);
    } catch (e) {
      debugPrint("Errore nel recupero delle richieste dell'utente: $e");
    }
  }

  /// Carica le richieste pendenti per gli eventi ospitati dal gestore
  /// corrente, insieme ai profili dei richiedenti (per la consolle di
  /// valutazione). Popola requestsNotifier.
  Future<void> fetchHostRequests() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final eventRows = await Supabase.instance.client
          .from('events')
          .select('id')
          .eq('host_id', uid);
      final eventIds =
          (eventRows as List).map((r) => r['id'].toString()).toList();
      if (eventIds.isEmpty) {
        _requests = [];
        requestsNotifier.value = [];
        return;
      }

      final reqRows = await Supabase.instance.client
          .from('event_requests')
          .select()
          .in_('event_id', eventIds);
      final requests = (reqRows as List)
          .map((r) => SupabaseParticipationRequest.fromRow(
              Map<String, dynamic>.from(r as Map)))
          .toList();

      // Profili dei richiedenti: caricati PRIMA di notificare la UI,
      // così getProfileById trova sempre il profilo in cache.
      final userIds = requests.map((r) => r.userId).toSet().toList();
      if (userIds.isNotEmpty) {
        final profRows = await Supabase.instance.client
            .from('profiles')
            .select()
            .in_('id', userIds);
        for (final row in (profRows as List)) {
          final prof =
              SupabaseProfile.fromRow(Map<String, dynamic>.from(row as Map));
          _profiles.removeWhere((p) => p.id == prof.id);
          _profiles.add(prof);
        }
        profilesNotifier.value = List.from(_profiles);
      }

      _requests = requests;
      requestsNotifier.value = List.from(_requests);
    } catch (e) {
      debugPrint("Errore nel recupero delle richieste reali: $e");
    }
  }

  /// Approva o rifiuta una richiesta sulla tabella reale, poi riallinea
  /// richieste ed eventi (approved_count). Ritorna null se ok.
  Future<String?> reviewParticipationRequest(
      String requestId, String status) async {
    try {
      await Supabase.instance.client
          .from('event_requests')
          .update({'status': status}).eq('id', requestId);
      await fetchHostRequests();
      await fetchEvents();
      return null;
    } catch (e) {
      debugPrint("Errore nella revisione della richiesta: $e");
      return "Operazione non riuscita. Riprova.";
    }
  }

  final ValueNotifier<List<SupabaseProfile>> blockedNotifier = ValueNotifier([]);

  /// Carica i profili degli utenti bloccati dall'utente corrente.
  Future<void> fetchBlockedUsers() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final blockRows = await Supabase.instance.client
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', uid);
      final blockedIds =
          (blockRows as List).map((r) => r['blocked_id'].toString()).toList();
      if (blockedIds.isEmpty) {
        blockedNotifier.value = [];
        return;
      }

      final profRows = await Supabase.instance.client
          .from('profiles')
          .select()
          .in_('id', blockedIds);
      final blocked = (profRows as List)
          .map((r) =>
              SupabaseProfile.fromRow(Map<String, dynamic>.from(r as Map)))
          .toList();
      blockedNotifier.value = blocked;
    } catch (e) {
      debugPrint("Errore nel recupero degli utenti bloccati: $e");
    }
  }

  /// Blocca un utente (bidirezionale lato RLS) e riallinea lo stato locale
  /// così i suoi contenuti spariscono immediatamente. Ritorna null se ok.
  Future<String?> blockUser(String targetUserId) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return "Sessione scaduta. Accedi di nuovo.";

      await Supabase.instance.client.from('blocks').insert({
        'blocker_id': uid,
        'blocked_id': targetUserId,
      });

      await Future.wait([
        fetchBlockedUsers(),
        fetchEvents(),
        fetchMyRequests(),
        fetchHostRequests(),
      ]);
      return null;
    } catch (e) {
      debugPrint("Errore durante il blocco utente: $e");
      return "Blocco non riuscito. Riprova.";
    }
  }

  /// Rimuove un blocco esistente. Ritorna null se ok.
  Future<String?> unblockUser(String targetUserId) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return "Sessione scaduta. Accedi di nuovo.";

      await Supabase.instance.client
          .from('blocks')
          .delete()
          .eq('blocker_id', uid)
          .eq('blocked_id', targetUserId);

      await Future.wait([
        fetchBlockedUsers(),
        fetchEvents(),
        fetchMyRequests(),
        fetchHostRequests(),
      ]);
      return null;
    } catch (e) {
      debugPrint("Errore durante lo sblocco utente: $e");
      return "Sblocco non riuscito. Riprova.";
    }
  }

  // Stato "visto/eliminato" delle notifiche: solo per sessione.
  // Una tabella notifications dedicata arriverà con le push (Fase 4).
  final Set<String> _seenNotificationIds = {};
  final Set<String> _dismissedNotificationIds = {};

  /// Deriva le notifiche reali del cliente dalle proprie richieste già
  /// valutate (approved/rejected), con il titolo dell'evento collegato.
  Future<void> fetchMyNotifications() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final reqRows = await Supabase.instance.client
          .from('event_requests')
          .select()
          .eq('user_id', uid)
          .neq('status', 'pending')
          .order('created_at', ascending: true);

      final requests = (reqRows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      final eventIds =
          requests.map((r) => r['event_id'].toString()).toSet().toList();
      final Map<String, String> titles = {};
      if (eventIds.isNotEmpty) {
        final evRows = await Supabase.instance.client
            .from('events')
            .select('id, title')
            .in_('id', eventIds);
        for (final row in (evRows as List)) {
          titles[row['id'].toString()] = row['title']?.toString() ?? 'Evento';
        }
      }

      _notifications = [];
      for (final r in requests) {
        final id = r['id'].toString();
        if (_dismissedNotificationIds.contains(id)) continue;
        final created =
            DateTime.tryParse(r['created_at']?.toString() ?? '')?.toLocal();
        final timestamp = created == null
            ? ''
            : "${created.day.toString().padLeft(2, '0')}/"
                "${created.month.toString().padLeft(2, '0')} "
                "${created.hour.toString().padLeft(2, '0')}:"
                "${created.minute.toString().padLeft(2, '0')}";
        // Le più recenti in cima
        _notifications.insert(
          0,
          NotificationItem(
            id: id,
            eventId: r['event_id'].toString(),
            eventTitle: titles[r['event_id'].toString()] ?? 'Evento',
            status: r['status'].toString(),
            timestamp: timestamp,
            read: _seenNotificationIds.contains(id),
          ),
        );
      }
      notificationsNotifier.value = List.from(_notifications);

      _notificationBadgeCount = _notifications
          .where((n) => !_seenNotificationIds.contains(n.id))
          .length;
      notificationBadgeNotifier.value = _notificationBadgeCount;
    } catch (e) {
      debugPrint("Errore nel recupero delle notifiche: $e");
    }
  }

  void deleteNotification(String notificationId) {
    _dismissedNotificationIds.add(notificationId);
    _notifications.removeWhere((n) => n.id == notificationId);
    notificationsNotifier.value = List.from(_notifications);
  }

  void resetNotificationBadge() {
    for (final n in _notifications) {
      _seenNotificationIds.add(n.id);
    }
    _notificationBadgeCount = 0;
    notificationBadgeNotifier.value = 0;
  }

  /// Carica un'immagine nel bucket 'event_covers' e restituisce l'URL pubblico.
  Future<String?> uploadEventImage(String fileName, Uint8List fileBytes) async {
    try {
      final storage = Supabase.instance.client.storage.from('event_covers');
      final filePath = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await storage.uploadBinary(filePath, fileBytes);
      return storage.getPublicUrl(filePath);
    } catch (e) {
      debugPrint("Errore upload immagine: $e");
      return null;
    }
  }

  /// Effettua il geocoding di un indirizzo tramite l'API pubblica di Nominatim.
  /// Ritorna Map<String, double> con chiavi 'lat' e 'lng' se trovato, null altrimenti.
  Future<Map<String, double>?> geocodeAddress(String address) async {
    try {
      final query = Uri.encodeComponent(address);
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'EcoraApp/1.0',
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          return {'lat': lat, 'lng': lon};
        }
      }
    } catch (e) {
      debugPrint("Errore durante il geocoding: $e");
    }
    return null;
  }

  /// Crea un evento reale sulla tabella `events` (status: published).
  /// Ritorna null in caso di successo, altrimenti un messaggio di errore.
  Future<String?> createEvent({
    required String title,
    required String description,
    required String hostId,
    required double latitude,
    required double longitude,
    required String? imageUrl,
    required DateTime eventDate,
    required int maxGuests,
    required String locationName,
  }) async {
    try {
      await Supabase.instance.client.from('events').insert({
        'host_id': hostId,
        'title': title,
        'description': description,
        'event_date': eventDate.toUtc().toIso8601String(),
        'max_guests': maxGuests,
        'status': 'published',
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'location_name': locationName,
      });
      await fetchEvents();
      return null;
    } catch (e) {
      debugPrint("Errore creazione evento: $e");
      return "Creazione evento non riuscita. Verifica di avere un profilo gestore e di essere connesso.";
    }
  }

  /// Aggiorna i campi modificabili del proprio profilo sulla tabella
  /// reale e riallinea lo stato locale. Ritorna null se ok.
  Future<String?> updateMyProfile({
    required String nickname,
    required String genericLocation,
    required String? profileType,
    required String? privacyLevel,
  }) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return "Sessione scaduta. Accedi di nuovo.";

      await Supabase.instance.client.from('profiles').update({
        'nickname': nickname,
        'generic_location': genericLocation,
        'profile_type': profileType,
        'privacy_level': privacyLevel,
      }).eq('id', uid);

      final current = currentProfileNotifier.value;
      if (current != null && current.id == uid) {
        final String gender;
        if (profileType == null) {
          gender = current.gender;
        } else if (profileType.contains('Coppia')) {
          gender = 'Coppia';
        } else if (profileType.contains('Donna')) {
          gender = 'Donna';
        } else {
          gender = 'Uomo';
        }
        final updated = current.copyWith(
          fullName: nickname,
          gender: gender,
          profileType: profileType,
          privacyLevel: privacyLevel,
          genericLocation: genericLocation,
        );
        _profiles.removeWhere((p) => p.id == uid);
        _profiles.add(updated);
        profilesNotifier.value = List.from(_profiles);
        currentProfileNotifier.value = updated;
      }
      return null;
    } catch (e) {
      debugPrint("Errore aggiornamento profilo: $e");
      return "Aggiornamento non riuscito. Riprova.";
    }
  }

  SupabaseProfile? getProfileById(String userId) {
    for (final p in _profiles) {
      if (p.id == userId) return p;
    }
    return null;
  }
}
