import 'package:flutter/material.dart';
import 'subscription_service.dart';
import 'theme.dart';

// UI dello stato abbonamento gestore (Block 5.4). Difesa in profondita':
// il blocco vero sulla creazione eventi e' la RLS (migrazione 0013),
// questi widget la anticipano con una UX chiara invece di un errore DB.

/// "16/08/2026" dall'expiry (in ora locale); em dash se assente. Pura.
String formatExpiryDate(DateTime? expiry) {
  if (expiry == null) return '—';
  final local = expiry.toLocal();
  return "${local.day.toString().padLeft(2, '0')}/"
      "${local.month.toString().padLeft(2, '0')}/${local.year}";
}

/// Riga di stato user-facing per la card e il foglio del gate. Pura.
String subscriptionStatusLabel(SubscriptionStatus? status, DateTime now) {
  if (status == null || !status.isActiveAt(now)) {
    return "Nessun abbonamento attivo";
  }
  final date = formatExpiryDate(status.expiryTime);
  return status.autoRenewing
      ? "Attivo • si rinnova il $date"
      : "Attivo fino al $date";
}

Future<void> _startPurchase(BuildContext context) async {
  final error = await EcoraSubscriptionService.instance.buySubscription();
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error)));
  }
}

Future<void> _startRestore(BuildContext context) async {
  final error = await EcoraSubscriptionService.instance.restorePurchases();
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error)));
  }
}

/// Card "ABBONAMENTO GESTORE" per la dashboard: stato corrente, CTA di
/// acquisto/ripristino quando serve, feedback del flusso asincrono
/// (purchaseStream) con dismiss manuale.
class SubscriptionStatusCard extends StatelessWidget {
  const SubscriptionStatusCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = EcoraSubscriptionService.instance;
    return ValueListenableBuilder<SubscriptionStatus?>(
      valueListenable: service.statusNotifier,
      builder: (context, status, _) {
        final active = status?.isActiveAt(DateTime.now()) ?? false;
        return Container(
          decoration: ecoraCardDecoration(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    active ? Icons.workspace_premium : Icons.lock_outline,
                    color: active ? premiumGold : textSecondary,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ABBONAMENTO GESTORE",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: premiumGold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subscriptionStatusLabel(status, DateTime.now()),
                          style: TextStyle(
                            fontSize: 13,
                            color: active ? textPrimary : textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!active) ...[
                const SizedBox(height: 12),
                const Text(
                  "Per pubblicare nuovi tavoli serve il piano mensile. "
                  "Gli eventi già pubblicati restano attivi.",
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ecoraPrimaryButtonStyle(),
                        onPressed: () => _startPurchase(context),
                        child: const Text("Abbonati"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => _startRestore(context),
                      child: const Text(
                        "Ripristina",
                        style: TextStyle(color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
              ValueListenableBuilder<String?>(
                valueListenable: service.feedbackNotifier,
                builder: (context, feedback, _) {
                  if (feedback == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: premiumGold, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feedback,
                            style: const TextStyle(
                                fontSize: 12, color: textPrimary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: textSecondary, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              service.feedbackNotifier.value = null,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Foglio mostrato quando un gestore senza abbonamento attivo prova a
/// creare un evento. La RLS bloccherebbe comunque l'INSERT: qui si spiega
/// il perche' e si offre subito l'acquisto.
Future<void> showSubscriptionRequiredSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: slateSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.workspace_premium, color: premiumGold, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "SERVE L'ABBONAMENTO GESTORE",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: premiumGold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "La pubblicazione di nuovi tavoli è riservata ai gestori "
                "con piano mensile attivo. Gli eventi già pubblicati, le "
                "chat e le richieste restano attivi anche senza rinnovo.",
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ecoraPrimaryButtonStyle(),
                  onPressed: () {
                    // Chiudi il foglio: sopra si apre quello di Google Play.
                    Navigator.of(sheetContext).pop();
                    _startPurchase(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text("Attiva l'abbonamento"),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _startRestore(context);
                  },
                  child: const Text(
                    "Ho già un abbonamento: ripristina",
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
