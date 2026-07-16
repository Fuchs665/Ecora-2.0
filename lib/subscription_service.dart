import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Product id dell'unico piano v1 (mensile, per i gestori). Deve combaciare
/// con Play Console e con PRODUCT_ID nella Edge Function verify-subscription.
const String kSubscriptionProductId = 'ecora_gestore_monthly';

/// Stato abbonamento del gestore corrente, letto dalla PROPRIA riga di
/// `subscriptions` (RLS own-row; le scritture passano solo dalla Edge
/// Function). Pura, testabile.
class SubscriptionStatus {
  final String productId;
  final DateTime? expiryTime;
  final bool autoRenewing;
  final DateTime? lastVerifiedAt;

  const SubscriptionStatus({
    required this.productId,
    required this.expiryTime,
    required this.autoRenewing,
    required this.lastVerifiedAt,
  });

  factory SubscriptionStatus.fromRow(Map<String, dynamic> row) {
    return SubscriptionStatus(
      productId: row['product_id']?.toString() ?? kSubscriptionProductId,
      expiryTime: DateTime.tryParse(row['expiry_time']?.toString() ?? ''),
      autoRenewing: row['auto_renewing'] == true,
      lastVerifiedAt:
          DateTime.tryParse(row['last_verified_at']?.toString() ?? ''),
    );
  }

  /// Attivo se l'expiry e' nel futuro. Il confronto tra DateTime utc/local
  /// e' sicuro (Dart confronta gli istanti, non il fuso).
  bool isActiveAt(DateTime now) =>
      expiryTime != null && expiryTime!.isAfter(now);

  bool get isActive => isActiveAt(DateTime.now());
}

/// Un PurchaseDetails va verificato lato server solo se riguarda il nostro
/// abbonamento ed e' in uno stato "consegnato" (purchased/restored).
/// Pura, testabile.
bool shouldVerifyPurchase(String productId, PurchaseStatus status) {
  return productId == kSubscriptionProductId &&
      (status == PurchaseStatus.purchased ||
          status == PurchaseStatus.restored);
}

/// Flusso d'acquisto abbonamento gestore via Google Play Billing.
/// Fail-soft come EcoraPushService: su web (o store non disponibile) l'app
/// funziona normalmente, solo senza acquisti. La fonte di verita' del gate
/// resta il DB (RLS has_active_subscription, migrazione 0013): qui si
/// avvia l'acquisto, si passa il token alla Edge Function e si legge lo
/// stato risultante.
class EcoraSubscriptionService {
  static final EcoraSubscriptionService instance =
      EcoraSubscriptionService._internal();
  EcoraSubscriptionService._internal();

  /// Stato corrente (null = nessuna riga: mai abbonato o non gestore).
  final ValueNotifier<SubscriptionStatus?> statusNotifier =
      ValueNotifier(null);

  /// Messaggi user-facing prodotti dal flusso asincrono di acquisto
  /// (il purchaseStream arriva fuori da qualsiasi contesto UI). La UI
  /// del Block 5.4 li mostra e li azzera.
  final ValueNotifier<String?> feedbackNotifier = ValueNotifier(null);

  bool _listening = false;
  StreamSubscription<List<PurchaseDetails>>? _purchasesSubscription;

  /// Da chiamare quando un GESTORE e' autenticato. Idempotente. Aggancia
  /// subito il purchaseStream: Google ripresenta qui anche gli acquisti
  /// rimasti in sospeso (es. verifica fallita per rete all'avvio scorso).
  Future<void> init() async {
    if (kIsWeb) return;
    if (!_listening) {
      try {
        _purchasesSubscription = InAppPurchase.instance.purchaseStream.listen(
          _onPurchaseUpdates,
          onError: (Object e) => debugPrint("Errore stream acquisti: $e"),
        );
        _listening = true;
      } catch (e) {
        debugPrint("In-app purchase non disponibile: $e");
      }
    }
    await refreshStatus();
  }

