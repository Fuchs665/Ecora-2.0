import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart';
import 'user_profile_page.dart';

class GestoreDashboard extends StatefulWidget {
  const GestoreDashboard({Key? key}) : super(key: key);

  @override
  State<GestoreDashboard> createState() => _GestoreDashboardState();
}

class _GestoreDashboardState extends State<GestoreDashboard> {
  int _selectedTab = 0; // 0 = Owner Feed, 1 = Guest Inspector, 3 = Chats/Messages, 4 = Club Profile
  bool _showCreateForm = false;

  @override
  Widget build(BuildContext context) {
    // Read current host profile
    final hostProfile = SupabaseClient.instance.currentProfileNotifier.value;
    if (hostProfile == null) {
      return const Scaffold(body: Center(child: Text("Access restricted.")));
    }

    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return ValueListenableBuilder<List<SupabaseParticipationRequest>>(
      valueListenable: SupabaseClient.instance.requestsNotifier,
      builder: (context, requests, _) {
        final pendingCount = requests.where((r) => r.status == 'pending').length;

        // Build list of widgets corresponding to the tabs
        final List<Widget> _subScreens = [
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
                  index: _selectedTab == 2 ? 0 : _selectedTab, // Safeguard index 2
                  children: _subScreens,
                ),
          bottomNavigationBar: Container(
            height: 76 + bottomPadding,
            decoration: BoxDecoration(
              color: slateSurface,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.05),
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
                  label: "Inspector",
                ),
                // Plus button placeholder block in bottom navigation
                const BottomNavigationBarItem(
                  icon: Opacity(
                    opacity: 0,
                    child: Icon(Icons.add, size: 24),
                  ),
                  label: "Creator",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.forum, size: 26),
                  label: "Chats",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.security, size: 26),
                  label: "Shield",
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
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "CLUB HUB CONSOLE",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 2.0,
                    color: premiumGold,
                    fontFamily: 'Serif',
                  ),
                ),
                Text(
                  "Owner Dashboard • Live Tables",
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
                    side: BorderSide(color: Colors.red.withOpacity(0.5), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.new_releases, color: Colors.red, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "PENDING ACCESS CLEARANCE",
                                style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 13),
                              ),
                              Text(
                                "$pendingCount guests are waiting for trust & safety screening.",
                                style: const TextStyle(color: textSecondary, fontSize: 12),
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
              "YOUR ACTIVE SELECTION TABLES",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: premiumGold, letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),

