import 'package:flutter/material.dart';

import 'theme.dart';

// Locale non verificato o sospeso (Blocco V.2, migrazione 0021). Testi
// approvati il 07/10/2026.

const String kVenueInactiveTitle = "Locale non attivo";
const String kVenueInactiveBody =
    "Il tuo locale non è attivo: non puoi pubblicare serate e quelle già "
    "pubblicate non sono visibili agli iscritti. Se pensi che sia un errore, "
    "scrivici dai contatti indicati nei Termini di Servizio.";

/// Avviso fisso in cima alla dashboard del gestore.
class VenueInactiveNotice extends StatelessWidget {
  const VenueInactiveNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoraSpace.s16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: EcoraColors.warning),
            const SizedBox(width: EcoraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kVenueInactiveTitle, style: textTheme.titleMedium),
                  const SizedBox(height: EcoraSpace.s4),
                  Text(
                    kVenueInactiveBody,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: EcoraColors.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "CREA SERATA" con il locale non attivo: lo stesso avviso, prima del
/// controllo dell'abbonamento (un locale non attivo non arriva al pagamento).
Future<void> showVenueInactiveSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(EcoraSpace.s16),
        child: VenueInactiveNotice(),
      ),
    ),
  );
}
