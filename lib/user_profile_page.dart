import 'package:flutter/material.dart';
import 'main.dart';

class UserProfilePage extends StatelessWidget {
  final SupabaseProfile profile;
  final VoidCallback onLogout;

  const UserProfilePage({
    Key? key,
    required this.profile,
    required this.onLogout,
  }) : super(key: key);

  String _getProfileAvatarUrl() {
    if (profile.gender == "Coppia") {
      return "https://images.unsplash.com/photo-1516575307900-510b501c3bf4?auto=format&fit=crop&q=80&w=300";
    } else if (profile.gender == "Donna") {
      return "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&q=80&w=300";
    } else {
      return "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=300";
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool highTrustEarned = profile.noShows == 0;

    return Scaffold(
      backgroundColor: matteDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              // --- DISCREET BRAND HEADER ---
              const Text(
                "E C O R A",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 6.0,
                  color: premiumGold,
                ),
              ),
              const SizedBox(height: 24),

              // --- PROFILE PICTURE ARCHITECTURE WITH GOLD CARD METALLIC HALO ---
              SizedBox(
                width: 136,
                height: 136,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow outer background halo
                    Container(
                      width: 126,
                      height: 126,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: premiumGold.withOpacity(0.15),
                            blurRadius: 16,
                            spreadRadius: 4,
                          )
                        ],
                        gradient: RadialGradient(
                          colors: [premiumGold.withOpacity(0.25), Colors.transparent],
                        ),
                      ),
                    ),

                    // Outer gold ring
                    Container(
                      width: 114,
                      height: 114,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: premiumGold, width: 2),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(60),
                        child: Container(
                          color: slateSurface,
                          child: Image.network(
                            _getProfileAvatarUrl(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, __) => const Icon(Icons.person, color: premiumGold, size: 40),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- FULL NAME & BASIC INFO ---
              Text(
                profile.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 0.5,
                  color: textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              Text(
                "${profile.gender}  •  ${profile.age} anni",
                style: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 14,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // --- HIGH TRUST BADGE ---
              if (highTrustEarned) ...[
                Card(
                  color: premiumGold.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: premiumGold.withOpacity(0.5), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.diamond, color: premiumGold, size: 16),
                        SizedBox(width: 8),
                        Text(
                          "ACCOUNT AD ALTA AFFIDABILITÀ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.5,
                            color: premiumGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // --- STATISTICS METRIC ROW ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StatMetricField(
                    label: "Presenze",
                    value: "${profile.participationsCount}",
                    indicatorColor: premiumGold,
                  ),
                  StatMetricField(
                    label: "No-Show",
                    value: "${profile.noShows}",
                    indicatorColor: profile.noShows > 2 ? Colors.red : textSecondary,
                  ),
                  StatMetricField(
                    label: "Organizzati",
                    value: profile.role == "gestore" ? "45" : "0",
                    indicatorColor: premiumGold,
                  ),
                ],
              ),

              const Spacer(),

              // --- PRIVACY SHIELD FOOTER CARD ---
              Card(
                color: slateSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, color: premiumGold, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Scudo Privacy Attivo",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                            ),
                            Text(
                              "La tua vera foto, l'età e le statistiche sono visibili solo ai club verificati quando richiedi la partecipazione.",
                              style: TextStyle(fontSize: 11, color: textSecondary, height: 1.35),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --- DEED LOGOUT BUTTON ACTION ---
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF424242)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: onLogout,
                  child: Text(
                    "ESCI DAL CLUB",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                      color: Colors.red.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class StatMetricField extends StatelessWidget {
  final String label;
  final String value;
  final Color indicatorColor;

  const StatMetricField({
    Key? key,
    required this.label,
    required this.value,
    required this.indicatorColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: slateSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF333333)),
      ),
      child: Container(
        width: 100,
        height: 90,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: indicatorColor),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10, letterSpacing: 0.5, color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}