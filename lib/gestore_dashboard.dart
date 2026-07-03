import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart';
import 'user_profile_page.dart';
import 'event_details_page.dart';

class GestoreDashboard extends StatefulWidget {
  const GestoreDashboard({Key? key}) : super(key: key);

  @override
  State<GestoreDashboard> createState() => _GestoreDashboardState();
}

class _GestoreDashboardState extends State<GestoreDashboard> {
  int _selectedTab =
      0; // 0 = Owner Feed, 1 = Guest Inspector, 3 = Chats/Messages, 4 = Club Profile
  bool _showCreateForm = false;

  @override
  void initState() {
    super.initState();
    SupabaseClient.instance.fetchEvents();
    SupabaseClient.instance.fetchHostRequests();
  }

  @override
  Widget build(BuildContext context) {
    // Read current host profile
    final hostProfile = SupabaseClient.instance.currentProfileNotifier.value;
    if (hostProfile == null) {
      return const Scaffold(body: Center(child: Text("Accesso limitato.")));
    }

    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return ValueListenableBuilder<List<SupabaseParticipationRequest>>(
      valueListenable: SupabaseClient.instance.requestsNotifier,
      builder: (context, requests, _) {
        final pendingCount =
            requests.where((r) => r.status == 'pending').length;

        // Build list of widgets corresponding to the tabs
        final List<Widget> subScreens = [
          ValueListenableBuilder<List<SupabaseEvent>>(
            valueListenable: SupabaseClient.instance.eventsNotifier,
            builder: (context, events, _) {
              return ClubDashboardScreen(
                events: events,
                requests: requests,
                onSelectRequestInspector: () {
                  setState(() {
                    _selectedTab = 1;
                    _showCreateForm = false;
                  });
                },
              );
            },
          ),
          ValueListenableBuilder<List<SupabaseEvent>>(
            valueListenable: SupabaseClient.instance.eventsNotifier,
            builder: (context, events, _) {
              return RequestInspectorScreen(
                events: events,
                requests: requests,
              );
            },
          ),
          const SizedBox.shrink(), // Placeholder index 2 (decorative center)
          const ClubMessagesScreen(),
          UserProfilePage(
            profile: hostProfile,
            onLogout: () {
              SupabaseClient.instance.logout();
            },
          ),
        ];

        return Scaffold(
          body: _showCreateForm
              ? CreateEventForm(
                  organizerId: hostProfile.id,
                  onDismiss: () {
                    setState(() {
                      _showCreateForm = false;
                    });
                  },
                )
              : IndexedStack(
                  index:
                      _selectedTab == 2 ? 0 : _selectedTab, // Safeguard index 2
                  children: subScreens,
                ),
          bottomNavigationBar: Container(
            height: 76 + bottomPadding,
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
              currentIndex: _selectedTab,
              onTap: (index) {
                if (index == 2) {
                  setState(() {
                    _showCreateForm = true;
                  });
                } else {
                  setState(() {
                    _selectedTab = index;
                    _showCreateForm = false;
                  });
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
                  icon: Icon(Icons.dashboard, size: 26),
                  label: "Dashboard",
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      const Icon(Icons.verified_user, size: 26),
                      if (pendingCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                            child: Text(
                              '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: "Ispettore",
                ),
                // Plus button placeholder block in bottom navigation
                const BottomNavigationBarItem(
                  icon: Opacity(
                    opacity: 0,
                    child: Icon(Icons.add, size: 24),
                  ),
                  label: "Creatore",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.forum, size: 26),
                  label: "Chat",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.security, size: 26),
                  label: "Scudo",
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              setState(() {
                _showCreateForm = true;
              });
            },
            backgroundColor: premiumGold,
            foregroundColor: matteDark,
            shape: const CircleBorder(),
            elevation: 4,
            child: const Icon(Icons.add, size: 28),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
        );
      },
    );
  }
}

// --- SUB-SCREEN 1: OWNER FEED SCREEN (CLUB DASHBOARD) ---

class ClubDashboardScreen extends StatelessWidget {
  final List<SupabaseEvent> events;
  final List<SupabaseParticipationRequest> requests;
  final VoidCallback onSelectRequestInspector;

  const ClubDashboardScreen({
    Key? key,
    required this.events,
    required this.requests,
    required this.onSelectRequestInspector,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pendingCount = requests.where((r) => r.status == 'pending').length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Club Info Console banner Header
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "CONSOLLE CLUB",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 2.0,
                    color: premiumGold,
                    fontFamily: 'Serif',
                  ),
                ),
                Text(
                  "Dashboard Organizzatore • Tavoli Attivi",
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Red Alert banner if guests are pending review
            if (pendingCount > 0) ...[
              GestureDetector(
                onTap: onSelectRequestInspector,
                child: Card(
                  color: const Color(0x2AA83232),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.new_releases,
                            color: Colors.red, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "APPROVAZIONI ACCESSO IN ATTESA",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                    fontSize: 13),
                              ),
                              Text(
                                "$pendingCount ospiti in attesa di screening di sicurezza e fiducia.",
                                style: const TextStyle(
                                    color: textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.red),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            const Text(
              "I TUOI TAVOLI ATTIVI",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: premiumGold,
                  letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),

            // Active list of table events for the club host
            ...events.map((event) {
              final eventInquiries = requests
                  .where((r) => r.eventId == event.id && r.status == 'pending')
                  .length;

              return Card(
                color: slateSurface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailsPage(event: event),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            event.imageUrl,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, __) => Container(
                              color: Colors.grey,
                              width: 72,
                              height: 72,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${event.currentApprovedCount} / ${event.maxParticipants} coppie confermate",
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: premiumGold,
                                    fontWeight: FontWeight.w600),
                              ),
                              if (eventInquiries > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "$eventInquiries richieste in attesa",
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold),
                                ),
                              ]
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: premiumGold),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// --- SUB-SCREEN 2: GUEST REQUEST INSPECTOR WITH MODAL APPROVAL ---

class RequestInspectorScreen extends StatefulWidget {
  final List<SupabaseEvent> events;
  final List<SupabaseParticipationRequest> requests;

  const RequestInspectorScreen({
    Key? key,
    required this.events,
    required this.requests,
  }) : super(key: key);

  @override
  State<RequestInspectorScreen> createState() => _RequestInspectorScreenState();
}

class _RequestInspectorScreenState extends State<RequestInspectorScreen> {
  Future<void> _reviewRequest(
      BuildContext dialogCtx, String requestId, String status) async {
    Navigator.of(dialogCtx).pop();
    final error = await SupabaseClient.instance
        .reviewParticipationRequest(requestId, status);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showSafetyProfileDialog(
      BuildContext context,
      SupabaseParticipationRequest req,
      SupabaseProfile applicant,
      SupabaseEvent eventObj) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: slateSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.shield, color: premiumGold),
              SizedBox(width: 10),
              Text(
                "PROFILO DI SICUREZZA E FIDUCIA",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.0,
                    color: textPrimary,
                    fontFamily: 'Serif'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                applicant.fullName,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textPrimary),
              ),
              Text(
                "Richiesta per: ${eventObj.title}",
                style: const TextStyle(fontSize: 12, color: premiumGold),
              ),
              const SizedBox(height: 16),
              // Candidate Stats Block Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: matteDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text("GENERE",
                            style:
                                TextStyle(fontSize: 9, color: textSecondary)),
                        Text(applicant.gender,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                fontSize: 13)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text("ETÀ",
                            style:
                                TextStyle(fontSize: 9, color: textSecondary)),
                        Text("${applicant.age} anni",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                fontSize: 13)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text("ASSENZE (NO-SHOW)",
                            style:
                                TextStyle(fontSize: 9, color: textSecondary)),
                        Text(
                          "${applicant.noShows}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: applicant.noShows > 0
                                ? Colors.red
                                : Colors.green,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: premiumGold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite_border,
                        color: premiumGold, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        applicant.noShows == 0
                            ? "Nessuna assenza passata. Partecipante ad ALTA AFFIDABILITÀ."
                            : "Attenzione: Il profilo ha assenze passate.",
                        style: TextStyle(
                          fontSize: 11,
                          color: applicant.noShows == 0
                              ? Colors.white70
                              : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF8A80)),
              onPressed: () => _reviewRequest(ctx, req.id, "rejected"),
              child: const Text("RIFIUTA",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white),
              onPressed: () => _reviewRequest(ctx, req.id, "approved"),
              child: const Text("APPROVA OSPITE",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequests =
        widget.requests.where((r) => r.status == 'pending').toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "ISPETTORE RICHIESTE OSPITI",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.5,
                  color: premiumGold,
                  fontFamily: 'Serif',
                ),
              ),
              const Text(
                "Consolle di Pre-screening e Approvazione",
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: pendingRequests.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: premiumGold, size: 54),
                            SizedBox(height: 16),
                            Text(
                              "Tutti i profili ospiti sono approvati. Tavolo ad alta affidabilità allineato.",
                              style:
                                  TextStyle(fontSize: 13, color: textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: pendingRequests.length,
                        itemBuilder: (context, index) {
                          final req = pendingRequests[index];
                          final applicant = SupabaseClient.instance
                              .getProfileById(req.userId);
                          final eventIdx = widget.events
                              .indexWhere((e) => e.id == req.eventId);

                          if (applicant == null || eventIdx < 0) {
                            return const SizedBox.shrink();
                          }
                          final eventObj = widget.events[eventIdx];

                          return Card(
                            color: slateSurface,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          applicant.fullName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                              fontSize: 14),
                                        ),
                                        Text(
                                          "Richiesta per: ${eventObj.title}",
                                          style: const TextStyle(
                                              fontSize: 12, color: premiumGold),
                                        ),
                                        Text(
                                          "Genere: ${applicant.gender}  •  Età: ${applicant.age} anni",
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: textSecondary),
                                        )
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: premiumGold,
                                      foregroundColor: matteDark,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 0),
                                      minimumSize: const Size(0, 32),
                                    ),
                                    onPressed: () {
                                      _showSafetyProfileDialog(
                                          context, req, applicant, eventObj);
                                    },
                                    child: const Text(
                                      "VALUTA",
                                      style: TextStyle(
                                          color: matteDark,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- SUB-SCREEN 3: EVENT GATHERING CREATION FORM ---

class CreateEventForm extends StatefulWidget {
  final String organizerId;
  final VoidCallback onDismiss;

  const CreateEventForm({
    Key? key,
    required this.organizerId,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<CreateEventForm> createState() => _CreateEventFormState();
}

class _CreateEventFormState extends State<CreateEventForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  double _maxParticipants = 8.0;
  DateTime? _eventDate;
  bool _isSubmitting = false;

  String get _formattedEventDate {
    final d = _eventDate;
    if (d == null) return "Seleziona data e ora dell'evento";
    return "${d.day.toString().padLeft(2, '0')}/"
        "${d.month.toString().padLeft(2, '0')}/${d.year} — "
        "${d.hour.toString().padLeft(2, '0')}:"
        "${d.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _eventDate ?? DateTime(now.year, now.month, now.day, 22, 0)),
    );
    if (time == null || !mounted) return;
    setState(() {
      _eventDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  final List<String> mockImageOptions = const [
    "https://images.unsplash.com/photo-1541252260730-0412e8e2108e?auto=format&fit=crop&q=80&w=600",
    "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?auto=format&fit=crop&q=80&w=600",
    "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&q=80&w=600",
    "https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?auto=format&fit=crop&q=80&w=600"
  ];
  late String _selectedMockImageUrl;

  @override
  void initState() {
    super.initState();
    _selectedMockImageUrl = mockImageOptions[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "CREA INCONTRO RISERVATO",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.0,
                      color: premiumGold,
                      fontFamily: 'Serif',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: premiumGold),
                    onPressed: widget.onDismiss,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _titleController,
                style: const TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: "Titolo Incontro (es. Ballo in Maschera Ambra)",
                  labelStyle:
                      const TextStyle(color: textSecondary, fontSize: 12),
                  floatingLabelStyle: const TextStyle(color: premiumGold),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: premiumGold),
                  ),
                  filled: true,
                  fillColor: slateSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: textPrimary, fontSize: 13),
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: "Concept Riservato / Protocollo d'Ingresso",
                  labelStyle:
                      const TextStyle(color: textSecondary, fontSize: 12),
                  floatingLabelStyle: const TextStyle(color: premiumGold),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: premiumGold),
                  ),
                  filled: true,
                  fillColor: slateSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _locationController,
                style: const TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText:
                      "Indirizzo della Location Privata (Svelato solo dopo l'approvazione)",
                  labelStyle:
                      const TextStyle(color: textSecondary, fontSize: 12),
                  floatingLabelStyle: const TextStyle(color: premiumGold),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: premiumGold),
                  ),
                  filled: true,
                  fillColor: slateSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),

              // --- DATA E ORA EVENTO ---
              GestureDetector(
                onTap: _pickEventDate,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: slateSurface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _eventDate == null
                          ? Colors.white.withValues(alpha: 0.06)
                          : premiumGold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: premiumGold, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _formattedEventDate,
                        style: TextStyle(
                          color:
                              _eventDate == null ? textSecondary : textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Limite Massimo Coppie Partecipanti: ${_maxParticipants.toInt()}",
                style: const TextStyle(color: textSecondary, fontSize: 13),
              ),
              Slider(
                value: _maxParticipants,
                min: 4.0,
                max: 20.0,
                activeColor: premiumGold,
                inactiveColor: const Color(0xFF424242),
                onChanged: (val) {
                  setState(() {
                    _maxParticipants = val;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Selezione copertina da galleria preset
              // (upload foto reale da dispositivo: blocco Fase 4)
              const Text(
                "COPERTINA EVENTO",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: premiumGold,
                    letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: mockImageOptions.map((url) {
                  final bool isSelected = _selectedMockImageUrl == url;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMockImageUrl = url;
                      });
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? premiumGold : Colors.transparent,
                          width: isSelected ? 3.0 : 0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isSelected ? 5 : 8),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, _, __) =>
                              Container(color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: premiumGold,
                    foregroundColor: matteDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          if (_titleController.text.isEmpty ||
                              _locationController.text.isEmpty ||
                              _eventDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Compila titolo, indirizzo e data dell'evento."),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          // TODO(blocco geocoding): coordinate reali
                          // dall'indirizzo; per ora punto casuale su Firenze.
                          final double lat =
                              43.7695 + (Random().nextDouble() - 0.5) * 0.03;
                          final double lng =
                              11.2558 + (Random().nextDouble() - 0.5) * 0.03;

                          setState(() => _isSubmitting = true);

                          final error =
                              await SupabaseClient.instance.createEvent(
                            title: _titleController.text,
                            description: _descriptionController.text,
                            hostId: widget.organizerId,
                            latitude: lat,
                            longitude: lng,
                            imageUrl: _selectedMockImageUrl,
                            eventDate: _eventDate!,
                            maxGuests: _maxParticipants.toInt(),
                            locationName: _locationController.text,
                          );

                          if (!mounted) return;
                          setState(() => _isSubmitting = false);

                          if (error != null) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(error),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          widget.onDismiss();
                        },
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(matteDark),
                          ),
                        )
                      : const Text(
                          "CARICA EVENTO NEL CLUB",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              fontSize: 12),
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

// --- SUB-SCREEN 4: SECURED CHATS ---

class ClubMessagesScreen extends StatelessWidget {
  const ClubMessagesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum, color: textSecondary, size: 54),
                SizedBox(height: 16),
                Text(
                  "Stanze del Club Protette",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textPrimary),
                ),
                SizedBox(height: 8),
                Text(
                  "I canali privati si apriranno per i partecipanti confermati una volta verificate le richieste.",
                  style: TextStyle(
                      fontSize: 12, color: textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
