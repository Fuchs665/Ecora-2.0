import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'theme.dart';

// Sblocco biometrico all'avvio e di nuovo al ritorno dal background
// (Blocco E.4d, audit A5). Il gate avvolge il Navigator (MaterialApp.builder):
// il pannello di blocco copre anche le pagine aperte sopra la home.

/// Dopo quanto tempo in background si richiede lo sblocco (deciso il
/// 07/10/2026).
const Duration kRelockAfter = Duration(seconds: 30);

/// Vero se, tornando in primo piano a [now] dopo essere andati in
/// background a [pausedAt], va richiesto lo sblocco. Pura.
bool shouldRelock({
  required DateTime? pausedAt,
  required DateTime now,
  Duration after = kRelockAfter,
}) =>
    pausedAt != null && now.difference(pausedAt) >= after;

/// Il sensore, separato per poterlo sostituire nei test.
abstract class EcoraAuthenticator {
  /// Vero se il dispositivo ha una biometria registrata.
  Future<bool> isAvailable();

  /// Mostra la richiesta di sblocco. Vero se riuscito.
  Future<bool> authenticate();
}

class LocalAuthAuthenticator implements EcoraAuthenticator {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    if (!canCheck && !await _auth.isDeviceSupported()) return false;
    final enrolled = await _auth.getAvailableBiometrics();
    return enrolled.isNotEmpty;
  }

  @override
  Future<bool> authenticate() => _auth.authenticate(
        localizedReason: 'Autenticati per accedere al tuo profilo riservato',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
}

enum _GateState { checking, unlocked, failed }

class BiometricGate extends StatefulWidget {
  final Widget child;
  final EcoraAuthenticator? authenticator;

  /// Orologio, sostituibile nei test.
  final DateTime Function() clock;

  const BiometricGate({
    Key? key,
    required this.child,
    this.authenticator,
    this.clock = DateTime.now,
  }) : super(key: key);

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate>
    with WidgetsBindingObserver {
  late final EcoraAuthenticator _auth =
      widget.authenticator ?? LocalAuthAuthenticator();
  _GateState _state = _GateState.checking;

  /// Biometria presente: senza, il gate non blocca mai (come prima).
  bool _available = false;

  /// La richiesta di sblocco è aperta: il dialogo di sistema stesso fa
  /// cambiare lo stato dell'app, e quei cambi vanno ignorati.
  bool _authenticating = false;

  /// L'app è stata sbloccata almeno una volta: da lì in poi il contenuto
  /// resta montato sotto il pannello (non si perde la navigazione).
  bool _everUnlocked = false;

  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometrics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_available || _authenticating) return;
    if (state == AppLifecycleState.paused) {
      if (_state == _GateState.unlocked) _pausedAt = widget.clock();
    } else if (state == AppLifecycleState.resumed) {
      final relock =
          shouldRelock(pausedAt: _pausedAt, now: widget.clock());
      _pausedAt = null;
      if (relock && _state == _GateState.unlocked) {
        // Niente tastiera aperta sopra il pannello di blocco.
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _state = _GateState.checking);
        _authenticate();
      }
    }
  }

  void _unlock() {
    _everUnlocked = true;
    _state = _GateState.unlocked;
  }

  Future<void> _checkBiometrics() async {
    try {
      _available = await _auth.isAvailable();
    } catch (e) {
      debugPrint("Errore verifica biometria: $e");
      _available = false; // Safe fallback bypass on exception
    }
    if (!mounted) return;
    if (!_available) {
      // Bypass if biometrics not supported or not enrolled
      setState(_unlock);
      return;
    }
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;
    bool authenticated = false;
    try {
      authenticated = await _auth.authenticate();
    } catch (e) {
      debugPrint("Errore autenticazione biometrica: $e");
    }
    _authenticating = false;
    if (!mounted) return;
    setState(() {
      if (authenticated) {
        _unlock();
      } else {
        _state = _GateState.failed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = _state != _GateState.unlocked;
    if (!_everUnlocked) return _lockScreen();
    return Stack(
      children: [
        ExcludeSemantics(
          excluding: locked,
          child: IgnorePointer(
            ignoring: locked,
            child: TickerMode(enabled: !locked, child: widget.child),
          ),
        ),
        if (locked) Positioned.fill(child: _lockScreen()),
      ],
    );
  }

  Widget _lockScreen() {
    if (_state != _GateState.failed) {
      return const Scaffold(
        backgroundColor: matteDark,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(premiumGold),
          ),
        ),
      );
    }

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
}
