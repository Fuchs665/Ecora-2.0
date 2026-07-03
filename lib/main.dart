import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'client_navigation_hub.dart';
import 'gestore_dashboard.dart';
import 'theme.dart';
export 'theme.dart';

// --- SUPABASE DATABASE MODELS ---

class SupabaseProfile {
  final String id;
  final String fullName;
  final String role; // 'cliente' or 'gestore'
  final int age;
  final String gender; // 'Uomo', 'Donna', 'Coppia'
  final int noShows;
  final int participationsCount;
  final String? profileType;
  final String? privacyLevel;
  final String? genericLocation;

  SupabaseProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.age,
    required this.gender,
    this.noShows = 0,
    this.participationsCount = 0,
    this.profileType,
    this.privacyLevel,
    this.genericLocation,
  });

  SupabaseProfile copyWith({
    String? id,
    String? fullName,
    String? role,
    int? age,
    String? gender,
    int? noShows,
    int? participationsCount,
    String? profileType,
    String? privacyLevel,
    String? genericLocation,
  }) {
    return SupabaseProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      noShows: noShows ?? this.noShows,
      participationsCount: participationsCount ?? this.participationsCount,
      profileType: profileType ?? this.profileType,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      genericLocation: genericLocation ?? this.genericLocation,
    );
  }

  /// Maps a row from the real `profiles` table.
  /// age/gender are not stored in the DB yet: gender is derived from
  /// profile_type, age uses a neutral placeholder.
  factory SupabaseProfile.fromRow(Map<String, dynamic> row) {
    final String? profileType = row['profile_type']?.toString();
    final String gender;
    if (profileType == null) {
      gender = 'Coppia';
    } else if (profileType.contains('Coppia')) {
      gender = 'Coppia';
    } else if (profileType.contains('Donna')) {
      gender = 'Donna';
    } else {
      gender = 'Uomo';
    }
    return SupabaseProfile(
      id: row['id']?.toString() ?? '',
      fullName: row['nickname']?.toString() ?? 'Utente Anonimo',
      role: row['role']?.toString() ?? 'cliente',
      age: 30,
      gender: gender,
      profileType: profileType,
      privacyLevel: row['privacy_level']?.toString(),
      genericLocation: row['generic_location']?.toString(),
    );
  }
}

class SupabaseEvent {
  final String id;
  final String title;
  final String description;
  final String organizerId;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String eventDate;
  final int maxParticipants;
  final int currentApprovedCount;
  final String locationName;

  SupabaseEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.organizerId,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.eventDate,
    required this.maxParticipants,
    this.currentApprovedCount = 0,
    this.locationName = "Secret Florence Villa",
  });

  double get tableCompletionPercentage =>
      maxParticipants > 0 ? (currentApprovedCount / maxParticipants) : 0.0;

  /// Maps a row returned by the `get_events_with_stats()` RPC
  /// (real DB keys: host_id, max_guests, approved_count).
  factory SupabaseEvent.fromStats(Map<String, dynamic> json) {
    return SupabaseEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      organizerId: json['host_id']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 43.7695,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 11.2558,
      imageUrl: json['image_url']?.toString() ??
          "https://images.unsplash.com/photo-1541252260730-0412e8e2108e?auto=format&fit=crop&q=80&w=600",
      eventDate:
          json['event_date']?.toString() ?? DateTime.now().toIso8601String(),
      maxParticipants: (json['max_guests'] as num?)?.toInt() ?? 0,
      currentApprovedCount: (json['approved_count'] as num?)?.toInt() ?? 0,
      locationName: json['location_name']?.toString() ?? 'Località riservata',
    );
  }

  SupabaseEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? organizerId,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? eventDate,
    int? maxParticipants,
    int? currentApprovedCount,
    String? locationName,
  }) {
    return SupabaseEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      organizerId: organizerId ?? this.organizerId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      eventDate: eventDate ?? this.eventDate,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentApprovedCount: currentApprovedCount ?? this.currentApprovedCount,
      locationName: locationName ?? this.locationName,
    );
  }
}

