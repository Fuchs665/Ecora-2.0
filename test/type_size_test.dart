import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nessun testo sotto i 12px fuori da theme.dart (labelSmall è a 11)', () {
    final small = RegExp(r'fontSize:\s*(\d|1[01])(\.\d+)?\b');
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('theme.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (small.hasMatch(lines[i])) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty);
  });

  test('i grigi hardcoded dello slider sono diventati token', () {
    for (final p in ['lib/gestore_dashboard.dart', 'lib/client_navigation_hub.dart']) {
      expect(File(p).readAsStringSync(), isNot(contains('0xFF424242')));
    }
  });
}
