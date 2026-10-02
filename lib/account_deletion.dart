import 'package:flutter/material.dart';

import 'gestore_metrics.dart';
import 'models.dart';
import 'subscription_service.dart';
import 'theme.dart';

/// Pagina degli abbonamenti Google Play: eliminare l'account non annulla
/// l'abbonamento, che si disdice solo da lì.
const String kPlaySubscriptionsUrl =
    'https://play.google.com/store/account/subscriptions'
    '?sku=$kSubscriptionProductId&package=com.ecora.app';

// --- Testi (Blocco E.1b, approvati il 02/10/2026) ---------------------------
const String kDeleteAccountEntry = "Elimina account";
const String kDeleteAccountTitle = "Eliminare l'account?";
const String kDeleteAccountBody =
    "Cancelliamo profilo, foto della galleria, richieste, presenze, messaggi, "
    "blocchi e dispositivi registrati. Non si può annullare.";
const String kDeleteAccountPastEvents =
    "Le serate passate restano in forma anonima, senza il nome del locale, "
    "per non cancellare lo storico degli ospiti.";
const String kDeleteAccountSubscription =
    "L'abbonamento Google Play non si annulla eliminando l'account: "
    "disdicilo da Google Play, altrimenti continuerà a rinnovarsi.";
const String kOpenGooglePlay = "Apri Google Play";
const String kDeleteAccountPasswordLabel =
    "Password, per confermare che sei tu";
const String kDeleteAccountAcknowledge =
    "Ho capito che l'eliminazione è definitiva";
const String kDeleteAccountConfirm = "ELIMINA ACCOUNT";
const String kDeleteAccountCancel = "Annulla";
const String kDeleteAccountWrongPassword = "Password non corretta.";
const String kDeleteAccountRateLimited =
    "Troppi tentativi. Riprova tra qualche minuto.";
const String kDeleteAccountFailed =
    "Eliminazione non riuscita. Riprova; se il problema continua scrivi a "
    "furchia96@gmail.com.";
const String kDeleteAccountDone = "Account eliminato.";

/// Cosa mostrare nel foglio di conferma, oltre al testo comune. Pura.
class DeletionWarnings {
  final bool isGestore;

  /// Serate del gestore non ancora iniziate: verranno cancellate.
  final int upcomingEvents;

  /// Ospiti approvati a quelle serate.
  final int approvedGuests;

  /// Abbonamento Play attivo: va disdetto a parte.
  final bool activeSubscription;

  const DeletionWarnings({
    this.isGestore = false,
    this.upcomingEvents = 0,
    this.approvedGuests = 0,
    this.activeSubscription = false,
  });

  /// Per il cliente nessun avviso in più. Per il gestore conta le sue serate
  /// pubblicate non ancora iniziate ([events] è la lista di
  /// `get_events_with_stats()`, con le serate di tutti i locali). Le date
  /// illeggibili contano come future: meglio un avviso in più che uno in meno.
  factory DeletionWarnings.compute({
    required SupabaseProfile profile,
    required List<SupabaseEvent> events,
    required SubscriptionStatus? subscription,
    required DateTime now,
  }) {
    if (profile.role != 'gestore') return const DeletionWarnings();
    final upcoming = eventsHostedBy(events, profile.id).where((e) {
      final date = DateTime.tryParse(e.eventDate);
      return date == null || date.isAfter(now);
    }).toList();
    return DeletionWarnings(
      isGestore: true,
      upcomingEvents: upcoming.length,
      approvedGuests:
          upcoming.fold(0, (sum, e) => sum + e.currentApprovedCount),
      activeSubscription: subscription?.isActiveAt(now) ?? false,
    );
  }
}

/// "Le tue 3 serate in programma (5 ospiti approvati) verranno cancellate."
/// Vuota se non ce ne sono. Pura.
String upcomingEventsWarning(int events, int guests) {
  if (events <= 0) return '';
  final guestsPart = guests <= 0
      ? ''
      : guests == 1
          ? ' (1 ospite approvato)'
          : ' ($guests ospiti approvati)';
  return events == 1
      ? "La tua serata in programma$guestsPart verrà cancellata."
      : "Le tue $events serate in programma$guestsPart verranno cancellate.";
}

/// Il pulsante si accende solo con la password scritta e la casella
/// spuntata. Pura.
bool canConfirmDeletion(
        {required String password, required bool acknowledged}) =>
    acknowledged && password.isNotEmpty;

/// Risposta della Edge Function `delete-account` -> messaggio per l'utente,
/// null se l'account è stato eliminato. [status] null = rete giù. Pura.
String? deletionErrorMessage(int? status, Object? data) {
  if (status != null && status >= 200 && status < 300) return null;
  final code = data is Map ? data['error']?.toString() : null;
  if (code == 'wrong_password') return kDeleteAccountWrongPassword;
  if (status == 429 || code == 'rate_limited') return kDeleteAccountRateLimited;
  return kDeleteAccountFailed;
}

/// Foglio di conferma dell'eliminazione. [onDelete] chiede l'eliminazione al
/// server e torna null se è andata, altrimenti il messaggio da mostrare.
/// Solo dopo il successo il foglio si chiude e parte [onDeleted] (uscita
/// locale): con un errore resta aperto con il messaggio, e nulla cambia.
class DeleteAccountSheet extends StatefulWidget {
  final DeletionWarnings warnings;
  final Future<String?> Function(String password) onDelete;
  final VoidCallback onDeleted;
  final VoidCallback onOpenGooglePlay;

  const DeleteAccountSheet({
    super.key,
    required this.warnings,
    required this.onDelete,
    required this.onDeleted,
    required this.onOpenGooglePlay,
  });

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final _password = TextEditingController();
  bool _acknowledged = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onDelete(_password.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.warnings;
    final upcoming = upcomingEventsWarning(w.upcomingEvents, w.approvedGuests);
    final canConfirm = !_busy &&
        canConfirmDeletion(
            password: _password.text, acknowledged: _acknowledged);
    const body =
        TextStyle(fontSize: 13, color: EcoraColors.inkMuted, height: 1.4);

    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(kDeleteAccountTitle,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const Text(kDeleteAccountBody, style: body),
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(upcoming, style: body),
              ],
              if (w.isGestore) ...[
                const SizedBox(height: 10),
                const Text(kDeleteAccountPastEvents, style: body),
              ],
              if (w.activeSubscription) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: EcoraColors.warning),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(kDeleteAccountSubscription,
                          style: TextStyle(
                              fontSize: 13,
                              color: EcoraColors.ink,
                              height: 1.4)),
                      TextButton(
                        onPressed: widget.onOpenGooglePlay,
                        child: const Text(kOpenGooglePlay),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                    labelText: kDeleteAccountPasswordLabel),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _acknowledged,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _acknowledged = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(kDeleteAccountAcknowledge,
                    style: TextStyle(fontSize: 13, color: EcoraColors.ink)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        fontSize: 13, color: EcoraColors.danger)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: EcoraColors.danger,
                  foregroundColor: EcoraColors.onBrass,
                ),
                onPressed: canConfirm ? _confirm : null,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(kDeleteAccountConfirm),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text(kDeleteAccountCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
