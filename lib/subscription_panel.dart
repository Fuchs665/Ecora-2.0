import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'italian_dates.dart';
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

/// Riga discreta della dashboard quando l'abbonamento è attivo (Blocco
/// C.1): "Abbonamento attivo fino al 12 novembre". Pura.
String subscriptionActiveLine(SubscriptionStatus status) {
  final expiry = status.expiryTime?.toLocal();
  if (expiry == null) return "Abbonamento attivo";
  return status.autoRenewing
      ? "Abbonamento attivo · si rinnova ${italianDayMonth(expiry)}"
      : "Abbonamento attivo fino ${italianDayMonth(expiry, afterA: true)}";
}

/// Pagina di Google Play dove il gestore rinnova o disdice il piano.
final Uri kManageSubscriptionUri = Uri.https(
  'play.google.com',
  '/store/account/subscriptions',
  {'sku': kSubscriptionProductId, 'package': 'com.ecora.app'},
);

Future<void> _openManageSubscription(BuildContext context) async {
  bool opened;
  try {
    opened = await launchUrl(
      kManageSubscriptionUri,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Impossibile aprire Google Play.")),
    );
  }
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

/// Abbonamento nella dashboard, declassato sotto la lista (Blocco C.1).
/// Attivo: una riga discreta con il link "Gestisci". Non attivo: la card
/// "ABBONAMENTO GESTORE" con acquisto e ripristino. In entrambi i casi il
/// feedback del flusso asincrono (purchaseStream) con dismiss manuale.
class SubscriptionStatusCard extends StatelessWidget {
  const SubscriptionStatusCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = EcoraSubscriptionService.instance;
    return ValueListenableBuilder<SubscriptionStatus?>(
      valueListenable: service.statusNotifier,
      builder: (context, status, _) {
        final now = DateTime.now();
        if (status != null && status.isActiveAt(now)) {
          return _ActiveSubscriptionLine(status: status);
        }
        return _InactiveSubscriptionCard(status: status, now: now);
      },
    );
  }
}

class _ActiveSubscriptionLine extends StatelessWidget {
  final SubscriptionStatus status;

  const _ActiveSubscriptionLine({required this.status});

  @override
  Widget build(BuildContext context) {
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              "${subscriptionActiveLine(status)} ·",
              style: bodySmall?.copyWith(color: EcoraColors.inkSubtle),
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: bodySmall?.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: EcoraColors.inkMuted,
                ),
              ),
              onPressed: () => _openManageSubscription(context),
              child: const Text("Gestisci"),
            ),
          ],
        ),
        const _PurchaseFeedback(),
      ],
    );
  }
}

class _InactiveSubscriptionCard extends StatelessWidget {
  final SubscriptionStatus? status;
  final DateTime now;

  const _InactiveSubscriptionCard({required this.status, required this.now});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoraSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: EcoraColors.inkMuted,
                  size: 24,
                ),
                const SizedBox(width: EcoraSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ABBONAMENTO GESTORE", style: textTheme.labelSmall),
                      const SizedBox(height: EcoraSpace.s4),
                      Text(
                        subscriptionStatusLabel(status, now),
                        style: textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: EcoraSpace.s12),
            Text(
              "Per pubblicare nuovi tavoli serve il piano mensile. "
              "Gli eventi già pubblicati restano attivi.",
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: EcoraSpace.s12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _startPurchase(context),
                    child: const Text("Abbonati"),
                  ),
                ),
                const SizedBox(width: EcoraSpace.s12),
                TextButton(
                  onPressed: () => _startRestore(context),
                  child: const Text("Ripristina"),
                ),
              ],
            ),
            const _PurchaseFeedback(),
          ],
        ),
      ),
    );
  }
}

/// Esito del flusso d'acquisto, chiudibile a mano.
class _PurchaseFeedback extends StatelessWidget {
  const _PurchaseFeedback();

  @override
  Widget build(BuildContext context) {
    final service = EcoraSubscriptionService.instance;
    return ValueListenableBuilder<String?>(
      valueListenable: service.feedbackNotifier,
      builder: (context, feedback, _) {
        if (feedback == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: EcoraSpace.s12),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: EcoraColors.brass, size: 16),
              const SizedBox(width: EcoraSpace.s8),
              Expanded(
                child: Text(
                  feedback,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: EcoraColors.ink),
                ),
              ),
              IconButton(
                tooltip: "Chiudi",
                icon: const Icon(Icons.close,
                    color: EcoraColors.inkMuted, size: 16),
                onPressed: () => service.feedbackNotifier.value = null,
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