  /// Rilegge la propria riga di `subscriptions` (via RLS). La tabella
  /// concede SELECT completo ad authenticated, quindi select() va bene.
  Future<void> refreshStatus() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final row = await Supabase.instance.client
          .from('subscriptions')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      statusNotifier.value = row == null
          ? null
          : SubscriptionStatus.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint("Errore lettura stato abbonamento: $e");
    }
  }

  /// Avvia il flusso d'acquisto Google Play. Ritorna null se il foglio
  /// d'acquisto e' partito (l'esito vero arriva su purchaseStream),
  /// altrimenti un messaggio d'errore da mostrare.
  Future<String?> buySubscription() async {
    if (kIsWeb) {
      return "Gli abbonamenti si acquistano dall'app Android.";
    }
    try {
      await init();
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) {
        return "Google Play non disponibile su questo dispositivo.";
      }
      final response =
          await iap.queryProductDetails({kSubscriptionProductId});
      if (response.productDetails.isEmpty) {
        return "Abbonamento non ancora disponibile sullo store.";
      }
      final started = await iap.buyNonConsumable(
        purchaseParam:
            PurchaseParam(productDetails: response.productDetails.first),
      );
      if (!started) return "Impossibile avviare l'acquisto. Riprova.";
      return null;
    } catch (e) {
      debugPrint("Errore avvio acquisto: $e");
      return "Acquisto non disponibile al momento. Riprova.";
    }
  }

  /// Ripristino acquisti (cambio device / reinstallazione): gli acquisti
  /// ritrovati arrivano su purchaseStream come `restored` e ripassano
  /// dalla verifica server.
  Future<String?> restorePurchases() async {
    if (kIsWeb) {
      return "Disponibile solo dall'app Android.";
    }
    try {
      await init();
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) {
        return "Google Play non disponibile su questo dispositivo.";
      }
      await iap.restorePurchases();
      return null;
    } catch (e) {
      debugPrint("Errore ripristino acquisti: $e");
      return "Ripristino non riuscito. Riprova.";
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (shouldVerifyPurchase(purchase.productID, purchase.status)) {
        await _verifyAndDeliver(purchase);
      } else if (purchase.status == PurchaseStatus.pending) {
        feedbackNotifier.value = "Pagamento in corso...";
      } else if (purchase.status == PurchaseStatus.error) {
        feedbackNotifier.value = "Acquisto non riuscito. Riprova.";
      }
    }
  }

  /// Verifica server-side del purchase token, poi ack a Google.
  /// Regola: 2xx -> stato aggiornato e completePurchase; 4xx -> solo
  /// completePurchase (token invalido/replay: ripresentarlo non aiuta);
  /// rete giu' o 5xx -> NIENTE completePurchase, cosi' Google lo
  /// ripresenta al prossimo avvio e la verifica viene ritentata.
  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    int code;
    dynamic data;
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'verify-subscription',
        body: {
          'purchase_token': purchase.verificationData.serverVerificationData,
        },
      );
      code = res.status ?? 0;
      data = res.data;
    } catch (e) {
      debugPrint("verify-subscription non raggiungibile: $e");
      code = 0;
    }

    if (code >= 200 && code < 300) {
      await refreshStatus();
      feedbackNotifier.value = "Abbonamento attivo. Buon lavoro.";
    } else if (code >= 400 && code < 500) {
      feedbackNotifier.value = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : "Verifica dell'acquisto rifiutata.";
    } else {
      feedbackNotifier.value =
          "Acquisto registrato, verifica in sospeso: riapri l'app tra poco.";
      return;
    }

    if (purchase.pendingCompletePurchase) {
      try {
        await InAppPurchase.instance.completePurchase(purchase);
      } catch (e) {
        debugPrint("Errore completePurchase: $e");
      }
    }
  }

  /// Best effort al logout: stato locale azzerato (la riga DB resta,
  /// e' legata all'account, non al device).
  void reset() {
    statusNotifier.value = null;
    feedbackNotifier.value = null;
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _purchasesSubscription?.cancel();
    _purchasesSubscription = null;
    _listening = false;
  }
}