class SupabaseParticipationRequest {
  final String id;
  final String userId;
  final String eventId;
  final String status; // 'pending', 'approved', 'rejected'

  SupabaseParticipationRequest({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.status,
  });

  SupabaseParticipationRequest copyWith({
    String? id,
    String? userId,
    String? eventId,
    String? status,
  }) {
    return SupabaseParticipationRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      status: status ?? this.status,
    );
  }

  /// Maps a row from the real `event_requests` table.
  factory SupabaseParticipationRequest.fromRow(Map<String, dynamic> row) {
    return SupabaseParticipationRequest(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      eventId: row['event_id']?.toString() ?? '',
      status: row['status']?.toString() ?? 'pending',
    );
  }
}

class NotificationItem {
  final String id;
  final String eventId;
  final String eventTitle;
  final String status; // 'approved', 'rejected'
  final String timestamp;
  final bool read;

  NotificationItem({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.status,
    required this.timestamp,
    this.read = false,
  });
}

// --- REACTIVE EXPERT SUPABASE SIMULATOR (Singleton Object) ---

class SupabaseClient {
  static final SupabaseClient instance = SupabaseClient._internal();
  SupabaseClient._internal();

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

// --- FLUTTER APPLICATION BARRIER ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: 'https://fswzykzclfrpzlufjhfg.supabase.co',
      anonKey: 'sb_publishable_qv2R89l53F8gK_cJ6rS66Q_7TLWe_-B',
    );
    await SupabaseClient.instance.restoreSession();
  } catch (e) {
    debugPrint(
        "Supabase initialization caught exception (e.g. offline/mock environment): $e");
  }
  runApp(const EcoraApp());
}

class EcoraApp extends StatefulWidget {
  const EcoraApp({Key? key}) : super(key: key);

  @override
  State<EcoraApp> createState() => _EcoraAppState();
}

class _EcoraAppState extends State<EcoraApp> {
  @override
  void initState() {
    super.initState();
    // Listening to profile logout changes
    SupabaseClient.instance.currentProfileNotifier
        .addListener(_profileListener);
  }

  @override
  void dispose() {
    SupabaseClient.instance.currentProfileNotifier
        .removeListener(_profileListener);
    super.dispose();
  }

  void _profileListener() {
    // Return to login screen automatically if logged out
    if (SupabaseClient.instance.currentProfileNotifier.value == null) {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Serif',
        scaffoldBackgroundColor: matteDark,
        colorScheme: const ColorScheme.dark(
          primary: premiumGold,
          onPrimary: matteDark,
          secondary: premiumGold,
          surface: slateSurface,
        ),
      ),
      home: BiometricGate(
        child: ValueListenableBuilder<SupabaseProfile?>(
          valueListenable: SupabaseClient.instance.currentProfileNotifier,
          builder: (context, profile, _) {
            if (profile == null) {
              return const AuthScreen();
            } else if (profile.role == 'gestore') {
              return const GestoreDashboard();
            } else {
              // Default sicuro: qualunque ruolo non-gestore -> area cliente.
              return const ClientNavigationHub();
            }
          },
        ),
      ),
    );
  }
}