            // Active list of table events for the club host
            ...events.map((event) {
              final eventInquiries = requests.where((r) => r.eventId == event.id && r.status == 'pending').length;

              return Card(
                color: slateSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${event.currentApprovedCount} / ${event.maxParticipants} couples checked-in",
                                style: const TextStyle(fontSize: 12, color: premiumGold, fontWeight: FontWeight.w600),
                              ),
                              if (eventInquiries > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "$eventInquiries pending inquiries",
                                  style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
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
  SupabaseParticipationRequest? _selectedRequestToReview;

  void _showSafetyProfileDialog(BuildContext context, SupabaseParticipationRequest req, SupabaseProfile applicant, SupabaseEvent eventObj) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: slateSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.shield, color: premiumGold),
              SizedBox(width: 10),
              Text(
                "TRUST & SAFETY PROFILE",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.0, color: textPrimary, fontFamily: 'Serif'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                applicant.fullName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary),
              ),
              Text(
                "Applying for: ${eventObj.title}",
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
                        const Text("GENDER", style: TextStyle(fontSize: 9, color: textSecondary)),
                        Text(applicant.gender, style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 13)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text("AGE", style: TextStyle(fontSize: 9, color: textSecondary)),
                        Text("${applicant.age} yrs", style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 13)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text("NO-SHOWS", style: TextStyle(fontSize: 9, color: textSecondary)),
                        Text(
                          "${applicant.noShows}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: applicant.noShows > 0 ? Colors.red : Colors.green,
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
                  border: Border.all(color: premiumGold.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite_border, color: premiumGold, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        applicant.noShows == 0
                            ? "Zero history of no-shows. HIGH-TRUST attendee."
                            : "Alert: Profile has historic no-shows.",
                        style: TextStyle(
                          fontSize: 11,
                          color: applicant.noShows == 0 ? Colors.white70 : Colors.red,
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
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF8A80)),
              onPressed: () {
                SupabaseClient.instance.reviewParticipationRequest(req.id, "rejected");
                Navigator.of(ctx).pop();
                setState(() {
                  _selectedRequestToReview = null;
                });
              },
              child: const Text("DISMISS/REJECT", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
              onPressed: () {
                SupabaseClient.instance.reviewParticipationRequest(req.id, "approved");
                Navigator.of(ctx).pop();
                setState(() {
                  _selectedRequestToReview = null;
                });
              },
              child: const Text("APPROVE GUEST", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequests = widget.requests.where((r) => r.status == 'pending').toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "GUEST REQUEST INSPECTOR",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.5,
                  color: premiumGold,
                  fontFamily: 'Serif',
                ),
              ),
              const Text(
                "Pre-screening & Trust Clearance Console",
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: pendingRequests.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, color: premiumGold, size: 54),
                            SizedBox(height: 16),
                            Text(
                              "All guest loops cleared. Perfect high trust table alignment.",
                              style: TextStyle(fontSize: 13, color: textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: pendingRequests.length,
                        itemBuilder: (context, index) {
                          final req = pendingRequests[index];
                          final applicant = SupabaseClient.instance.getProfileById(req.userId);
                          final eventObj = widget.events.firstWhere((e) => e.id == req.eventId);

                          if (applicant == null) return const SizedBox.shrink();

                          return Card(
                            color: slateSurface,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          applicant.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 14),
                                        ),
                                        Text(
                                          "Applied to: ${eventObj.title}",
                                          style: const TextStyle(fontSize: 12, color: premiumGold),
                                        ),
                                        Text(
                                          "Gender: ${applicant.gender}  •  Age: ${applicant.age} anni",
                                          style: const TextStyle(fontSize: 11, color: textSecondary),
                                        )
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: premiumGold,
                                      foregroundColor: matteDark,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                      minimumSize: const Size(0, 32),
                                    ),
                                    onPressed: () {
                                      _showSafetyProfileDialog(context, req, applicant, eventObj);
                                    },
                                    child: const Text(
                                      "SCREEN",
                                      style: TextStyle(color: matteDark, fontWeight: FontWeight.bold, fontSize: 11),
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
                    "CREATE DISCREET GATHERING",
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
                  labelText: "Gathering Title (e.g. Amber Masked Ball)",
                  labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
                  floatingLabelStyle: const TextStyle(color: premiumGold),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
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
                controller: _descriptionController,
                style: const TextStyle(color: textPrimary, fontSize: 13),
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: "Discreet Concept / Entry Protocol",
                  labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
                  floatingLabelStyle: const TextStyle(color: premiumGold),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
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
                controller: _locationController,
                style: const TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: "Private Location Address (Disclosed strictly on approval)",
                  labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
                  floatingLabelStyle: const TextStyle(color: premiumGold),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: premiumGold),
                  ),
                  filled: true,
                  fillColor: slateSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Maximum Couples Attendance Limit: ${_maxParticipants.toInt()}",
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

              // Mock Image List Selection
              const Text(
                "EVENT COVER (Supabase Storage upload simulation)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: premiumGold, letterSpacing: 1.0),
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
                          errorBuilder: (context, _, __) => Container(color: Colors.grey),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () {
                    if (_titleController.text.isNotEmpty && _locationController.text.isNotEmpty) {
                      // Seed coordinates inside Florence
                      final double rndLat = (Random().nextDouble() - 0.5) * 0.03;
                      final double rndLng = (Random().nextDouble() - 0.5) * 0.03;
                      final double mockLat = 43.7695 + rndLat;
                      final double mockLng = 11.2558 + rndLng;

                      SupabaseClient.instance.insertEventAndUploadImage(
                        title: _titleController.text,
                        description: _descriptionController.text,
                        organizerId: widget.organizerId,
                        latitude: mockLat,
                        longitude: mockLng,
                        mockImagePath: _selectedMockImageUrl,
                        maxParticipants: _maxParticipants.toInt(),
                        locationName: _locationController.text,
                      );

                      widget.onDismiss();
                    }
                  },
                  child: const Text(
                    "UPLOAD EVENT TO ECO-SYSTEM",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 12),
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.forum, color: textSecondary, size: 54),
                SizedBox(height: 16),
                Text(
                  "Club Lounges Secured",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                ),
                SizedBox(height: 8),
                Text(
                  "Private channels will open for confirmed matching attendees once requests are verified.",
                  style: TextStyle(fontSize: 12, color: textSecondary, height: 1.5),
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
