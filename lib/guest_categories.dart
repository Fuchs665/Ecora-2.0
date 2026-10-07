import 'models.dart';

// Posti per tipologia (Blocco C.5d, migrazione 0022). Testi approvati il
// 07/10/2026. Una coppia occupa 1 posto, come per il totale.

const String kCategoryLimitsTitle = "Posti per tipologia (facoltativo)";
const String kCategoryLimitsHint =
    "Lascia \"Nessun limite\" se ti basta il totale.";
const String kNoLimit = "Nessun limite";

const String kEventFull = "Serata al completo.";
const String kCouplesFull = "Posti per le coppie esauriti.";
const String kWomenFull = "Posti per le donne esauriti.";
const String kMenFull = "Posti per gli uomini esauriti.";

enum GuestCategory { coppia, donna, uomo }

extension GuestCategoryLabel on GuestCategory {
  /// "Coppie", "Donne", "Uomini".
  String get plural => switch (this) {
        GuestCategory.coppia => "Coppie",
        GuestCategory.donna => "Donne",
        GuestCategory.uomo => "Uomini",
      };
}

/// Stessi valori di guest_category() della 0022 e della registrazione.
/// Null se la tipologia manca o non è riconosciuta. Pura.
GuestCategory? guestCategoryOf(String? profileType) => switch (profileType) {
      'Coppia U/D' || 'Coppia D/D' || 'Coppia U/U' => GuestCategory.coppia,
      'Donna Singola' => GuestCategory.donna,
      'Uomo Singolo' => GuestCategory.uomo,
      _ => null,
    };

/// "Coppie 3/6 · Donne 1/2 · Uomini 0/2": solo le categorie con un limite;
/// vuota se non ce n'è nessuno. Pura.
String categoryLimitsLabel(SupabaseEvent e) {
  final parts = <String>[
    if (e.maxCouples != null)
      "${GuestCategory.coppia.plural} ${e.approvedCouples}/${e.maxCouples}",
    if (e.maxWomen != null)
      "${GuestCategory.donna.plural} ${e.approvedWomen}/${e.maxWomen}",
    if (e.maxMen != null)
      "${GuestCategory.uomo.plural} ${e.approvedMen}/${e.maxMen}",
  ];
  return parts.join(" · ");
}

/// Messaggio per un'approvazione rifiutata dal trigger della 0022, o null
/// se il codice non è dei posti. Pura.
String? capacityErrorMessage(String? code) => switch (code) {
      'EC001' => kEventFull,
      'EC002' => kCouplesFull,
      'EC003' => kWomenFull,
      'EC004' => kMenFull,
      _ => null,
    };

/// Contatore del form: null = nessun limite. "+" da nessun limite porta a
/// 1, "−" da 0 torna a nessun limite; mai oltre il totale. Pure.
int? incrementLimit(int? value, int total) =>
    value == null ? (total >= 1 ? 1 : 0) : (value < total ? value + 1 : value);

int? decrementLimit(int? value) =>
    value == null ? null : (value == 0 ? null : value - 1);

/// Quando il totale scende, i limiti non lo superano. Pura.
int? clampLimit(int? value, int total) =>
    value == null ? null : (value > total ? total : value);
