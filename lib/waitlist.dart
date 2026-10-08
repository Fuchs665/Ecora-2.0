import 'models.dart';

// Lista d'attesa (Blocco L.2, migrazione 0023). Testi approvati il
// 08/10/2026. Lo stato lo decide il server alla candidatura.

const String kWaitlistStatus = "In lista d'attesa";
const String kWaitlistSection = "Lista d'attesa";

/// "Sei 3° in lista. Ti avvisiamo se si libera un posto." Senza posizione
/// (non ancora letta o lettura fallita) solo la seconda frase. Pura.
String waitlistDetail(int? position) {
  const notice = "Ti avvisiamo se si libera un posto.";
  if (position == null || position < 1) return notice;
  return "Sei $position° in lista. $notice";
}

/// Le richieste in lista d'attesa, dalla più vecchia: l'ordine di arrivo.
/// Pura.
List<SupabaseParticipationRequest> waitlistedInOrder(
    Iterable<SupabaseParticipationRequest> requests) {
  final list = requests.where((r) => r.status == 'waitlisted').toList();
  list.sort((a, b) {
    final ca = a.createdAt, cb = b.createdAt;
    if (ca == null && cb == null) return 0;
    if (ca == null) return 1;
    if (cb == null) return -1;
    return ca.compareTo(cb);
  });
  return list;
}
