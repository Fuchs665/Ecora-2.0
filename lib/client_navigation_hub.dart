import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart';
import 'event_details_page.dart';
import 'user_profile_page.dart';

class ClientNavigationHub extends StatefulWidget {
  const ClientNavigationHub({Key? key}) : super(key: key);

  @override
  State<ClientNavigationHub> createState() => _ClientNavigationHubState();
}

class _ClientNavigationHubState extends State<ClientNavigationHub> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Read current logged-in profile
    final currentProfile = SupabaseClient.instance.currentProfileNotifier.value;

    final List<Widget> pages = [
      const ExploreScreen(),
      ValueListenableBuilder<List<NotificationItem>>(
        valueListenable: SupabaseClient.instance.notificationsNotifier,
        builder: (context, notifications, _) {
          return NotificationsScreen(
            notifications: notifications,
            onDeleteNotification: (id) {
              SupabaseClient.instance.deleteNotification(id);
            },
          );
        },
      ),
      const MessagesScreen(),
      if (currentProfile != null)
        UserProfilePage(
          profile: currentProfile,
          onLogout: () {
            SupabaseClient.instance.logout();
          },
        )
      else
        const Center(
            child: Text("Nessun profilo caricato",
                style: TextStyle(color: textPrimary))),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        height: 76,
        decoration: BoxDecoration(
          color: slateSurface,
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            // Aggiorna dal DB e azzera il badge quando si apre la campanella
            if (index == 1) {
              SupabaseClient.instance
                  .fetchMyNotifications()
                  .then((_) => SupabaseClient.instance.resetNotificationBadge());
            }
          },
          backgroundColor: slateSurface,
          selectedItemColor: premiumGold,
          unselectedItemColor: textSecondary,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28),
              activeIcon: Icon(Icons.home, color: premiumGold, size: 28),
              label: "Esplora",
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.mail, size: 28),
                  ValueListenableBuilder<int>(
                    valueListenable:
                        SupabaseClient.instance.notificationBadgeNotifier,
                    builder: (context, badgeCount, _) {
                      if (badgeCount == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: premiumGold,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(
                              color: matteDark,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              label: "Notifiche",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble, size: 26),
              label: "Forum",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person, size: 28),
              label: "Profilo",
            ),
          ],
        ),
      ),
    );
  }
}

