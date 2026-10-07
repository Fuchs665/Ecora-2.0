import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Casella 18+ (registrazione e "Termini aggiornati").
const String kAgeConsentText = "Dichiaro di avere almeno 18 anni.";

/// Consenso esplicito art. 9 GDPR, separato dai Termini (Blocco E.4b,
/// testo approvato il 07/10/2026).
const String kSensitiveConsentText =
    "Acconsento espressamente al trattamento dei dati sulla mia vita "
    "sessuale e sul mio orientamento sessuale, come descritto "
    "nell'Informativa sulla Privacy.";

/// Testo della casella di consenso in registrazione, con due link separati:
/// Termini di Servizio e Informativa sulla Privacy (Blocco E.3b).
class ConsentText extends StatefulWidget {
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  const ConsentText({
    super.key,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  @override
  State<ConsentText> createState() => _ConsentTextState();
}

class _ConsentTextState extends State<ConsentText> {
  late final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer()
    ..onTap = () => widget.onOpenTerms();
  late final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => widget.onOpenPrivacy();

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: premiumGold,
      fontWeight: FontWeight.bold,
    );
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: textSecondary, fontSize: 12),
        children: [
          const TextSpan(text: "Ho letto e accetto i "),
          TextSpan(
            text: "Termini di Servizio",
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: " e l'"),
          TextSpan(
            text: "Informativa sulla Privacy",
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: "."),
        ],
      ),
    );
  }
}
