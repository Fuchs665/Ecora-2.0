import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/secure_session_storage.dart';

class _FakeVault implements SessionVault {
  String? value;
  bool failRead = false, failWrite = false, failDelete = false;
  int deletes = 0;

  _FakeVault([this.value]);

  @override
  Future<String?> read() async {
    if (failRead) throw Exception('read');
    return value;
  }

  @override
  Future<void> write(String v) async {
    if (failWrite) throw Exception('write');
    value = v;
  }

  @override
  Future<void> delete() async {
    deletes++;
    if (failDelete) throw Exception('delete');
    value = null;
  }
}

void main() {
  late _FakeVault secure, legacy;
  late EncryptedSessionStore store;

  void make({String? secureValue, String? legacyValue}) {
    secure = _FakeVault(secureValue);
    legacy = _FakeVault(legacyValue);
    store = EncryptedSessionStore(secure: secure, legacy: legacy);
  }

  group('uso normale', () {
    test('salva, legge e cancella nella memoria cifrata', () async {
      make();
      expect(await store.hasAccessToken(), isFalse);
      await store.persistSession('sessione');
      expect(secure.value, 'sessione');
      expect(await store.accessToken(), 'sessione');
      expect(await store.hasAccessToken(), isTrue);
      await store.removePersistedSession();
      expect(secure.value, isNull);
      expect(await store.hasAccessToken(), isFalse);
    });

    test('il logout pulisce anche il vecchio file', () async {
      make(secureValue: 's', legacyValue: 'vecchia');
      await store.removePersistedSession();
      expect(secure.value, isNull);
      expect(legacy.value, isNull);
    });

    test('logout: un errore su una memoria non blocca l\'altra', () async {
      make(secureValue: 's', legacyValue: 'vecchia');
      secure.failDelete = true;
      await store.removePersistedSession();
      expect(legacy.value, isNull);
    });
  });

  group('migrazione dal file in chiaro', () {
    test('sposta la sessione e cancella il vecchio file', () async {
      make(legacyValue: 'vecchia');
      await store.initialize();
      expect(secure.value, 'vecchia');
      expect(legacy.value, isNull);
      expect(await store.accessToken(), 'vecchia');
    });

    test('con una sessione cifrata già presente non la sovrascrive', () async {
      make(secureValue: 'nuova', legacyValue: 'vecchia');
      await store.initialize();
      expect(secure.value, 'nuova');
      expect(legacy.value, isNull, reason: 'il file in chiaro va comunque via');
    });

    test('niente da spostare: nessuna scrittura', () async {
      make();
      await store.initialize();
      expect(secure.value, isNull);
      expect(legacy.deletes, 0);
    });

    test('copia fallita: il vecchio file resta per il prossimo avvio', () async {
      make(legacyValue: 'vecchia');
      secure.failWrite = true;
      await store.initialize();
      expect(legacy.value, 'vecchia');
      expect(legacy.deletes, 0);
      secure.failWrite = false;
      await store.initialize();
      expect(secure.value, 'vecchia');
      expect(legacy.value, isNull);
    });

    test('vecchio file illeggibile: nessun errore', () async {
      make();
      legacy.failRead = true;
      await store.initialize();
      expect(secure.value, isNull);
    });
  });

  group('errori del Keystore', () {
    test('sessione non decifrabile: assente e cancellata', () async {
      make(secureValue: 'rotta');
      secure.failRead = true;
      expect(await store.accessToken(), isNull);
      expect(await store.hasAccessToken(), isFalse);
      expect(secure.deletes, greaterThan(0));
    });

    test('salvataggio fallito: nessuna eccezione verso supabase', () async {
      make();
      secure.failWrite = true;
      await store.persistSession('s');
      expect(secure.value, isNull);
    });
  });
}
