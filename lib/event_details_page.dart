import 'dart:ui';
import 'package:flutter/material.dart';
import 'main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class EventDetailsPage extends StatefulWidget {
  final SupabaseEvent event;

  const EventDetailsPage({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  String _requestStatus = 'none';

  @override
  void initState() {
    super.initState();
    _checkRequestStatus();
  }

  Future<void> _checkRequestStatus() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final response = await Supabase.instance.client
          .from('event_requests')
          .select('status')
          .eq('event_id', widget.event.id)
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (response != null && response['status'] != null) {
        if (mounted) {
          setState(() {
            _requestStatus = response['status'].toString();
          });
        }
      }
    } catch (e) {
      debugPrint("Errore durante il recupero dello stato della richiesta: $e");
    }
  }

  Future<void> _submitRequest(String currentUserId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    // UI reattiva subito, ma se l'insert fallisce lo stato viene ripristinato.
    setState(() {
      _requestStatus = 'pending';
    });

    try {
      await Supabase.instance.client.from('event_requests').insert({
        'event_id': widget.event.id,
        'user_id': currentUser.id,
        'status': 'pending',
      });
    } catch (e) {
      debugPrint("Errore nell'inserimento della richiesta reale: $e");
      if (!mounted) return;
      setState(() {
        _requestStatus = 'none';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invio della richiesta non riuscito. Riprova."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await _checkRequestStatus();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = EcoraDataService.instance.currentProfileNotifier.value?.id ?? "";

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dettagli Evento",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: premiumGold),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: matteDark,
        elevation: 0,
      ),
      backgroundColor: matteDark,
      body: Builder(
        builder: (context) {
          // Lo stato della richiesta viene letto dal DB in _checkRequestStatus.
          final requestStatus = _requestStatus;
          final isApproved = requestStatus == "approved";

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- TOP HERO COVER PHOTO WITH OVERLAYS ---
                      Stack(
                        children: [
                          Image.network(
                            widget.event.imageUrl,
                            width: double.infinity,
                            height: 240,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, __) => Container(
                              color: Colors.grey,
                              width: double.infinity,
                              height: 240,
                            ),
                          ),
                          // Premium dark shader gradient
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, matteDark.withValues(alpha: 0.8), matteDark],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          // Top Right completion balloon
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: premiumGold,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${(widget.event.tableCompletionPercentage * 100).toInt()}% RISERVATO",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: matteDark,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // --- CONTENT CORE ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.event.title.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                letterSpacing: 1.0,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Date Field
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, color: premiumGold, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  widget.event.eventDate.replaceAll("T", " @ "),
                                  style: const TextStyle(fontSize: 14, color: premiumGold, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Capacity limit
                            Row(
                              children: [
                                const Icon(Icons.people, color: textSecondary, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  "Limite tavolo: massimo ${widget.event.maxParticipants} coppie (${widget.event.currentApprovedCount} confermate)",
                                  style: const TextStyle(fontSize: 13, color: textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            const Text(
                              "IL CONCEPT",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.5,
                                color: premiumGold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.event.description,
                              style: const TextStyle(fontSize: 14, color: textSecondary, height: 1.45),
                            ),
                            const SizedBox(height: 24),

                            // --- SHIELD DISCREET LOCATION VIEW COMPONENT ---
                            const Text(
                              "LOCALIZZAZIONE RISERVATA",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.5,
                                color: premiumGold,
                              ),
                            ),
                            const SizedBox(height: 8),

                            Stack(
                              children: [
                                // The actual address and map widgets (always present in tree, but blurred if not approved)
                                Card(
                                  color: slateSurface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isApproved ? premiumGold.withValues(alpha: 0.5) : textSecondary.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: isApproved ? Colors.green : Colors.orange,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              isApproved ? "INVITO APPROVATO" : "INVITO DA APPROVARE",
                                              style: TextStyle(
                                                color: isApproved ? Colors.green : Colors.orange,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          "Indirizzo:",
                                          style: TextStyle(fontSize: 12, color: textSecondary),
                                        ),
                                        Text(
                                          widget.event.locationName,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                                        ),
                                        const SizedBox(height: 12),
                                        // Precise coords card (mocking the map block/box)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: matteDark,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text("Coordinate Precise", style: TextStyle(fontSize: 10, color: textSecondary)),
                                                  Text(
                                                    "Lat: ${widget.event.latitude.toStringAsFixed(5)} / Lng: ${widget.event.longitude.toStringAsFixed(5)}",
                                                    style: const TextStyle(fontSize: 12, color: premiumGold, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              const Icon(Icons.directions, color: premiumGold),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                // BLUR OVERLAY SHIELD (when not approved)
                                if (!isApproved)
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Stack(
                                        children: [
                                          // BackdropFilter to blur the underlying address and map card
                                          Positioned.fill(
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                                              child: Container(
                                                color: Colors.black.withValues(alpha: 0.55),
                                              ),
                                            ),
                                          ),
                                          // Golden lock and text overlay
                                          const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.lock, color: premiumGold, size: 36),
                                                  SizedBox(height: 12),
                                                  Text(
                                                    "Indirizzo sbloccato dopo l'approvazione del Club",
                                                    style: TextStyle(
                                                      color: premiumGold,
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 13,
                                                      letterSpacing: 0.5,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),

              // --- FOOTER BUTTON CTA CONTROLS ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Builder(
                  builder: (context) {
                    if (requestStatus == "none") {
                      return SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ecoraPrimaryButtonStyle(),
                          onPressed: () {
                            _submitRequest(currentUserId);
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.key, color: matteDark, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "RICHIEDI INVITO PRIVATO",
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.0),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else if (requestStatus == "pending") {
                      return SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: slateSurface,
                            foregroundColor: premiumGold,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: null, // Disabled awaiting screening
                          child: const Text(
                            "IN ATTESA DI APPROVAZIONE",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      );
                    } else if (requestStatus == "approved") {
                      return SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: () {},
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "PARTECIPAZIONE CONFERMATA",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      // rejected
                      return SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                            foregroundColor: Colors.redAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: null,
                          child: const Text(
                            "RICHIESTA RESPINTA",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent),
                          ),
                        ),
                      );
                    }
                  }
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}