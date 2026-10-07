import 'package:flutter/material.dart';

import 'consent_text.dart';
import 'theme.dart';

// Termini accettati lato server (Blocco E.4b, migrazione 0020): la data la
// scrive il server con accept_terms, l'app chiede solo terms_to_accept.
// Testi approvati il 07/10/2026.

const String kTermsUpdateTitle = "Termini aggiornati";
const String kTermsUpdateBody =
    "Abbiamo aggiornato i Termini di Servizio. Per continuare a usare Ecora "
    "leggili e accettali. Se non li accetti puoi uscire o eliminare "
    "l'account.";
const String kTermsAcceptButton = "Accetta e continua";
const String kTermsDeleteAccountButton = "Elimina l'account";
const String kTermsCheckFailed =
    "Impossibile verificare i Termini. Controlla la connessione.";
const String kTermsChangedAgain =
    "I Termini sono stati aggiornati di nuovo. Rileggili e accetta.";
const String kTermsSaveFailed = "Salvataggio non riuscito. Riprova.";

enum TermsCheckState { checking, ok, mustAccept, failed }

/// Esito del controllo dei Termini per l'utente collegato.
class TermsCheck {
  final TermsCheckState state;

  /// Versione da accettare (solo con [TermsCheckState.mustAccept]).
  final String? version;

  const TermsCheck._(this.state, [this.version]);

  static const TermsCheck checking = TermsCheck._(TermsCheckState.checking);
  static const TermsCheck ok = TermsCheck._(TermsCheckState.ok);
  static const TermsCheck failed = TermsCheck._(TermsCheckState.failed);
  factory TermsCheck.mustAccept(String version) =>
      TermsCheck._(TermsCheckState.mustAccept, version);
}

/// Vero se il consenso dato in registrazione copre già [version]: l'utente
/// ha spuntato le caselle (segnale nei metadati auth) e si è iscritto
/// quando quella versione era già in vigore. La data di iscrizione è quella
/// del server (auth.users.created_at); la versione è la data dei Termini.
/// Serve al flusso con conferma email, dove il profilo nasce al primo
/// accesso. Pura.
bool signupConsentCovers({
  required Map<String, dynamic>? metadata,
  required String createdAt,
  required String version,
}) {
  final meta = metadata ?? const {};
  // terms_accepted_at: app prima di E.4b, che salvava il timestamp.
  final consented =
      meta['terms_consent'] == true || meta['terms_accepted_at'] != null;
  if (!consented) return false;
  final signup = DateTime.tryParse(createdAt);
  final effective = DateTime.tryParse(version);
  if (signup == null || effective == null) return false;
  return !signup.toUtc().isBefore(DateTime.utc(
      effective.year, effective.month, effective.day));
}

/// Messaggio per un accept_terms fallito, dal codice di Postgres. Pura.
String acceptTermsErrorMessage(String? code) =>
    code == '22023' ? kTermsChangedAgain : kTermsSaveFailed;

/// Casella di consenso con testo a destra; tutta la riga è toccabile.
class ConsentCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget child;

  const ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: EcoraSpace.s8),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged:
                    onChanged == null ? null : (v) => onChanged(v ?? false),
                activeColor: EcoraColors.brass,
                checkColor: EcoraColors.onBrass,
                side: const BorderSide(color: EcoraColors.lineControl),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: EcoraSpace.s12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Chiesta al primo accesso a chi non ha accettato la versione in vigore
/// dei Termini (tutti gli iscritti prima di E.4, e dopo ogni modifica
/// sostanziale: punto 13 dei Termini).
class TermsUpdateScreen extends StatefulWidget {
  /// Registra l'accettazione: null se riuscita, altrimenti il messaggio.
  final Future<String?> Function() onAccept;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  const TermsUpdateScreen({
    super.key,
    required this.onAccept,
    required this.onLogout,
    required this.onDeleteAccount,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  @override
  State<TermsUpdateScreen> createState() => _TermsUpdateScreenState();
}

class _TermsUpdateScreenState extends State<TermsUpdateScreen> {
  bool _age = false;
  bool _terms = false;
  bool _sensitive = false;
  bool _saving = false;
  String? _error;

  bool get _allChecked => _age && _terms && _sensitive;

  Future<void> _accept() async {
    if (_saving || !_allChecked) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onAccept();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final consentStyle =
        textTheme.bodyMedium?.copyWith(color: EcoraColors.inkMuted);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            EcoraSpace.s24,
            EcoraSpace.s40,
            EcoraSpace.s24,
            EcoraSpace.s24,
          ),
          children: [
            const Text("ECORA", style: EcoraTextStyles.wordmark),
            const SizedBox(height: EcoraSpace.s24),
            Text(kTermsUpdateTitle, style: textTheme.displayMedium),
            const SizedBox(height: EcoraSpace.s12),
            Text(
              kTermsUpdateBody,
              style: textTheme.bodyLarge?.copyWith(color: EcoraColors.inkMuted),
            ),
            const SizedBox(height: EcoraSpace.s24),
            ConsentCheckbox(
              value: _age,
              onChanged: _saving ? null : (v) => setState(() => _age = v),
              child: Text(kAgeConsentText, style: consentStyle),
            ),
            ConsentCheckbox(
              value: _terms,
              onChanged: _saving ? null : (v) => setState(() => _terms = v),
              child: ConsentText(
                onOpenTerms: widget.onOpenTerms,
                onOpenPrivacy: widget.onOpenPrivacy,
              ),
            ),
            ConsentCheckbox(
              value: _sensitive,
              onChanged: _saving ? null : (v) => setState(() => _sensitive = v),
              child: Text(kSensitiveConsentText, style: consentStyle),
            ),
            if (_error != null) ...[
              const SizedBox(height: EcoraSpace.s12),
              Text(
                _error!,
                style: textTheme.bodyMedium
                    ?.copyWith(color: EcoraColors.danger),
              ),
            ],
            const SizedBox(height: EcoraSpace.s24),
            ElevatedButton(
              onPressed: (_saving || !_allChecked) ? null : _accept,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: "Salvataggio in corso",
                      ),
                    )
                  : const Text(kTermsAcceptButton),
            ),
            const SizedBox(height: EcoraSpace.s8),
            TextButton(
              onPressed: _saving ? null : widget.onLogout,
              child: const Text("Esci"),
            ),
            TextButton(
              onPressed: _saving ? null : widget.onDeleteAccount,
              child: const Text(kTermsDeleteAccountButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// Il controllo dei Termini non è riuscito (rete): non si entra in
/// silenzio, si riprova o si esce.
class TermsCheckErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  const TermsCheckErrorScreen({
    super.key,
    required this.onRetry,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            EcoraSpace.s24,
            EcoraSpace.s40,
            EcoraSpace.s24,
            EcoraSpace.s24,
          ),
          children: [
            const Text("ECORA", style: EcoraTextStyles.wordmark),
            const SizedBox(height: EcoraSpace.s24),
            Text(
              kTermsCheckFailed,
              style: textTheme.bodyLarge?.copyWith(color: EcoraColors.inkMuted),
            ),
            const SizedBox(height: EcoraSpace.s24),
            ElevatedButton(onPressed: onRetry, child: const Text("Riprova")),
            const SizedBox(height: EcoraSpace.s8),
            TextButton(onPressed: onLogout, child: const Text("Esci")),
          ],
        ),
      ),
    );
  }
}

/// Mentre si controllano i Termini.
class TermsCheckingScreen extends StatelessWidget {
  const TermsCheckingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
