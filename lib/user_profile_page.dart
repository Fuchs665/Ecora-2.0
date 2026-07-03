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

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: slateSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: EditProfileSheet(profile: profile),
      ),
    );
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

              // --- DISCREET BRAND HEADER + EDIT ACTION ---
              Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    "E C O R A",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 6.0,
                      color: premiumGold,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: premiumGold, size: 20),
                      tooltip: "Modifica profilo",
                      onPressed: () => _showEditSheet(context),
                    ),
                  ),
                ],
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
                            color: premiumGold.withValues(alpha: 0.15),
                            blurRadius: 16,
                            spreadRadius: 4,
                          )
                        ],
                        gradient: RadialGradient(
                          colors: [premiumGold.withValues(alpha: 0.25), Colors.transparent],
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
                  color: premiumGold.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: premiumGold.withValues(alpha: 0.5), width: 1),
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
                      color: Colors.red.withValues(alpha: 0.8),
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

// --- EDIT PROFILE BOTTOM SHEET (real Supabase UPDATE) ---

class EditProfileSheet extends StatefulWidget {
  final SupabaseProfile profile;

  const EditProfileSheet({Key? key, required this.profile}) : super(key: key);

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _locationController;
  String? _profileType;
  String? _privacyLevel;
  bool _isSaving = false;

  static const List<String> _profileTypes = [
    "Coppia U/D",
    "Coppia D/D",
    "Coppia U/U",
    "Donna Singola",
    "Uomo Singolo",
  ];

  static const Map<String, String> _privacyOptions = {
    "Visibile": "visible",
    "In incognito": "ghost",
  };

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.profile.fullName);
    _locationController =
        TextEditingController(text: widget.profile.genericLocation ?? "");
    _profileType = _profileTypes.contains(widget.profile.profileType)
        ? widget.profile.profileType
        : null;
    _privacyLevel =
        _privacyOptions.containsValue(widget.profile.privacyLevel)
            ? widget.profile.privacyLevel
            : null;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
      floatingLabelStyle: const TextStyle(color: premiumGold),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: premiumGold),
      ),
      filled: true,
      fillColor: matteDark.withValues(alpha: 0.5),
    );
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    final location = _locationController.text.trim();

    if (nickname.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Il nickname deve contenere almeno 3 caratteri."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final error = await SupabaseClient.instance.updateMyProfile(
      nickname: nickname,
      genericLocation: location,
      profileType: _profileType,
      privacyLevel: _privacyLevel,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "MODIFICA PROFILO",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 2,
              color: premiumGold,
              fontFamily: 'Serif',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nicknameController,
            style: const TextStyle(color: textPrimary, fontSize: 13),
            decoration: _fieldDecoration("Nickname"),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _locationController,
            style: const TextStyle(color: textPrimary, fontSize: 13),
            decoration: _fieldDecoration("Località (generica)"),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _profileType,
            dropdownColor: slateSurface,
            style: const TextStyle(color: textPrimary, fontSize: 13),
            decoration: _fieldDecoration("Tipologia di profilo"),
            items: _profileTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _profileType = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _privacyLevel,
            dropdownColor: slateSurface,
            style: const TextStyle(color: textPrimary, fontSize: 13),
            decoration: _fieldDecoration("Livello di privacy"),
            items: _privacyOptions.entries
                .map((e) =>
                    DropdownMenuItem(value: e.value, child: Text(e.key)))
                .toList(),
            onChanged: (v) => setState(() => _privacyLevel = v),
          ),
          const SizedBox(height: 24),
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
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(matteDark),
                      ),
                    )
                  : const Text(
                      "SALVA MODIFICHE",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontSize: 12),
                    ),
            ),
          ),
        ],
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