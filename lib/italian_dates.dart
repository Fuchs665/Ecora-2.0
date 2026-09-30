// Date in italiano per le etichette dell'interfaccia (Blocco C.1). Niente
// pacchetto intl: bastano mesi, giorni e le regole dell'articolo.

const List<String> _kMonths = [
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

// Nell'ordine di DateTime.weekday (1 = lunedì).
const List<String> _kWeekdays = [
  'lunedì',
  'martedì',
  'mercoledì',
  'giovedì',
  'venerdì',
  'sabato',
  'domenica',
];

/// "ottobre" dal mese di [date]. Pura.
String italianMonthName(DateTime date) => _kMonths[date.month - 1];

/// "sabato" dal giorno della settimana di [date]. Pura.
String italianWeekdayName(DateTime date) => _kWeekdays[date.weekday - 1];

/// Giorno e mese con l'articolo: "il 17 ottobre", "l'8 ottobre",
/// "il 1° ottobre". Con [afterA] l'articolo si unisce alla preposizione
/// "a": "al 17 ottobre", "all'11 ottobre". Pura.
String italianDayMonth(DateTime date, {bool afterA = false}) {
  // 8 e 11 si leggono "otto" e "undici": l'articolo si elide.
  final elided = date.day == 8 || date.day == 11;
  final String article;
  if (elided) {
    article = afterA ? "all'" : "l'";
  } else {
    article = afterA ? 'al ' : 'il ';
  }
  final day = date.day == 1 ? '1°' : '${date.day}';
  return '$article$day ${italianMonthName(date)}';
}
