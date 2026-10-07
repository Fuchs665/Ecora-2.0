import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Blocco E.4c (audit A4, A5): backup spento e FLAG_SECURE. La prova vera è
// sul telefono; qui si controlla che nessuno li tolga per sbaglio.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('backup spento nel manifest', () {
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
  });

  test('regole di estrazione: tutto escluso da cloud e trasferimento', () {
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
        .readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp('<$section>(.*?)</$section>', dotAll: true)
          .firstMatch(rules)!
          .group(1)!;
      for (final domain in ['root', 'file', 'database', 'sharedpref', 'external']) {
        expect(body, contains('<exclude domain="$domain" path="." />'),
            reason: '$section/$domain');
      }
      expect(body, isNot(contains('<include')), reason: section);
    }
  });

  test('FLAG_SECURE impostato nella MainActivity', () {
    final activity =
        File('android/app/src/main/kotlin/com/ecora/app/MainActivity.kt')
            .readAsStringSync();
    expect(activity, contains('WindowManager.LayoutParams.FLAG_SECURE'));
    expect(activity, contains('window.setFlags('));
    expect(activity, isNot(contains('clearFlags')));
  });
}
