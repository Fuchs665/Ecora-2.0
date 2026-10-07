import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'birth_year.dart';
import 'client_navigation_hub.dart';
import 'consent_text.dart';
import 'account_deletion.dart';
import 'gestore_dashboard.dart';
import 'terms_update.dart';
import 'theme.dart';
export 'theme.dart';

import 'models.dart';
import 'data_service.dart';
import 'push_service.dart';
import 'subscription_service.dart';
export 'models.dart';
export 'data_service.dart';

// Privacy policy e Termini ospitati su GitHub Pages (cartella /docs del repo).
const String kPrivacyPolicyUrl =
    'https://fuchs665.github.io/Ecora-2.0/privacy.html';
const String kTermsUrl = 'https://fuchs665.github.io/Ecora-2.0/terms.html';

/// Il profilo non è stato creato (audit A2): testo approvato il 07/10/2026.
const String kRegistrationIncomplete =
    "Registrazione non completata. Riprova ad accedere tra poco.";

/// Messaggi che devono sopravvivere al cambio di schermata (es. "Account
/// eliminato", mostrato sopra la schermata di accesso).
final GlobalKey<ScaffoldMessengerState> ecoraMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// --- FLUTTER APPLICATION BARRIER ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: 'https://fswzykzclfrpzlufjhfg.supabase.co',
      anonKey: 'sb_publishable_qv2R89l53F8gK_cJ6rS66Q_7TLWe_-B',
    );
    await EcoraDataService.instance.restoreSession();
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
    EcoraDataService.instance.currentProfileNotifier
        .addListener(_profileListener);
    // Push: rimozione token al logout + registrazione se la sessione
    // era gia' stata ripristinata prima di runApp. Al logout si azzera
    // anche lo stato abbonamento locale (la riga DB resta, e' dell'account).
    EcoraDataService.instance.beforeLogout = () async {
      await EcoraPushService.instance.unregisterDevice();
      EcoraSubscriptionService.instance.reset();
    };
    if (EcoraDataService.instance.currentProfileNotifier.value != null) {
      EcoraPushService.instance.registerDevice();
      _initSubscriptionsIfGestore();
      EcoraDataService.instance.checkTerms();
    }
  }

  // Solo i gestori acquistano: il listener del purchaseStream va agganciato
  // al loro login/ripristino, cosi' Google puo' riconsegnare gli acquisti
  // rimasti in sospeso (verifica fallita per rete, app chiusa a meta', ...).
  void _initSubscriptionsIfGestore() {
    final profile = EcoraDataService.instance.currentProfileNotifier.value;
    if (profile?.role == 'gestore') {
      EcoraSubscriptionService.instance.init();
    }
  }

  @override
  void dispose() {
    EcoraDataService.instance.currentProfileNotifier
        .removeListener(_profileListener);
    super.dispose();
  }

  void _profileListener() {
    // Return to login screen automatically if logged out
    if (EcoraDataService.instance.currentProfileNotifier.value == null) {
      if (mounted) setState(() {});
    } else {
      // Login (o registrazione) completati: registra il device per le push
      // e, per i gestori, aggancia il flusso abbonamento.
      EcoraPushService.instance.registerDevice();
      _initSubscriptionsIfGestore();
      // Termini: una volta per accesso (il notifier del profilo cambia
      // anche per le modifiche al profilo).
      if (EcoraDataService.instance.termsCheckNotifier.value.state ==
          TermsCheckState.checking) {
        EcoraDataService.instance.checkTerms();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecora',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: ecoraMessengerKey,
      theme: ecoraTheme(),
      home: BiometricGate(
        child: ValueListenableBuilder<SupabaseProfile?>(
          valueListenable: EcoraDataService.instance.currentProfileNotifier,
          builder: (context, profile, _) {
            if (profile == null) {
              return const AuthScreen();
            }
            return ValueListenableBuilder<TermsCheck>(
              valueListenable: EcoraDataService.instance.termsCheckNotifier,
              builder: (context, terms, _) =>
                  _homeFor(context, profile, terms),
            );
          },
        ),
      ),
    );
  }

  Widget _homeFor(
      BuildContext context, SupabaseProfile profile, TermsCheck terms) {
    switch (terms.state) {
      case TermsCheckState.checking:
        return const TermsCheckingScreen();
      case TermsCheckState.failed:
        return TermsCheckErrorScreen(
          onRetry: EcoraDataService.instance.checkTerms,
          onLogout: EcoraDataService.instance.logout,
        );
      case TermsCheckState.mustAccept:
        return TermsUpdateScreen(
          onAccept: EcoraDataService.instance.acceptTerms,
          onLogout: EcoraDataService.instance.logout,
          onDeleteAccount: () => _showDeleteAccountSheet(context, profile),
          onOpenTerms: () => _openLegalPage(context, kTermsUrl,
              "Impossibile aprire i Termini di Servizio."),
          onOpenPrivacy: () => _openLegalPage(context, kPrivacyPolicyUrl,
              "Impossibile aprire la Privacy Policy."),
        );
      case TermsCheckState.ok:
        break;
    }
    if (profile.role != 'gestore' && profile.birthYear == null) {
      // Iscritti prima di B.2b: l'anno si chiede una volta sola.
      return BirthYearScreen(
        onSave: EcoraDataService.instance.saveBirthYear,
        onLogout: EcoraDataService.instance.logout,
      );
    } else if (profile.role == 'gestore') {
      return const GestoreDashboard();
    }
    // Default sicuro: qualunque ruolo non-gestore -> area cliente.
    return const ClientNavigationHub();
  }

  Future<void> _openLegalPage(
      BuildContext context, String url, String failureMessage) async {
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      ecoraMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  /// "Elimina l'account" dalla schermata dei Termini (punto 13: chi non li
  /// accetta può eliminare l'account). Stesso foglio del profilo; per il
  /// gestore prima si caricano le serate, per gli avvisi del foglio.
  Future<void> _showDeleteAccountSheet(
      BuildContext context, SupabaseProfile profile) async {
    if (profile.role == 'gestore') {
      await EcoraDataService.instance.fetchEvents();
      await EcoraSubscriptionService.instance.refreshStatus();
    }
    if (!context.mounted) return;
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
                    style: ecoraPrimaryButtonStyle(),
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
  String? _infoMessage;

  // Login Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;

  // Registration Controllers
  final TextEditingController _regNicknameController = TextEditingController();
  final TextEditingController _regLocationController = TextEditingController();
  final TextEditingController _regBirthYearController = TextEditingController();
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

  // Consenso obbligatorio alla registrazione (Fase 3 — Trust & Safety).
  bool _ageConfirmed = false;
  bool _termsAccepted = false;
  bool _sensitiveConsent = false;

  // Link del testo di consenso (Termini e Privacy): pagina nel browser.
  Future<void> _openLegalPage(String url, String failureMessage) async {
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      if (mounted) setState(() => _errorMessage = failureMessage);
    }
  }

  Widget _buildConsentCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required Widget child,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: premiumGold,
                checkColor: matteDark,
                side: const BorderSide(color: textSecondary),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  String _parseSupabaseError(dynamic error) {
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('invalid login credentials') ||
        errStr.contains('invalid_credentials')) {
      return "Credenziali non valide.";
    } else if (errStr.contains('email not confirmed')) {
      return "Email non ancora confermata. Controlla la tua casella di posta.";
    } else if (errStr.contains('already registered') ||
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
      _infoMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = "Credenziali non valide.";
        });
        return;
      }

      Map<String, dynamic>? profileData = await Supabase.instance.client
          .from('profiles')
          .select(kProfileSelectColumns)
          .eq('id', user.id)
          .maybeSingle();

      // Ripara gli account creati prima della policy di INSERT sui profili:
      // se manca la riga profilo, la creiamo ora con valori minimi.
      // Upsert con ignoreDuplicates evita il conflitto se la riga esiste
      // ma non era leggibile per un problema transitorio.
      if (profileData == null) {
        final fallbackNickname = email.split('@').first;
        // Flusso con conferma email: la riga profilo nasce al primo login.
        // I consensi non passano da qui: li scrive il server con
        // accept_terms (EcoraDataService.checkTerms, migrazione 0020).
        final meta = user.userMetadata ?? {};
        await Supabase.instance.client.from('profiles').upsert(
          {
            'id': user.id,
            'nickname': fallbackNickname,
            'role': 'cliente',
            'birth_year': meta['birth_year'],
          },
          onConflict: 'id',
          ignoreDuplicates: true,
        );
        profileData = await Supabase.instance.client
            .from('profiles')
            .select(kProfileSelectColumns)
            .eq('id', user.id)
            .maybeSingle();
        if (profileData == null) {
          // Audit A2: mai entrare con un profilo che esiste solo in memoria.
          await Supabase.instance.client.auth
              .signOut(scope: SignOutScope.local);
          if (!mounted) return;
          setState(() => _errorMessage = kRegistrationIncomplete);
          return;
        }
      }

      final prof =
          SupabaseProfile.fromRow(Map<String, dynamic>.from(profileData));
      EcoraDataService.instance.addProfile(prof);
      EcoraDataService.instance.currentProfileNotifier.value = prof;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _parseSupabaseError(e);
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

    final birthYearProblem =
        birthYearError(_regBirthYearController.text, DateTime.now());
    if (birthYearProblem != null) {
      setState(() {
        _errorMessage = birthYearProblem;
      });
      return;
    }
    final int birthYear = int.parse(_regBirthYearController.text.trim());

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

    if (!_ageConfirmed) {
      setState(() {
        _errorMessage = "Devi confermare di avere almeno 18 anni per registrarti.";
      });
      return;
    }

    if (!_termsAccepted) {
      setState(() {
        _errorMessage =
            "Devi accettare i Termini di Servizio e l'Informativa sulla Privacy.";
      });
      return;
    }

    // Il pulsante resta spento finché manca: qui solo per sicurezza.
    if (!_sensitiveConsent) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      // 1. Registrazione reale su Supabase Auth
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        // terms_consent: le caselle sono state spuntate. Data e versione
        // dei Termini le scrive il server con accept_terms, al primo
        // controllo dopo l'accesso (EcoraDataService.checkTerms).
        data: {
          'terms_consent': true,
          'birth_year': birthYear,
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception("Impossibile creare l'utente.");
      }

      // Con la conferma email attiva non esiste ancora una sessione:
      // la riga profilo verrà creata al primo login (percorso di riparazione).
      if (response.session == null) {
        if (!mounted) return;
        setState(() {
          _isLogin = true;
          _errorMessage = null;
          _infoMessage =
              "Registrazione riuscita! Controlla la tua email per confermare l'account, poi accedi.";
        });
        return;
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
          'birth_year': birthYear,
        });
      } catch (dbErr) {
        // Audit A2: senza riga profilo non si entra. Al prossimo accesso
        // il percorso di riparazione del login la crea.
        debugPrint("Errore nell'inserimento del profilo reale: $dbErr");
        await Supabase.instance.client.auth
            .signOut(scope: SignOutScope.local);
        if (!mounted) return;
        setState(() {
          _isLogin = true;
          _errorMessage = kRegistrationIncomplete;
        });
        return;
      }

      // 3. Registrazione nello stato locale (in-memory simulator)
      final newLocalProfile = SupabaseProfile(
        id: userId,
        fullName: nickname,
        role: 'cliente',
        birthYear: birthYear,
        gender: profileType.contains('Coppia') ? 'Coppia' : (profileType.contains('Donna') ? 'Donna' : 'Uomo'),
        noShows: 0,
        participationsCount: 0,
        profileType: profileType,
        privacyLevel: privacyLevel,
      );

      EcoraDataService.instance.addProfile(newLocalProfile);
      EcoraDataService.instance.currentProfileNotifier.value = newLocalProfile;

    } catch (e) {
      debugPrint("Errore completo durante la registrazione: $e");
      setState(() {
        _errorMessage = _parseSupabaseError(e);
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
                        premiumGold.withValues(alpha: 0.18),
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
                // --- LOGIN EMAIL ---
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: ecoraInputDecoration(
                    "Email",
                    prefixIcon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 16),

                // --- LOGIN PASSWORD ---
                TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: ecoraInputDecoration(
                    "Password",
                    prefixIcon: Icons.lock_outline,
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
                  ),
                ),
                const SizedBox(height: 24),

                // --- LOGIN BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ecoraPrimaryButtonStyle(),
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
                    style: ecoraSecondaryButtonStyle(),
                    onPressed: () {
                      setState(() {
                        _isLogin = false;
                        _errorMessage = null;
                        _infoMessage = null;
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
                  decoration: ecoraInputDecoration(
                    "Nickname (es. Alex & Sofia)",
                    prefixIcon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 16),

                // Tipologia di Profilo Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedProfileType,
                  hint: const Text(
                    "Seleziona la tipologia...",
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  dropdownColor: slateSurface,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  icon: const Icon(Icons.arrow_drop_down, color: premiumGold),
                  decoration: ecoraInputDecoration(
                    "Tipologia di Profilo",
                    prefixIcon: Icons.people_outline,
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
                  initialValue: _selectedPrivacyLevel,
                  hint: const Text(
                    "Seleziona livello di privacy...",
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  dropdownColor: slateSurface,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  icon: const Icon(Icons.arrow_drop_down, color: premiumGold),
                  decoration: ecoraInputDecoration(
                    "Livello di Privacy",
                    prefixIcon: Icons.security_outlined,
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
                  decoration: ecoraInputDecoration(
                    "Località Generica (es. Firenze Nord)",
                    prefixIcon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(height: 16),

                // Anno di nascita (Blocco B.2b): obbligatorio, 18+.
                TextField(
                  controller: _regBirthYearController,
                  keyboardType: TextInputType.number,
                  inputFormatters: kBirthYearInputFormatters,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: ecoraInputDecoration(
                    kBirthYearLabel,
                    prefixIcon: Icons.cake_outlined,
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Email
                TextField(
                  controller: _regEmailController,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: ecoraInputDecoration(
                    "Email",
                    prefixIcon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Password
                TextField(
                  controller: _regPasswordController,
                  obscureText: !_regPasswordVisible,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: ecoraInputDecoration(
                    "Password (almeno 6 caratteri)",
                    prefixIcon: Icons.lock_outline,
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
                  ),
                ),
                const SizedBox(height: 16),

                // --- CONSENSO OBBLIGATORIO (Fase 3 — Trust & Safety) ---
                _buildConsentCheckbox(
                  value: _ageConfirmed,
                  onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
                  child: const Text(
                    kAgeConsentText,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
                _buildConsentCheckbox(
                  value: _termsAccepted,
                  onChanged: (v) =>
                      setState(() => _termsAccepted = v ?? false),
                  child: ConsentText(
                    onOpenTerms: () => _openLegalPage(
                        kTermsUrl, "Impossibile aprire i Termini di Servizio."),
                    onOpenPrivacy: () => _openLegalPage(kPrivacyPolicyUrl,
                        "Impossibile aprire la Privacy Policy."),
                  ),
                ),
                _buildConsentCheckbox(
                  value: _sensitiveConsent,
                  onChanged: (v) =>
                      setState(() => _sensitiveConsent = v ?? false),
                  child: const Text(
                    kSensitiveConsentText,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),

                // --- REGISTER BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ecoraPrimaryButtonStyle(),
                    onPressed: (_isLoading ||
                            !_ageConfirmed ||
                            !_termsAccepted ||
                            !_sensitiveConsent)
                        ? null
                        : _handleRegister,
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
                    style: ecoraSecondaryButtonStyle(),
                    onPressed: () {
                      setState(() {
                        _isLogin = true;
                        _errorMessage = null;
                        _infoMessage = null;
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
                        _infoMessage = null;
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

              // --- PANNELLO ERRORE / SUCCESSO ---
              if (_errorMessage != null)
                _AuthMessagePanel(
                  message: _errorMessage!,
                  icon: Icons.error_outline,
                  color: Colors.redAccent,
                  backgroundColor: Colors.red,
                )
              else if (_infoMessage != null)
                _AuthMessagePanel(
                  message: _infoMessage!,
                  icon: Icons.check_circle_outline,
                  color: premiumGold,
                  backgroundColor: premiumGold,
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
                        _isLogin
                            ? "La connessione con Ecora è cifrata. Gli altri iscritti vedono solo il nickname, la zona e le foto che scegli di caricare."
                            : "Iscrivendoti accetti la verifica dei gestori: ogni richiesta di partecipazione viene valutata prima di essere approvata.",
                        style: TextStyle(
                          color: textSecondary.withValues(alpha: 0.8),
                          fontSize: 12,
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

/// Pannello di feedback per AuthScreen: stessa struttura per errore
/// (rosso) e successo (oro), solo colore/icona cambiano.
class _AuthMessagePanel extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _AuthMessagePanel({
    required this.message,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: backgroundColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
