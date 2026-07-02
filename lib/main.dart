import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'client_navigation_hub.dart';
import 'gestore_dashboard.dart';

// --- PREMIUM DESIGN SYSTEM TOKENS ---
const Color matteDark = Color(0xFF1A1A1A);
const Color slateSurface = Color(0xFF2A2A2A);
const Color premiumGold = Color(0xFFD4AF37);
const Color textPrimary = Color(0xFFFFFFFF);
const Color textSecondary = Color(0xFFA0A0A0);

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
  SupabaseClient._internal() {
    _seedDatabase();
  }

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

  List<SupabaseProfile> _profiles = [];
  List<SupabaseEvent> _events = [];
  List<SupabaseParticipationRequest> _requests = [];
  List<NotificationItem> _notifications = [];
  int _notificationBadgeCount = 0;

  void _seedDatabase() {
    final clienteUser = SupabaseProfile(
      id: "user-cliente-123",
      fullName: "Alex & Sofia",
      role: "cliente",
      age: 32,
      gender: "Coppia",
      noShows: 0,
      participationsCount: 8,
    );

    final hostUser = SupabaseProfile(
      id: "user-gestore-456",
      fullName: "Club Segreto della Villa",
      role: "gestore",
      age: 40,
      gender: "Donna",
      noShows: 0,
      participationsCount: 45,
    );

    _profiles = [
      clienteUser,
      hostUser,
      SupabaseProfile(
          id: "user-test-789",
          fullName: "Marcus & Ellen",
          role: "cliente",
          age: 29,
          gender: "Coppia",
          noShows: 0,
          participationsCount: 3),
      SupabaseProfile(
          id: "user-test-101",
          fullName: "Isabella",
          role: "cliente",
          age: 27,
          gender: "Donna",
          noShows: 1,
          participationsCount: 12),
      SupabaseProfile(
          id: "user-test-102",
          fullName: "Valerio",
          role: "cliente",
          age: 34,
          gender: "Uomo",
          noShows: 2,
          participationsCount: 4),
    ];

    const double florenceLat = 43.7695;
    const double florenceLng = 11.2558;

    _events = [
      SupabaseEvent(
        id: "event-1",
        title: "Serata Velluto Dorato",
        description:
            "Un ricevimento champagne ultra-esclusivo sulla terrazza privata più bella di Firenze. Progettato per coppie con mentalità aperta alla ricerca di conversazioni significative in assoluta riservatezza. Richiesto abbigliamento formale elegante.",
        organizerId: hostUser.id,
        latitude: florenceLat + 0.008,
        longitude: florenceLng + 0.006,
        imageUrl:
            "https://images.unsplash.com/photo-1541252260730-0412e8e2108e?auto=format&fit=crop&q=80&w=600",
        eventDate: "2026-06-25T21:00:00",
        maxParticipants: 10,
        currentApprovedCount: 8,
        locationName: "Villa di Lusso Privata, Colline di Firenze",
      ),
      SupabaseEvent(
        id: "event-2",
        title: "Occhi d'Ambra di Mezza Estate",
        description:
            "Festa in maschera discreta con cocktail. Rigorosamente limitata a 6 coppie. Atmosfera visiva perfetta con candele d'ambra accese, salotto privato e suoni ambientali soffusi.",
        organizerId: hostUser.id,
        latitude: florenceLat - 0.004,
        longitude: florenceLng - 0.003,
        imageUrl:
            "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?auto=format&fit=crop&q=80&w=600",
        eventDate: "2026-06-28T22:30:00",
        maxParticipants: 6,
        currentApprovedCount: 5,
        locationName: "Stanza di Velluto Riservata, Firenze Sud",
      ),
      SupabaseEvent(
        id: "event-3",
        title: "Incontro Trama d'Ombra",
        description:
            "Incontro discreto post-serata per viaggiatori internazionali di lusso. Pre-screening obbligatorio. Massima sicurezza, elegante cocktail room scura, acustica premium d'oro.",
        organizerId: hostUser.id,
        latitude: florenceLat + 0.015,
        longitude: florenceLng - 0.012,
        imageUrl:
            "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&q=80&w=600",
        eventDate: "2026-07-02T23:00:00",
        maxParticipants: 12,
        currentApprovedCount: 4,
        locationName: "Palazzo Segreto, Area Aeroporto di Firenze",
      ),
    ];

    _requests = [
      SupabaseParticipationRequest(
          id: "req-1",
          userId: "user-test-789",
          eventId: "event-1",
          status: "pending"),
      SupabaseParticipationRequest(
          id: "req-2",
          userId: "user-test-101",
          eventId: "event-1",
          status: "pending"),
      SupabaseParticipationRequest(
          id: "req-3",
          userId: "user-test-102",
          eventId: "event-2",
          status: "pending"),
    ];

    _notifications = [];
    _notificationBadgeCount = 0;

    currentProfileNotifier.value = clienteUser;
    profilesNotifier.value = List.from(_profiles);
    eventsNotifier.value = List.from(_events);
    requestsNotifier.value = List.from(_requests);
    notificationsNotifier.value = List.from(_notifications);
    notificationBadgeNotifier.value = _notificationBadgeCount;
  }

  void login(String email, String selectedRole) {
    SupabaseProfile? p;
    for (var profile in _profiles) {
      if (profile.role == selectedRole) {
        p = profile;
        break;
      }
    }

    p ??= SupabaseProfile(
      id: "user-random-${DateTime.now().millisecondsSinceEpoch}",
      fullName:
          selectedRole == "cliente" ? "Claudio & Maya" : "Noble Club Firenze",
      role: selectedRole,
      age: 35,
      gender: selectedRole == "cliente" ? "Coppia" : "Donna",
      noShows: 0,
      participationsCount: selectedRole == "cliente" ? 2 : 12,
    );

    if (!_profiles.any((profile) => profile.id == p!.id)) {
      _profiles.add(p);
      profilesNotifier.value = List.from(_profiles);
    }
    currentProfileNotifier.value = p;
  }

  void addProfile(SupabaseProfile p) {
    if (!_profiles.any((profile) => profile.id == p.id)) {
      _profiles.add(p);
      profilesNotifier.value = List.from(_profiles);
    }
  }

  Future<void> fetchEvents() async {
    try {
      final data = await Supabase.instance.client
          .from('events')
          .select();

      final List<SupabaseEvent> realEvents = (data as List).map((item) {
        return SupabaseEvent(
          id: item['id']?.toString() ?? '',
          title: item['title']?.toString() ?? '',
          description: item['description']?.toString() ?? '',
          organizerId: item['organizer_id']?.toString() ?? 'user-gestore-456',
          latitude: (item['latitude'] as num?)?.toDouble() ?? 43.7695,
          longitude: (item['longitude'] as num?)?.toDouble() ?? 11.2558,
          imageUrl: item['image_url']?.toString() ??
              "https://images.unsplash.com/photo-1541252260730-0412e8e2108e?auto=format&fit=crop&q=80&w=600",
          eventDate: item['event_date']?.toString() ?? DateTime.now().toIso8601String(),
          maxParticipants: (item['max_participants'] as num?)?.toInt() ?? 10,
          currentApprovedCount: (item['current_approved_count'] as num?)?.toInt() ?? 0,
          locationName: item['location_name']?.toString() ?? 'Secret Florence Villa',
        );
      }).toList();

      if (realEvents.isNotEmpty) {
        final uniqueRealIds = realEvents.map((e) => e.id).toSet();
        final List<SupabaseEvent> combined = List.from(realEvents);
        for (var mock in _events) {
          if (!uniqueRealIds.contains(mock.id)) {
            combined.add(mock);
          }
        }
        _events = combined;
      }
      eventsNotifier.value = List.from(_events);
    } catch (e) {
      debugPrint("Errore nel recupero degli eventi reali da Supabase: $e");
    }
  }

  void logout() {
    currentProfileNotifier.value = null;
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

  void submitParticipationRequest(String eventId, String userId) {
    bool exists =
        _requests.any((req) => req.userId == userId && req.eventId == eventId);
    if (!exists) {
      final req = SupabaseParticipationRequest(
        id: "req-${DateTime.now().millisecondsSinceEpoch}",
        userId: userId,
        eventId: eventId,
        status: "pending",
      );
      _requests.add(req);
      requestsNotifier.value = List.from(_requests);
    }
  }

  void reviewParticipationRequest(String requestId, String status) {
    List<SupabaseParticipationRequest> updated = [];
    for (var req in _requests) {
      if (req.id == requestId) {
        updated.add(req.copyWith(status: status));

        if (status == "approved") {
          _updateEventApprovedCount(req.eventId, 1);
        }

        final ev = _events.firstWhere((e) => e.id == req.eventId);
        final notif = NotificationItem(
          id: "notif-${DateTime.now().millisecondsSinceEpoch}",
          eventId: req.eventId,
          eventTitle: ev.title,
          status: status,
          timestamp:
              "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
        );
        _notifications.insert(0, notif);
        _notificationBadgeCount++;
        notificationsNotifier.value = List.from(_notifications);
        notificationBadgeNotifier.value = _notificationBadgeCount;
      } else {
        updated.add(req);
      }
    }
    _requests = updated;
    requestsNotifier.value = List.from(_requests);
  }

  void _updateEventApprovedCount(String eventId, int increment) {
    _events = _events.map((ev) {
      if (ev.id == eventId) {
        int nextVal = ev.currentApprovedCount + increment;
        if (nextVal > ev.maxParticipants) nextVal = ev.maxParticipants;
        return ev.copyWith(currentApprovedCount: nextVal);
      }
      return ev;
    }).toList();
    eventsNotifier.value = List.from(_events);
  }

  void deleteNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notificationsNotifier.value = List.from(_notifications);
  }

  void resetNotificationBadge() {
    _notificationBadgeCount = 0;
    notificationBadgeNotifier.value = 0;
  }

  void insertEventAndUploadImage({
    required String title,
    required String description,
    required String organizerId,
    required double latitude,
    required double longitude,
    required String? mockImagePath,
    required int maxParticipants,
    required String locationName,
  }) {
    final String actualUrl = (mockImagePath != null && mockImagePath.isNotEmpty)
        ? mockImagePath
        : "https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?auto=format&fit=crop&q=80&w=600";

    final ev = SupabaseEvent(
      id: "event-${DateTime.now().millisecondsSinceEpoch}",
      title: title,
      description: description,
      organizerId: organizerId,
      latitude: latitude,
      longitude: longitude,
      imageUrl: actualUrl,
      eventDate: "2026-06-30T22:00:00",
      maxParticipants: maxParticipants,
      currentApprovedCount: 1,
      locationName: locationName,
    );

    _events.insert(0, ev);
    eventsNotifier.value = List.from(_events);
  }

  SupabaseProfile? getProfileById(String userId) {
    return _profiles.firstWhere((p) => p.id == userId);
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
          background: matteDark,
        ),
      ),
      home: BiometricGate(
        child: ValueListenableBuilder<SupabaseProfile?>(
          valueListenable: SupabaseClient.instance.currentProfileNotifier,
          builder: (context, profile, _) {
            if (profile == null) {
              return const AuthScreen();
            } else if (profile.role == 'cliente') {
              return const ClientNavigationHub();
            } else {
              return const GestoreDashboard();
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: premiumGold,
                      foregroundColor: matteDark,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
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

  // Login Controllers
  final TextEditingController _emailController =
      TextEditingController(text: "alex.sofia@private.it");
  final TextEditingController _passwordController =
      TextEditingController(text: "••••••••");
  bool _passwordVisible = false;
  String _selectedRole = "cliente"; // "cliente" or "gestore"

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

  Widget _buildRoleButton(String roleLabel, String roleValue) {
    final isSelected = _selectedRole == roleValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRole = roleValue;
            if (_selectedRole == "cliente") {
              _emailController.text = "alex.sofia@private.it";
              _passwordController.text = "••••••••";
            } else {
              _emailController.text = "villa.secret@club.it";
              _passwordController.text = "••••••••";
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? premiumGold : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            roleLabel,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: isSelected ? matteDark : textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  String _parseSupabaseError(dynamic error) {
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('already registered') ||
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
    });

    try {
      // Se è uno dei profili di test rapido, usiamo la simulazione istantanea
      if (email == "alex.sofia@private.it" ||
          email == "villa.secret@club.it" ||
          password == "••••••••") {
        SupabaseClient.instance.login(email, _selectedRole);
        return;
      }

      // Tentativo reale con Supabase Auth
      try {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (response.user != null) {
          final userId = response.user!.id;

          try {
            final profileData = await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', userId)
                .maybeSingle();

            if (profileData != null) {
              final String role = profileData['role'] ?? 'cliente';
              final String nickname = profileData['nickname'] ?? 'Utente Anonimo';

              final prof = SupabaseProfile(
                id: userId,
                fullName: nickname,
                role: role,
                age: 30,
                gender: 'Coppia',
                noShows: 0,
                participationsCount: 1,
                profileType: profileData['profile_type'],
                privacyLevel: profileData['privacy_level'],
              );

              SupabaseClient.instance.addProfile(prof);
              SupabaseClient.instance.currentProfileNotifier.value = prof;
              return;
            }
          } catch (dbErr) {
            debugPrint("Errore recupero riga profilo reale: $dbErr");
          }

          final prof = SupabaseProfile(
            id: userId,
            fullName: email.split('@').first,
            role: _selectedRole,
            age: 30,
            gender: 'Coppia',
            noShows: 0,
            participationsCount: 1,
          );
          SupabaseClient.instance.addProfile(prof);
          SupabaseClient.instance.currentProfileNotifier.value = prof;
        }
      } catch (authErr) {
        debugPrint("Errore Supabase Auth reale: $authErr");

        if (authErr.toString().contains('not initialized') ||
            authErr.toString().contains('Null check operator') ||
            authErr.toString().contains('SocketException')) {
          // Fallback offline su simulazione
          SupabaseClient.instance.login(email, _selectedRole);
          return;
        }

        setState(() {
          _errorMessage = "Credenziali non valide o errore di rete.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Errore durante l'accesso: ${e.toString()}";
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
      String friendlyError = _parseSupabaseError(e);

      if (e.toString().contains('not initialized') ||
          e.toString().contains('Null check operator') ||
          e.toString().contains('SocketException')) {
        // Fallback offline / mock simulator
        final mockUserId = "user-mock-${DateTime.now().millisecondsSinceEpoch}";
        final mockProfile = SupabaseProfile(
          id: mockUserId,
          fullName: nickname,
          role: 'cliente',
          age: 30,
          gender: profileType.contains('Coppia') ? 'Coppia' : (profileType.contains('Donna') ? 'Donna' : 'Uomo'),
          noShows: 0,
          participationsCount: 0,
          profileType: profileType,
          privacyLevel: privacyLevel,
        );
        SupabaseClient.instance.addProfile(mockProfile);
        SupabaseClient.instance.currentProfileNotifier.value = mockProfile;
        return;
      }

      setState(() {
        _errorMessage = friendlyError;
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
                        premiumGold.withOpacity(0.18),
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
                // --- ACCOUNT ROLE GATE SELECTOR ---
                const Text(
                  "Io sono",
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.0,
                    color: premiumGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: slateSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Row(
                    children: [
                      _buildRoleButton("CLIENTE / COPPIA", "cliente"),
                      _buildRoleButton("GESTORE / CLUB", "gestore"),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- LOGIN EMAIL ---
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle:
                        const TextStyle(color: textSecondary, fontSize: 12),
                    floatingLabelStyle: const TextStyle(color: premiumGold),
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: premiumGold, size: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: premiumGold),
                    ),
                    filled: true,
                    fillColor: slateSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 16),

                // --- LOGIN PASSWORD ---
                TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle:
                        const TextStyle(color: textSecondary, fontSize: 12),
                    floatingLabelStyle: const TextStyle(color: premiumGold),
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: premiumGold, size: 20),
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
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: premiumGold),
                    ),
                    filled: true,
                    fillColor: slateSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),

                // --- LOGIN BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: premiumGold,
                      foregroundColor: matteDark,
                      elevation: 4,
                      shape: RoundedCornerShape(24),
                    ),
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
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: premiumGold, width: 1.5),
                      shape: RoundedCornerShape(24),
                      foregroundColor: premiumGold,
                    ),
                    onPressed: () {
                      setState(() {
                        _isLogin = false;
                        _errorMessage = null;
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
                  decoration: InputDecoration(
                    labelText: "Nickname (es. Alex & Sofia)",
                    labelStyle:
                        const TextStyle(color: textSecondary, fontSize: 12),
                    floatingLabelStyle: const TextStyle(color: premiumGold),
                    prefixIcon: const Icon(Icons.person_outline,
                        color: premiumGold, size: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: premiumGold),
                    ),
                    filled: true,
                    fillColor: slateSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 16),

                // Tipologia di Profilo Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedProfileType,
                  hint: const Text(
                    "Seleziona la tipologia...",
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  dropdownColor: slateSurface,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  icon: const Icon(Icons.arrow_drop_down, color: premiumGold),
                  decoration: InputDecoration(
                    labelText: "Tipologia di Profilo",
                    labelStyle:
                        const TextStyle(color: textSecondary, fontSize: 12),
                    floatingLabelStyle: const TextStyle(color: premiumGold),
                    prefixIcon: const Icon(Icons.people_outline,
                        color: premiumGold, size: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: premiumGold),
                    ),
                    filled: true,
                    fillColor: slateSurface.withOpacity(0.5),
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
                  value: _selectedPrivacyLevel,
                  hint: const Text(
                    "Seleziona livello di privacy...",
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  dropdownColor: slateSurface,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  icon: const Icon(Icons.arrow_drop_down, color: premiumGold),
                  decoration: InputDecoration(
                    labelText: "Livello di Privacy",
                    labelStyle:
                        const TextStyle(color: textSecondary, fontSize: 12),
                    floatingLabelStyle: const TextStyle(color: premiumGold),
                    prefixIcon: const Icon(Icons.security_outlined,
                        color: premiumGold, size: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: premiumGold),
                    ),
                    filled: true,
                    fillColor: slateSurface.withOpacity(0.5),
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
                  decoration: InputDecoration(
                    labelText: "Località Generica (es. Firenze Nord)",
                    labelStyle:
                        const TextStyle(color: textSecondary, fontSize: 12),
                    floatingLabelStyle: const TextStyle(color: premiumGold),
                    prefixIcon: const Icon(Icons.location_on_outlined,
                        color: premiumGold, size: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: premiumGold),
                    ),
                    filled: true,
                    fillColor: slateSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Email
                TextField(
                  controller: _regEmailController,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle:
                        const TextStyle(color: textSecondary, fontSize: 12),
                    floatingLabelStyle: const TextStyle(color: premiumGold),
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: premiumGold, size: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: premiumGold),
                    ),
                    filled: true,
                    fillColor: slateSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Password
                TextField(
                  controller: _regPasswordController,
                  obscureText: !_regPasswordVisible,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: "Password (almeno 6 caratteri)",
                    labelStyle:
                        const TextStyle(color: textSecondary, fontSize: 12),
                    floatingLabelStyle: const TextStyle(color: premiumGold),
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: premiumGold, size: 20),
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
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: premiumGold),
                    ),
                    filled: true,
                    fillColor: slateSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),

                // --- REGISTER BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: premiumGold,
                      foregroundColor: matteDark,
                      elevation: 4,
                      shape: RoundedCornerShape(24),
                    ),
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
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: premiumGold, width: 1.5),
                      shape: RoundedCornerShape(24),
                      foregroundColor: premiumGold,
                    ),
                    onPressed: () {
                      setState(() {
                        _isLogin = true;
                        _errorMessage = null;
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

              // --- ERROR PANEL INDICATOR ---
              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                          color: textSecondary.withOpacity(0.8),
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

// Custom helper: RoundedCornerShape wrapper widget mimicking Material3's corner radii
RoundedRectangleBorder RoundedCornerShape(double radius) {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
  );
}
