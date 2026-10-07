import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Sessione di Supabase cifrata (Blocco E.4e, audit A4). supabase_flutter 1.x
// la salva in chiaro in un file Hive della cartella dell'app (token di
// accesso e di rinnovo); qui va in flutter_secure_storage, cifrata con
// chiavi del Keystore di Android. Alla prima apertura dopo l'aggiornamento
// la sessione del file Hive si sposta qui, così nessuno viene disconnesso.

/// Un posto dove tenere la stringa della sessione.
abstract class SessionVault {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// La memoria cifrata.
class KeystoreSessionVault implements SessionVault {
  static const String _key = 'ecora_supabase_session';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// Il vecchio file Hive in chiaro, letto con la classe della libreria
/// stessa: serve solo a spostare la sessione e a cancellarla.
class LegacyHiveSessionVault implements SessionVault {
  final HiveLocalStorage _hive = const HiveLocalStorage();
  Future<void>? _ready;

  Future<void> _open() => _ready ??= _hive.initialize();

  @override
  Future<String?> read() async {
    await _open();
    return _hive.accessToken();
  }

  @override
  Future<void> write(String value) =>
      throw UnsupportedError('Il file Hive in chiaro non si scrive più.');

  @override
  Future<void> delete() async {
    await _open();
    await _hive.removePersistedSession();
  }
}

/// La logica, separata da [LocalStorage] per poterla provare con memorie
/// finte. Nessun metodo lancia eccezioni verso supabase_flutter: un errore
/// del Keystore vuol dire "nessuna sessione", mai un'app bloccata.
class EncryptedSessionStore {
  final SessionVault secure;
  final SessionVault legacy;

  EncryptedSessionStore({required this.secure, required this.legacy});

  /// All'avvio: sposta la sessione dal file in chiaro, se c'è.
  Future<void> initialize() async {
    final current = await accessToken();
    String? old;
    try {
      old = await legacy.read();
    } catch (e) {
      debugPrint("Sessione: vecchio file non leggibile: $e");
      return;
    }
    if (old == null) return;
    if (current == null) {
      try {
        await secure.write(old);
      } catch (e) {
        // Il file in chiaro resta: si riprova al prossimo avvio, senza
        // perdere la sessione.
        debugPrint("Sessione: copia nella memoria cifrata non riuscita: $e");
        return;
      }
    }
    try {
      await legacy.delete();
    } catch (e) {
      debugPrint("Sessione: vecchio file non cancellato: $e");
    }
  }

  Future<bool> hasAccessToken() async => await accessToken() != null;

  /// La sessione salvata, o null. Se non si riesce a decifrarla (chiavi
  /// del Keystore perse) la si cancella: si rifà l'accesso.
  Future<String?> accessToken() async {
    try {
      return await secure.read();
    } catch (e) {
      debugPrint("Sessione cifrata non leggibile: $e");
      await _deleteQuietly(secure);
      return null;
    }
  }

  Future<void> persistSession(String session) async {
    try {
      await secure.write(session);
    } catch (e) {
      // La sessione resta in memoria: al prossimo avvio si rifà l'accesso.
      debugPrint("Sessione non salvata nella memoria cifrata: $e");
    }
  }

  Future<void> removePersistedSession() async {
    await _deleteQuietly(secure);
    await _deleteQuietly(legacy);
  }

  static Future<void> _deleteQuietly(SessionVault vault) async {
    try {
      await vault.delete();
    } catch (e) {
      debugPrint("Sessione non cancellata: $e");
    }
  }
}

/// Da passare a Supabase.initialize(localStorage: ...).
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage._(EncryptedSessionStore store)
      : super(
          initialize: store.initialize,
          hasAccessToken: store.hasAccessToken,
          accessToken: store.accessToken,
          persistSession: store.persistSession,
          removePersistedSession: store.removePersistedSession,
        );

  factory SecureSessionStorage({SessionVault? secure, SessionVault? legacy}) =>
      SecureSessionStorage._(EncryptedSessionStore(
        secure: secure ?? KeystoreSessionVault(),
        legacy: legacy ?? LegacyHiveSessionVault(),
      ));
}