// --- EXPLORE SCREEN WITH EXQUISITE DETAIL AND ADVANCED MAP MAPPER ---

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _isMapView = false;
  bool _isRadiusActive = false;
  double _radiusKm = 25.0;
  SupabaseEvent? _selectedPointEvent;

  // Florence coordinates defaults
  final double centerLat = 43.7695;
  final double centerLng = 11.2558;

  @override
  void initState() {
    super.initState();
    SupabaseClient.instance.fetchEvents();
    SupabaseClient.instance.fetchMyRequests();
    SupabaseClient.instance.fetchMyNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<List<SupabaseEvent>>(
          valueListenable: SupabaseClient.instance.eventsNotifier,
          builder: (context, allEvents, _) {
            // Apply radius distance calculations matching haversine model
            final filteredEvents = _isRadiusActive
                ? allEvents.where((e) {
                    double distance =
                        SupabaseClient.instance.calculateHaversineDistance(
                      centerLat,
                      centerLng,
                      e.latitude,
                      e.longitude,
                    );
                    return distance <= _radiusKm;
                  }).toList()
                : allEvents;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- PREMIUM ELEGANT HEADER ---
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield, color: premiumGold, size: 24),
                          SizedBox(width: 8),
                          Text(
                            "ECORA",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                              letterSpacing: 4,
                              fontFamily: 'Serif',
                              color: premiumGold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Stack(
                            children: [
                              const Icon(Icons.notifications,
                                  color: textSecondary, size: 24),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: premiumGold,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: slateSurface, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: premiumGold.withValues(alpha: 0.1),
                              border: Border.all(
                                  color: premiumGold.withValues(alpha: 0.5),
                                  width: 1),
                            ),
                            child: const Icon(Icons.person,
                                color: premiumGold, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // --- SUB-HEADER: TRENDING TABLES & SWITCHER ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Tavoli del Momento",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: slateSurface,
                          borderRadius: BorderRadius.circular(24),
                          border:
                              Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _isMapView = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: !_isMapView
                                      ? premiumGold
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "Lista",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        !_isMapView ? matteDark : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _isMapView = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isMapView
                                      ? premiumGold
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "Mappa",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _isMapView ? matteDark : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // --- DISTANCE SPACER SLIDER ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: slateSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _isRadiusActive,
                                    activeColor: premiumGold,
                                    checkColor: matteDark,
                                    onChanged: (val) {
                                      setState(() {
                                        _isRadiusActive = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Filtra per posizione",
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Text(
                              _isRadiusActive
                                  ? "${_radiusKm.toInt()} km"
                                  : "Firenze (Tutti)",
                              style: const TextStyle(
                                color: premiumGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (_isRadiusActive) ...[
                          const SizedBox(height: 6),
                          Slider(
                            value: _radiusKm,
                            min: 1.0,
                            max: 50.0,
                            activeColor: premiumGold,
                            inactiveColor: const Color(0xFF424242),
                            onChanged: (val) {
                              setState(() {
                                _radiusKm = val;
                              });
                            },
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // --- CONTENT CONTAINER ---
                Expanded(
                  child: filteredEvents.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_queue,
                                  color: textSecondary, size: 48),
                              SizedBox(height: 12),
                              Text(
                                "Nessun evento riservato nel raggio selezionato",
                                style: TextStyle(
                                    color: textSecondary, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : !_isMapView
                          ? ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              itemCount: filteredEvents.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  // --- PRIVACY BANNER NOTE ---
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: premiumGold.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: premiumGold.withValues(alpha: 0.15)),
                                    ),
                                    child: const Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.privacy_tip,
                                            color: premiumGold, size: 20),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "BLOCCO PRIVACY DI PRECISIONE",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.0,
                                                  color: premiumGold,
                                                ),
                                              ),
                                              SizedBox(height: 3),
                                              Text(
                                                "I dettagli GPS precisi e l'organizzatore sono bloccati finché il tuo profilo non viene approvato dall'organizzatore dell'evento. Ecora dà priorità al tuo anonimato.",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: textSecondary,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                final ev = filteredEvents[index - 1];
                                return EventFeedCard(
                                  event: ev,
                                  onClick: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EventDetailsPage(event: ev),
                                      ),
                                    );
                                  },
                                );
                              },
                            )
                          : Stack(
                              children: [
                                // Drawing map canvas matching CartoDB styling
                                Positioned.fill(
                                  child: Container(
                                    color: const Color(0xFF0F0F0F),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return GestureDetector(
                                          onTapDown: (details) {
                                            // Project coordinates back for tap matching
                                            final offset =
                                                details.localPosition;
                                            SupabaseEvent? tappedEvent;
                                            double minDistance = 99999.0;
                                            for (var ev in filteredEvents) {
                                              final screenPt = _projectCoords(
                                                ev.latitude,
                                                ev.longitude,
                                                centerLat,
                                                centerLng,
                                                constraints.maxWidth,
                                                constraints.maxHeight,
                                              );
                                              double dist = sqrt(pow(
                                                      offset.dx - screenPt.dx,
                                                      2) +
                                                  pow(offset.dy - screenPt.dy,
                                                      2));
                                              if (dist < 32.0 &&
                                                  dist < minDistance) {
                                                minDistance = dist;
                                                tappedEvent = ev;
                                              }
                                            }
                                            setState(() {
                                              _selectedPointEvent = tappedEvent;
                                            });
                                          },
                                          child: CustomPaint(
                                            painter: FlorenceMapPainter(
                                              events: filteredEvents,
                                              centerLat: centerLat,
                                              centerLng: centerLng,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                // Top description overlay bar
                                Positioned(
                                  top: 12,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: matteDark.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color:
                                                Colors.white.withValues(alpha: 0.04)),
                                      ),
                                      child: const Text(
                                        "Mappa Dark CartoDB — Tocca i nodi luminosi per i dettagli",
                                        style: TextStyle(
                                            color: textSecondary, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ),

                                // Highlighted detail bottom drawer card
                                if (_selectedPointEvent != null)
                                  Positioned(
                                    bottom: 16,
                                    left: 16,
                                    right: 16,
                                    child: FadeInWidget(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  EventDetailsPage(
                                                      event:
                                                          _selectedPointEvent!),
                                            ),
                                          );
                                        },
                                        child: Card(
                                          color: slateSurface,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            side: const BorderSide(
                                                color: premiumGold, width: 1),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.network(
                                                    _selectedPointEvent!
                                                        .imageUrl,
                                                    width: 64,
                                                    height: 64,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (context, _, __) =>
                                                            Container(
                                                      color: Colors.grey,
                                                      width: 64,
                                                      height: 64,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        _selectedPointEvent!
                                                            .title,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 15,
                                                            color: textPrimary),
                                                      ),
                                                      Text(
                                                        "Tavolo al ${(_selectedPointEvent!.tableCompletionPercentage * 100).toInt()}% Riservato",
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                            color: premiumGold),
                                                      ),
                                                      const Text(
                                                        "Firenze Sud — Tocca per richiedere l'accesso",
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                textSecondary),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Icon(Icons.chevron_right,
                                                    color: premiumGold),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Linear projection helper
  Offset _projectCoords(double lat, double lng, double centerLat,
      double centerLng, double width, double height) {
    const double scale = 14000.0;
    double x = width / 2.0 + (lng - centerLng) * scale * 0.70;
    double y = height / 2.0 - (lat - centerLat) * scale;
    return Offset(
      x.clamp(40.0, width - 40.0),
      y.clamp(40.0, height - 40.0),
    );
  }
}

// --- FLORENCE MAP PAINTER ---

class FlorenceMapPainter extends CustomPainter {
  final List<SupabaseEvent> events;
  final double centerLat;
  final double centerLng;

  FlorenceMapPainter({
    required this.events,
    required this.centerLat,
    required this.centerLng,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Draw River Arno cutting through Florence
    final riverPaint = Paint()
      ..color = const Color(0xFF1A2B2D)
      ..strokeWidth = 32.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final riverPath = Path();
    riverPath.moveTo(0, height * 0.45);
    riverPath.cubicTo(width * 0.3, height * 0.42, width * 0.7, height * 0.52,
        width, height * 0.48);
    canvas.drawPath(riverPath, riverPaint);

    // 2. Draw CartoDB radial rings representing Florence bounds
    final ringPaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(
          Offset(width / 2, height / 2), width * 0.15 * i, ringPaint);
    }

    // Florence main grid streets
    final streetPaint = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
        Offset(0, height * 0.2), Offset(width, height * 0.35), streetPaint);
    canvas.drawLine(
        Offset(0, height * 0.75), Offset(width, height * 0.65), streetPaint);
    canvas.drawLine(
        Offset(width * 0.25, 0), Offset(width * 0.35, height), streetPaint);
    canvas.drawLine(
        Offset(width * 0.75, 0), Offset(width * 0.60, height), streetPaint);

    // 3. Draw Event Pin Targets
    final guestId =
        SupabaseClient.instance.currentProfileNotifier.value?.id ?? "";
    final requests = SupabaseClient.instance.requestsNotifier.value;

    for (var ev in events) {
      final screenPt = _project(ev.latitude, ev.longitude, width, height);
      final req = requests.firstWhere(
        (r) => r.userId == guestId && r.eventId == ev.id,
        orElse: () => SupabaseParticipationRequest(
            id: "", userId: "", eventId: "", status: ""),
      );
      final bool isApproved = req.status == "approved";

      final pulseColor =
          isApproved ? const Color(0x334CAF50) : premiumGold.withValues(alpha: 0.25);
      final coreColor = isApproved ? const Color(0xFF4CAF50) : premiumGold;

      // Glow halo
      canvas.drawCircle(screenPt, 24.0, Paint()..color = pulseColor);
      // Core dot
      canvas.drawCircle(screenPt, 8.0, Paint()..color = coreColor);
      // Outer ring
      canvas.drawCircle(
          screenPt,
          8.0,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
    }
  }

  Offset _project(double lat, double lng, double width, double height) {
    const double scale = 14000.0;
    double x = width / 2.0 + (lng - centerLng) * scale * 0.70;
    double y = height / 2.0 - (lat - centerLat) * scale;
    return Offset(
      x.clamp(40.0, width - 40.0),
      y.clamp(40.0, height - 40.0),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- EVENT FEED CARD WIDGET ---

class EventFeedCard extends StatelessWidget {
  final SupabaseEvent event;
  final VoidCallback onClick;

  const EventFeedCard({
    Key? key,
    required this.event,
    required this.onClick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: slateSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onClick,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Cover Photo
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24)),
                  child: Image.network(
                    event.imageUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => Container(
                      color: Colors.grey,
                      width: double.infinity,
                      height: 180,
                    ),
                  ),
                ),
                // Cover gradient dark shader
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Completion Tag
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: const BoxDecoration(
                      color: premiumGold,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(4),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      "URGENTE: ${(event.tableCompletionPercentage * 100).toInt()}% RISERVATO",
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: matteDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Card details
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.title.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: premiumGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: premiumGold.withValues(alpha: 0.3), width: 0.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user,
                                color: premiumGold, size: 10),
                            SizedBox(width: 3),
                            Text(
                              "Alta Affidabilità",
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: premiumGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Map Marker Discreet representation
                  const Row(
                    children: [
                      Icon(Icons.location_on, color: premiumGold, size: 14),
                      SizedBox(width: 4),
                      Text(
                        "Zona Colline del Sud, Firenze (Solo Approvati)",
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Text(
                    event.description,
                    style: const TextStyle(
                        fontSize: 12, color: textSecondary, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),

                  // Table progress line
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${event.currentApprovedCount} di ${event.maxParticipants} coppie confermate",
                        style: const TextStyle(
                            fontSize: 11,
                            color: premiumGold,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "${(event.tableCompletionPercentage * 100).toInt()}% posti riservati",
                        style:
                            const TextStyle(fontSize: 10, color: textSecondary),
                      )
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: event.tableCompletionPercentage,
                      backgroundColor: const Color(0xFF323232),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(premiumGold),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TAB 1: NOTIFICATIONS SCREEN (SWIPE-TO-DELETE LOGIC) ---

class NotificationsScreen extends StatelessWidget {
  final List<NotificationItem> notifications;
  final Function(String) onDeleteNotification;

  const NotificationsScreen({
    Key? key,
    required this.notifications,
    required this.onDeleteNotification,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "NOTIFICHE",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.5,
                  color: premiumGold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mail_outline,
                                color: textSecondary, size: 48),
                            SizedBox(height: 12),
                            Text(
                              "Il tuo feed degli inviti privati è vuoto.",
                              style:
                                  TextStyle(fontSize: 13, color: textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          // Use Dismissible for beautiful swipe-to-delete support
                          return Dismissible(
                            key: Key(item.id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) {
                              onDeleteNotification(item.id);
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC62828),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            child: Card(
                              color: slateSurface,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: item.status == "approved"
                                            ? const Color(0x334CAF50)
                                            : const Color(0x33C62828),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        item.status == "approved"
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: item.status == "approved"
                                            ? const Color(0xFF4CAF50)
                                            : const Color(0xFFEF5350),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.status == "approved"
                                                ? "Invito Approvato"
                                                : "Richiesta Rifiutata",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: textPrimary),
                                          ),
                                          Text(
                                            item.status == "approved"
                                                ? "Stato approvato per ${item.eventTitle}. Coordinate GPS sbloccate."
                                                : "La tua richiesta per ${item.eventTitle} è stata riservatamente declinata.",
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: textSecondary,
                                                height: 1.3),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.timestamp,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: premiumGold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TAB 2: MESSAGES SCREEN (PLACEHOLDER CHAT) ---

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "STANZE CHAT PRIVATE",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.5,
                  color: premiumGold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: slateSurface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.forum, color: premiumGold, size: 48),
                      SizedBox(height: 16),
                      Text(
                        "Conversazioni Riservate",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textPrimary),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "I cerchi di chat si bloccano automaticamente in cicli di privacy personalizzati 'Tablo'. Puoi comunicare con altre coppie rigorosamente dopo che entrambi gli inviti a un tavolo condiviso sono stati approvati dall'organizzatore.",
                        style: TextStyle(
                            fontSize: 12, color: textSecondary, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "CHAT ATTIVE (0)",
                style: TextStyle(
                    fontSize: 12, color: textSecondary, letterSpacing: 1),
              ),
              const SizedBox(height: 12),
              Card(
                color: slateSurface.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF333333),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock,
                            color: textSecondary, size: 16),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Gruppo di Incontro Villa Nobile",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textSecondary,
                                  fontSize: 14),
                            ),
                            Text(
                              "Chat bloccata fino all'accettazione del tavolo",
                              style: TextStyle(
                                  color: Color(0x80FFA0A0), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// Fade in widget helper to mimic Compose animated visibility
class FadeInWidget extends StatelessWidget {
  final Widget child;
  const FadeInWidget({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: child,
    );
  }
}