// --- BIOMETRIC SECURITY GATEWAY ---
class BiometricGate extends StatefulWidget {
  final Widget child;
  const BiometricGate({Key? key, required this.child}) : super(key: key);

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  final LocalAuthentication _auth = LocalAuthentication();
  String _authState = 'checking'; // 'checking', 'authenticated', 'failed'

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool hasBiometrics = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!hasBiometrics) {
        setState(() {
          _authState = 'authenticated'; // Bypass automatically if biometrics not supported
        });
        return;
      }

      final List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        setState(() {
          _authState = 'authenticated'; // Bypass if no biometric templates are enrolled
        });
        return;
      }

      _authenticate();
    } catch (e) {
      debugPrint("Errore verifica biometria: $e");
      setState(() {
        _authState = 'authenticated'; // Safe fallback bypass on exception
      });
    }
  }

  Future<void> _authenticate() async {
    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: 'Autenticati per accedere al tuo profilo riservato',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        setState(() {
          _authState = 'authenticated';
        });
      } else {
        setState(() {
          _authState = 'failed';
        });
      }
    } catch (e) {
      debugPrint("Errore autenticazione biometrica: $e");
      setState(() {
        _authState = 'failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authState == 'checking') {
      return const Scaffold(
        backgroundColor: matteDark,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(premiumGold),
          ),
        ),
      );
    }

    if (_authState == 'failed') {
      return Scaffold(
        backgroundColor: matteDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                const Icon(
                  Icons.fingerprint,
                  color: premiumGold,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  "ACCESSO BLOCCATO",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 4,
                    fontFamily: 'Serif',
                    color: premiumGold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "È necessaria l'autenticazione biometrica per sbloccare l'applicazione e proteggere i tuoi dati sensibili.",
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ecoraPrimaryButtonStyle(),
                    onPressed: _authenticate,
                    child: const Text(
                      "RIPROVA LO SBLOCCO",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}

// --- PREMIUM SECURE LOGIN SCREEN WITH DISCREET ENTRANCE GATEWAY ---

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  // Login Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;

  // Registration Controllers
  final TextEditingController _regNicknameController = TextEditingController();
  final TextEditingController _regLocationController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();
  bool _regPasswordVisible = false;

  final List<String> _profileTypes = [
    "Coppia U/D",
    "Coppia D/D",
    "Coppia U/U",
    "Donna Singola",
    "Uomo Singolo",
  ];
  String? _selectedProfileType;

  final Map<String, String> _privacyOptions = {
    "Visibile": "visible",
    "In incognito": "ghost",
  };
  String? _selectedPrivacyLevel;

  String _parseSupabaseError(dynamic error) {
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('invalid login credentials') ||
        errStr.contains('invalid_credentials')) {
      return "Credenziali non valide.";
    } else if (errStr.contains('email not confirmed')) {
      return "Email non ancora confermata. Controlla la tua casella di posta.";
    } else if (errStr.contains('already registered') ||
        errStr.contains('already in use') ||
        errStr.contains('user_already_exists')) {
      return "Email già in uso. Prova a fare il login.";
    } else if (errStr.contains('weak password') ||
        errStr.contains('password should be')) {
      return "La password è troppo debole. Usa almeno 6 caratteri.";
    } else if (errStr.contains('invalid email') || errStr.contains('format')) {
      return "Formato dell'email non valido.";
    } else if (errStr.contains('network') ||
        errStr.contains('failed to connect')) {
      return "Errore di connessione a Supabase.";
    }
    return "Errore di autenticazione: ${error.toString()}";
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Per favore, compila tutti i campi.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = "Credenziali non valide.";
        });
        return;
      }

      Map<String, dynamic>? profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // Ripara gli account creati prima della policy di INSERT sui profili:
      // se manca la riga profilo, la creiamo ora con valori minimi.
      // Upsert con ignoreDuplicates evita il conflitto se la riga esiste
      // ma non era leggibile per un problema transitorio.
      if (profileData == null) {
        final fallbackNickname = email.split('@').first;
        await Supabase.instance.client.from('profiles').upsert(
          {
            'id': user.id,
            'nickname': fallbackNickname,
            'role': 'cliente',
          },
          onConflict: 'id',
          ignoreDuplicates: true,
        );
        profileData = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        profileData ??= {
          'id': user.id,
          'nickname': fallbackNickname,
          'role': 'cliente',
        };
      }

      final prof =
          SupabaseProfile.fromRow(Map<String, dynamic>.from(profileData));
      SupabaseClient.instance.addProfile(prof);
      SupabaseClient.instance.currentProfileNotifier.value = prof;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _parseSupabaseError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text.trim();
    final nickname = _regNicknameController.text.trim();
    final location = _regLocationController.text.trim();
    final profileType = _selectedProfileType;
    final privacyLevel = _selectedPrivacyLevel;

    if (email.isEmpty || password.isEmpty || nickname.isEmpty || location.isEmpty) {
      setState(() {
        _errorMessage = "Per favore, compila tutti i campi.";
      });
      return;
    }

    if (nickname.length < 3) {
      setState(() {
        _errorMessage = "Il nickname deve contenere almeno 3 caratteri.";
      });
      return;
    }

    if (location.length < 2) {
      setState(() {
        _errorMessage = "La località deve contenere almeno 2 caratteri.";
      });
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _errorMessage = "Inserisci un indirizzo email valido.";
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = "La password deve contenere almeno 6 caratteri.";
      });
      return;
    }

    if (profileType == null || profileType.isEmpty) {
      setState(() {
        _errorMessage = "Per favore, seleziona la tipologia di profilo dal menu.";
      });
      return;
    }

    if (privacyLevel == null || privacyLevel.isEmpty) {
      setState(() {
        _errorMessage = "Per favore, seleziona il livello di privacy dal menu.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      // 1. Registrazione reale su Supabase Auth
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception("Impossibile creare l'utente.");
      }

      // Con la conferma email attiva non esiste ancora una sessione:
      // la riga profilo verrà creata al primo login (percorso di riparazione).
      if (response.session == null) {
        if (!mounted) return;
        setState(() {
          _isLogin = true;
          _errorMessage = null;
          _infoMessage =
              "Registrazione riuscita! Controlla la tua email per confermare l'account, poi accedi.";
        });
        return;
      }

      final String userId = user.id;

      // 2. Inserimento riga reale nella tabella public.profiles
      try {
        await Supabase.instance.client.from('profiles').insert({
          'id': userId,
          'nickname': nickname,
          'role': 'cliente',
          'generic_location': location,
          'is_verified': false,
          'profile_type': profileType,
          'privacy_level': privacyLevel,
        });
      } catch (dbErr) {
        debugPrint("Errore nell'inserimento del profilo reale: $dbErr");
      }

      // 3. Registrazione nello stato locale (in-memory simulator)
      final newLocalProfile = SupabaseProfile(
        id: userId,
        fullName: nickname,
        role: 'cliente',
        age: 30,
        gender: profileType.contains('Coppia') ? 'Coppia' : (profileType.contains('Donna') ? 'Donna' : 'Uomo'),
        noShows: 0,
        participationsCount: 0,
        profileType: profileType,
        privacyLevel: privacyLevel,
      );

      SupabaseClient.instance.addProfile(newLocalProfile);
      SupabaseClient.instance.currentProfileNotifier.value = newLocalProfile;

    } catch (e) {
      debugPrint("Errore completo durante la registrazione: $e");
      setState(() {
        _errorMessage = _parseSupabaseError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // --- LOGO DESIGN TOKEN ---
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        premiumGold.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.diamond,
                    color: premiumGold,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "E C O R A",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: 8,
                  fontFamily: 'Serif',
                  color: premiumGold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // --- TITLE INDICATOR ---
              Text(
                _isLogin ? "ACCESSO RISERVATO" : "REGISTRAZIONE NUOVO MEMBRO",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 2,
                  color: premiumGold,
                ),
              ),
              const SizedBox(height: 20),

              // --- FORM WRAPPER ---
              if (_isLogin) ...[
                // --- LOGIN EMAIL ---
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: ecoraInputDecoration(
                    "Email",
                    prefixIcon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 16),

                // --- LOGIN PASSWORD ---
                TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: ecoraInputDecoration(
                    "Password",
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: premiumGold,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- LOGIN BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ecoraPrimaryButtonStyle(),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(matteDark),
                            ),
                          )
                        : const Text(
                            "LOGIN",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: ecoraSecondaryButtonStyle(),
                    onPressed: () {
                      setState(() {
                        _isLogin = false;
                        _errorMessage = null;
                        _infoMessage = null;
                      });
                    },
                    child: const Text(
                      "REGISTRATI / CREA ACCOUNT",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // --- REGISTRATION FORM FIELDS ---
                // 1. Nickname
                TextField(
                  controller: _regNicknameController,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: ecoraInputDecoration(
                    "Nickname (es. Alex & Sofia)",
                    prefixIcon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 16),

                // Tipologia di Profilo Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedProfileType,
                  hint: const Text(
                    "Seleziona la tipologia...",
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  dropdownColor: slateSurface,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  icon: const Icon(Icons.arrow_drop_down, color: premiumGold),
                  decoration: ecoraInputDecoration(
                    "Tipologia di Profilo",
                    prefixIcon: Icons.people_outline,
                  ),
                  items: _profileTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(
                        type,
                        style: const TextStyle(color: textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedProfileType = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Livello di Privacy Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedPrivacyLevel,
                  hint: const Text(
                    "Seleziona livello di privacy...",
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  dropdownColor: slateSurface,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  icon: const Icon(Icons.arrow_drop_down, color: premiumGold),
                  decoration: ecoraInputDecoration(
                    "Livello di Privacy",
                    prefixIcon: Icons.security_outlined,
                  ),
                  items: _privacyOptions.keys.map((String label) {
                    return DropdownMenuItem<String>(
                      value: _privacyOptions[label],
                      child: Text(
                        label,
                        style: const TextStyle(color: textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedPrivacyLevel = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 2. Località Generica
                TextField(
                  controller: _regLocationController,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: ecoraInputDecoration(
                    "Località Generica (es. Firenze Nord)",
                    prefixIcon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Email
                TextField(
                  controller: _regEmailController,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: ecoraInputDecoration(
                    "Email",
                    prefixIcon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Password
                TextField(
                  controller: _regPasswordController,
                  obscureText: !_regPasswordVisible,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: ecoraInputDecoration(
                    "Password (almeno 6 caratteri)",
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _regPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: premiumGold,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _regPasswordVisible = !_regPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- REGISTER BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ecoraPrimaryButtonStyle(),
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(matteDark),
                            ),
                          )
                        : const Text(
                            "REGISTRATI ORA",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: ecoraSecondaryButtonStyle(),
                    onPressed: () {
                      setState(() {
                        _isLogin = true;
                        _errorMessage = null;
                        _infoMessage = null;
                      });
                    },
                    child: const Text(
                      "TORNA AL LOGIN",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],

              // --- TOGGLE BTN UNDER ACTION ---
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? "Non hai un account? " : "Hai già un account? ",
                    style: const TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = null;
                        _infoMessage = null;
                      });
                    },
                    child: Text(
                      _isLogin ? "Registrati" : "Accedi",
                      style: const TextStyle(
                        color: premiumGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),

              // --- PANNELLO ERRORE / SUCCESSO ---
              if (_errorMessage != null)
                _AuthMessagePanel(
                  message: _errorMessage!,
                  icon: Icons.error_outline,
                  color: Colors.redAccent,
                  backgroundColor: Colors.red,
                )
              else if (_infoMessage != null)
                _AuthMessagePanel(
                  message: _infoMessage!,
                  icon: Icons.check_circle_outline,
                  color: premiumGold,
                  backgroundColor: premiumGold,
                ),

              const SizedBox(height: 36),

              // Privacy note footer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock, color: premiumGold, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isLogin
                            ? "Protetto rigorosamente da tunnel crittografati Supabase. Anonimato assoluto end-to-end. L'identità del tuo dispositivo non viene mai registrata."
                            : "Compilando il modulo acconsenti al pre-screening rigoroso. Il tuo nickname e la tua località non saranno rivelati finché non sarai approvato a un tavolo condiviso.",
                        style: TextStyle(
                          color: textSecondary.withValues(alpha: 0.8),
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pannello di feedback per AuthScreen: stessa struttura per errore
/// (rosso) e successo (oro), solo colore/icona cambiano.
class _AuthMessagePanel extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _AuthMessagePanel({
    required this.message,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: backgroundColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
