import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  SupabaseProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.age,
    required this.gender,
    this.noShows = 0,
    this.participationsCount = 0,
  });

  SupabaseProfile copyWith({
    String? id,
    String? fullName,
    String? role,
    int? age,
    String? gender,
    int? noShows,
    int? participationsCount,
  }) {
    return SupabaseProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      noShows: noShows ?? this.noShows,
      participationsCount: participationsCount ?? this.participationsCount,
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
      fullName: "Villa Secret Club",
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
        title: "Golden Velvet Soiree",
        description:
            "An ultra-exclusive champagne reception inside Florence's most beautiful private terrace. Designed for open-minded couples looking for meaningful conversations in absolute secrecy. Smart formal attire required.",
        organizerId: hostUser.id,
        latitude: florenceLat + 0.008,
        longitude: florenceLng + 0.006,
        imageUrl:
            "https://images.unsplash.com/photo-1541252260730-0412e8e2108e?auto=format&fit=crop&q=80&w=600",
        eventDate: "2026-06-25T21:00:00",
        maxParticipants: 10,
        currentApprovedCount: 8,
        locationName: "Private Luxury Villa, Florence Hills",
      ),
      SupabaseEvent(
        id: "event-2",
        title: "Midsummer Amber Eyes",
        description:
            "Discreet masquerade cocktail party. Strictly limited to 6 couples. Perfect visual atmosphere with glowing amber candles, private lounge, and soft ambient sounds.",
        organizerId: hostUser.id,
        latitude: florenceLat - 0.004,
        longitude: florenceLng - 0.003,
        imageUrl:
            "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?auto=format&fit=crop&q=80&w=600",
        eventDate: "2026-06-28T22:30:00",
        maxParticipants: 6,
        currentApprovedCount: 5,
        locationName: "Secluded Velvet Room, Florence South",
      ),
      SupabaseEvent(
        id: "event-3",
        title: "Shadow Tapestry Meet",
        description:
            "Discreet after-party gather for international luxury travelers. Pre-screening mandatory. Perfect security, dark elegant cocktail room, premium gold acoustics.",
        organizerId: hostUser.id,
        latitude: florenceLat + 0.015,
        longitude: florenceLng - 0.012,
        imageUrl:
            "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&q=80&w=600",
        eventDate: "2026-07-02T23:00:00",
        maxParticipants: 12,
        currentApprovedCount: 4,
        locationName: "Secret Palace, Florence Airport Area",
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
      url: 'https://fswzykzclfrpzlujhfg.supabase.co',
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
      home: ValueListenableBuilder<SupabaseProfile?>(
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
    );
  }
}

// --- PREMIUM SECURE LOGIN SCREEN WITH DISCREET ENTRANCE GATEWAY ---

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController =
      TextEditingController(text: "alex.sofia@private.it");
  final TextEditingController _passwordController =
      TextEditingController(text: "••••••••");
  bool _passwordVisible = false;
  String _selectedRole = "cliente"; // "cliente" or "gestore"

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
              const SizedBox(height: 40),
              // --- LOGO DESIGN TOKEN ---
              Center(
                child: Container(
                  width: 90,
                  height: 90,
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
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "E C O R A",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  letterSpacing: 8,
                  fontFamily: 'Serif',
                  color: premiumGold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                "DISCREET ECO-SYSTEM",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                  letterSpacing: 3,
                  fontFamily: 'Sans-Serif',
                  color: textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // --- ACCOUNT ROLE GATE SELECTOR ---
              const Text(
                "CHOOSE SELECTIVE ENTRY PROTOCOL",
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.5,
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
              const SizedBox(height: 24),

              // --- TEXT FIELDS (EMULATING SUPABASE INPUT AUTH) ---
              TextField(
                controller: _emailController,
                style: const TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: "Discreet Identifier / Email",
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
              TextField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                style: const TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: "Security Access Key",
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
              const SizedBox(height: 28),

              // --- SUBMIT AUTH ACCESS TRIGGER ---
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
                  onPressed: () {
                    // Initialize Auth integration
                    SupabaseClient.instance
                        .login(_emailController.text, _selectedRole);
                  },
                  child: const Text(
                    "ACCESS ECO-SYSTEM",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
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
                        "Secured strictly by Supabase encrypted tunnels. Absolute end-to-end anonymity. Your device identity is never recorded.",
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
