import 'package:flutter/material.dart';
import 'main.dart';

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
  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseClient.instance.currentProfileNotifier.value?.id ?? "";

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Event Details",
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
      body: ValueListenableBuilder<List<SupabaseParticipationRequest>>(
        valueListenable: SupabaseClient.instance.requestsNotifier,
        builder: (context, requests, _) {
          // Find if user has a request for this event
          final userReq = requests.firstWhere(
            (r) => r.userId == currentUserId && r.eventId == widget.event.id,
            orElse: () => SupabaseParticipationRequest(id: "", userId: "", eventId: "", status: "none"),
          );
          final requestStatus = userReq.status; // "pending", "approved", "rejected", "none" (default fallback)
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
                                  colors: [Colors.transparent, matteDark.withOpacity(0.9), matteDark],
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
                                "${(widget.event.tableCompletionPercentage * 100).toInt()}% FILLED",
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
                                  "Table Limit: ${widget.event.maxParticipants} couples max (${widget.event.currentApprovedCount} confirmed)",
                                  style: const TextStyle(fontSize: 13, color: textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            const Text(
                              "THE CONCEPT",
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
                              "DISCREET LOCATION GATING",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.5,
                                color: premiumGold,
                              ),
                            ),
                            const SizedBox(height: 8),

                            if (isApproved) ...[
                              // UNLOCKED STATE CARD
                              Card(
                                color: slateSurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: premiumGold.withOpacity(0.5), width: 1),
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
                                            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 10),
                                          const Text(
                                            "INVITATION APPROVED",
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        "Address Revealed:",
                                        style: TextStyle(fontSize: 12, color: textSecondary),
                                      ),
                                      Text(
                                        widget.event.locationName,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                                      ),
                                      const SizedBox(height: 12),
                                      // Precise coords card
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
                                                const Text("Precise Coordinates", style: TextStyle(fontSize: 10, color: textSecondary)),
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
                              )
                            ] else ...[
                              // LOCKED / BLURRED FLOATING MAPPING STATE (FLUTTER REWRITE MATCHING ORIGINAL SPECIFICATIONS)
                              Container(
                                width: double.infinity,
                                height: 180,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF333333)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      // Simulated blurred map streets
                                      Positioned.fill(
                                        child: Container(
                                          color: const Color(0xFF0F0F0F),
                                          child: Opacity(
                                            opacity: 0.1,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: List.generate(
                                                5,
                                                (index) => Container(
                                                  height: 12,
                                                  color: Colors.white,
                                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Blurred fog covering Arno mapping
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [matteDark.withOpacity(0.85), matteDark.withOpacity(0.98)],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Lock instruction details
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.lock, color: premiumGold, size: 32),
                                              const SizedBox(height: 10),
                                              const Text(
                                                "Florence South Area",
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                "Exact location & GPS coordinates are revealed strictly after the host approves your invitation request.",
                                                style: TextStyle(fontSize: 11, color: textSecondary, height: 1.4),
                                                textAlign: TextAlign.center,
                                              ),
                                              if (requestStatus == 'pending') ...[
                                                const SizedBox(height: 10),
                                                const Text(
                                                  "REQUEST PENDING APPROVAL",
                                                  style: TextStyle(color: premiumGold, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                                                ),
                                              ]
                                            ],
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              )
                            ],
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: premiumGold,
                            foregroundColor: matteDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: () {
                            SupabaseClient.instance.submitParticipationRequest(widget.event.id, currentUserId);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.key, color: matteDark, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "REQUEST PRIVATE INVITATION",
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
                            "AWAITING HOST CLEARANCE",
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.check, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "ATTENDANCE CONFIRMED",
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
                            backgroundColor: const Color(0x33C62828),
                            foregroundColor: const Color(0xFFEF5350),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: null,
                          child: const Text(
                            "REQUEST DECLINED",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFEF5350)),
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
