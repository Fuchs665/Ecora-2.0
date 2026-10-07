import 'dart:io';

import 'package:ecora/consent_text.dart';
import 'package:ecora/main.dart' show kPrivacyPolicyUrl, kTermsUrl;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Blocco E.3b: il consenso in registrazione ha due link separati, Termini e
/// Privacy, e ognuno apre la propria pagina.
void main() {
  const pagesBase = 'https://fuchs665.github.io/Ecora-2.0/';

  Future<List<String>> pump(WidgetTester tester) async {
    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConsentText(
          onOpenTerms: () => opened.add(kTermsUrl),
          onOpenPrivacy: () => opened.add(kPrivacyPolicyUrl),
        ),
      ),
    ));
    return opened;
  }

  TextSpan link(WidgetTester tester, String text) {
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final spans = <TextSpan>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) spans.add(span);
      return true;
    });
    expect(spans, hasLength(1), reason: 'link "$text"');
    return spans.single;
  }

  testWidgets('testo con due link distinti', (tester) async {
    await pump(tester);
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    expect(rich.text.toPlainText(),
        "Ho letto e accetto i Termini di Servizio e l'Informativa sulla Privacy.");
    final terms = link(tester, 'Termini di Servizio');
    final privacy = link(tester, 'Informativa sulla Privacy');
    expect(terms.recognizer, isA<TapGestureRecognizer>());
    expect(privacy.recognizer, isA<TapGestureRecognizer>());
    expect(identical(terms.recognizer, privacy.recognizer), isFalse);
  });

  testWidgets('ogni link apre la propria pagina', (tester) async {
    final opened = await pump(tester);
    (link(tester, 'Termini di Servizio').recognizer! as TapGestureRecognizer)
        .onTap!();
    expect(opened, [kTermsUrl]);
    (link(tester, 'Informativa sulla Privacy').recognizer!
            as TapGestureRecognizer)
        .onTap!();
    expect(opened, [kTermsUrl, kPrivacyPolicyUrl]);
  });

  test('gli URL puntano a pagine che esistono in docs/', () {
    expect(kTermsUrl, '${pagesBase}terms.html');
    expect(kPrivacyPolicyUrl, '${pagesBase}privacy.html');
    for (final url in [kTermsUrl, kPrivacyPolicyUrl]) {
      final file = File('docs/${url.substring(pagesBase.length)}');
      expect(file.existsSync(), isTrue, reason: file.path);
    }
  });
}
