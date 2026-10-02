import 'account_deletion.dart';
import 'cover_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'profile_gallery.dart';
import 'subscription_service.dart';

class UserProfilePage extends StatelessWidget {
  final SupabaseProfile profile;
  final VoidCallback onLogout;

  const UserProfilePage({
    Key? key,
    required this.profile,
    required this.onLogout,
  }) : super(key: key);

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

  void _showBlockedUsersSheet(BuildContext context) {
    EcoraDataService.instance.fetchBlockedUsers();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: slateSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const BlockedUsersSheet(),
    );
  }

  /// Eliminazione account (Blocco E.1b). Il foglio chiama il server; solo a
  /// eliminazione riuscita si chiude e si esce, come un logout.
  void _showDeleteAccountSheet(BuildContext context) {
    final warnings = DeletionWarnings.compute(
      profile: profile,
      events: EcoraDataService.instance.eventsNotifier.value,
      subscription: EcoraSubscriptionService.instance.statusNotifier.value,
      now: DateTime.now(),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: slateSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DeleteAccountSheet(
        warnings: warnings,
        onDelete: EcoraDataService.instance.requestAccountDeletion,
        onDeleted: () async {
          await EcoraDataService.instance.logout();
          ecoraMessengerKey.currentState?.showSnackBar(
              const SnackBar(content: Text(kDeleteAccountDone)));
        },
        onOpenGooglePlay: () => launchUrl(Uri.parse(kPlaySubscriptionsUrl),
            mode: LaunchMode.externalApplication),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: matteDark,
      body: SafeArea(
        // Scorre se lo schermo è basso o il testo è ingrandito; altrimenti il
        // pulsante di uscita resta ancorato in fondo (Spacer).
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
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
                                  colors: [
                                    premiumGold.withValues(alpha: 0.25),
                                    Colors.transparent
                                  ],
                                ),
                              ),
                            ),

                            // Outer gold ring
                            Container(
                              width: 114,
                              height: 114,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: premiumGold, width: 2),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(60),
                                child: _InitialAvatar(name: profile.fullName),
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
                        [
                          profile.gender,
                          if (profile.ageAt(DateTime.now()) != null)
                            "${profile.ageAt(DateTime.now())} anni",
                        ].join("  •  "),
                        style: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Affidabilità, presenze e assenze tornano con dati veri
                      // nel Blocco B.2c.
                      const SizedBox(height: 8),

                      // --- GALLERIA FOTO PROFILO (bucket privato, RLS 0008) ---
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ProfileGallerySection(profileId: profile.id),
                      ),

                      const Spacer(),

                      // --- PRIVACY SHIELD FOOTER CARD ---
                      Card(
                        color: slateSurface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.lock, color: premiumGold, size: 24),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Privacy attiva",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: textPrimary),
                                    ),
                                    Text(
                                      "La tua vera foto, l'età e le statistiche sono visibili solo ai locali verificati quando richiedi la partecipazione.",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                          height: 1.35),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- UTENTI BLOCCATI ---
                      ValueListenableBuilder<List<SupabaseProfile>>(
                        valueListenable:
                            EcoraDataService.instance.blockedNotifier,
                        builder: (context, blocked, _) {
                          return Card(
                            color: slateSurface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading:
                                  const Icon(Icons.block, color: textSecondary),
                              title: Text(
                                "Utenti bloccati (${blocked.length})",
                                style: const TextStyle(
                                    color: textPrimary, fontSize: 13),
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: textSecondary),
                              onTap: () => _showBlockedUsersSheet(context),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // --- ELIMINA ACCOUNT (E.1b) ---
                      Card(
                        color: slateSurface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline,
                              color: EcoraColors.danger),
                          title: const Text(
                            kDeleteAccountEntry,
                            style: TextStyle(
                                color: EcoraColors.danger, fontSize: 13),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: textSecondary),
                          onTap: () => _showDeleteAccountSheet(context),
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
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: onLogout,
                          child: Text(
                            "ESCI DALL'ACCOUNT",
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
            ),
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
    _privacyLevel = _privacyOptions.containsValue(widget.profile.privacyLevel)
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
    return ecoraInputDecoration(label, fillColor: matteDark);
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
    final error = await EcoraDataService.instance.updateMyProfile(
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
                .map(
                    (e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
                .toList(),
            onChanged: (v) => setState(() => _privacyLevel = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ecoraPrimaryButtonStyle(),
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

// --- BLOCKED USERS SHEET (lista + sblocco) ---

class BlockedUsersSheet extends StatelessWidget {
  const BlockedUsersSheet({Key? key}) : super(key: key);

  Future<void> _unblock(
      BuildContext context, String userId, String name) async {
    final error = await EcoraDataService.instance.unblockUser(userId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? "$name è stato sbloccato."),
        backgroundColor: error != null ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "UTENTI BLOCCATI",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 2,
                color: premiumGold,
                fontFamily: 'Serif',
              ),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<List<SupabaseProfile>>(
              valueListenable: EcoraDataService.instance.blockedNotifier,
              builder: (context, blocked, _) {
                if (blocked.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      "Non hai bloccato nessun utente.",
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: blocked.map((p) {
                    return Card(
                      color: matteDark,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(p.fullName,
                            style: const TextStyle(color: textPrimary)),
                        trailing: TextButton(
                          onPressed: () => _unblock(context, p.id, p.fullName),
                          child: const Text("SBLOCCA",
                              style: TextStyle(color: premiumGold)),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
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
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: indicatorColor),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar disegnato: Luce con l'iniziale del nome (nessuna foto hardcoded).
class _InitialAvatar extends StatelessWidget {
  final String name;

  const _InitialAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '' : trimmed.substring(0, 1).toUpperCase();
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: LucePainter()),
        Center(
          child: Text(
            initial,
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(color: EcoraColors.ink),
          ),
        ),
      ],
    );
  }
}
