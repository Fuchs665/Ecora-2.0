import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data_service.dart';

/// Riga da upsert-are in `device_tokens` (pura, testabile).
Map<String, dynamic> deviceTokenRow(
    String userId, String token, String platform) {
  return {
    'user_id': userId,
    'token': token,
    'platform': platform,
  };
}

/// Registra il device per le push FCM e tiene allineato il token in
/// `device_tokens`. Tutto fail-soft: senza google-services.json (o su web,
/// dove il setup VAPID non e' configurato in v1) l'app funziona
/// normalmente, solo senza push.
class EcoraPushService {
  static final EcoraPushService instance = EcoraPushService._internal();
  EcoraPushService._internal();

  bool _firebaseReady = false;
  String? _currentToken;
  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  /// Da chiamare quando un utente e' autenticato. Idempotente.
  Future<void> registerDevice() async {
    if (kIsWeb) return;
    try {
      if (!_firebaseReady) {
        // Su Android la configurazione arriva da google-services.json.
        await Firebase.initializeApp();
        _firebaseReady = true;
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }
      _refreshSubscription ??=
          messaging.onTokenRefresh.listen(_saveToken, onError: (e) {
        debugPrint("Errore refresh token FCM: $e");
      });

      // Push ricevuta ad app aperta: niente banner di sistema, si
      // riallineano subito richieste e notifiche in-app.
      _foregroundSubscription ??=
          FirebaseMessaging.onMessage.listen((message) {
        EcoraDataService.instance.fetchMyNotifications();
        EcoraDataService.instance.fetchMyRequests();
        EcoraDataService.instance.fetchHostRequests();
      });
    } catch (e) {
      debugPrint("Push non disponibili (Firebase non configurato?): $e");
    }
  }

  /// Best effort al logout: rimuove il token del device corrente cosi'
  /// l'utente disconnesso non riceve piu' push. Va chiamato PRIMA della
  /// signOut (serve la sessione per passare la RLS own-rows).
  Future<void> unregisterDevice() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final token = _currentToken;
      if (uid == null || token == null) return;
      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('user_id', uid)
          .eq('token', token);
      _currentToken = null;
    } catch (e) {
      debugPrint("Errore rimozione token FCM: $e");
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      await Supabase.instance.client.from('device_tokens').upsert(
          deviceTokenRow(uid, token, defaultTargetPlatform.name));
      _currentToken = token;
    } catch (e) {
      debugPrint("Errore salvataggio token FCM: $e");
    }
  }
}
