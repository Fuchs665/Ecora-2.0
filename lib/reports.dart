// Segnalazioni (Blocco E.2b): tipi, motivi e testi, senza dipendenze da
// Flutter né da Supabase. La tabella `reports` e le sue regole sono nella
// migrazione 0019 (supabase/migrations/0019_segnalazioni.sql): i codici dei
// motivi qui sotto devono restare uguali al check `reports_reason_check`.

// --- Testi (approvati il 06/10/2026) -----------------------------------------
const String kReportMessageAction = "Segnala messaggio";
const String kReportEventAction = "Segnala serata";
const String kReportUserAction = "SEGNALA UTENTE";
const String kReportMessageTitle = "Segnala messaggio";
const String kReportEventTitle = "Segnala serata";
const String kReportUserTitle = "Segnala utente";
const String kReportSubtitle = "Chi segnali non vedrà il tuo nome.";
const String kReportNoteLabel = "Dettagli (facoltativo)";
const String kReportSubmit = "Invia segnalazione";
const String kReportCancel = "Annulla";
const String kReportSent = "Segnalazione inviata. La esaminiamo entro 24 ore.";
const String kReportAlreadySent =
    "Hai già segnalato questo contenuto: lo stiamo esaminando.";
const String kReportRateLimited =
    "Hai inviato troppe segnalazioni oggi. Riprova domani.";
const String kReportFailed = "Invio non riuscito. Riprova.";
const String kReportBlock = "Blocca";
const String kReportNoThanks = "No, grazie";
const String kMessageBlockedTerms =
    "Il messaggio contiene termini non ammessi su Ecora.";

/// Domanda dopo l'invio: "Vuoi anche bloccare Marco?".
String reportBlockQuestion(String name) => "Vuoi anche bloccare $name?";

/// Lunghezza massima della nota (check `reports_note_check`).
const int kReportNoteMaxLength = 500;

enum ReportTargetType { message, user, event }

class ReportReason {
  /// Codice salvato in `reports.reason`.
  final String code;
  final String label;
  const ReportReason(this.code, this.label);
}

/// Motivi a lista fissa, nell'ordine in cui compaiono nel foglio.
const Map<ReportTargetType, List<ReportReason>> kReportReasons = {
  ReportTargetType.message: [
    ReportReason('harassment', "Offese o molestie"),
    ReportReason('threats', "Minacce"),
    ReportReason('unwanted_sexual', "Contenuto sessuale non richiesto"),
    ReportReason('spam', "Spam o truffa"),
    ReportReason('other', "Altro"),
  ],
  ReportTargetType.user: [
    ReportReason('underage', "Sembra minorenne"),
    ReportReason('fake_profile', "Profilo falso"),
    ReportReason('inappropriate_photos', "Foto inappropriate nella galleria"),
    ReportReason('harassment', "Offese o molestie"),
    ReportReason('spam', "Spam o truffa"),
    ReportReason('other', "Altro"),
  ],
  ReportTargetType.event: [
    ReportReason('not_a_venue', "Non si svolge in un locale"),
    ReportReason('misleading', "Serata falsa o ingannevole"),
    ReportReason('inappropriate_content', "Contenuti inappropriati"),
    ReportReason('spam', "Spam o truffa"),
    ReportReason('other', "Altro"),
  ],
};

String reportTitle(ReportTargetType type) {
  switch (type) {
    case ReportTargetType.message:
      return kReportMessageTitle;
    case ReportTargetType.user:
      return kReportUserTitle;
    case ReportTargetType.event:
      return kReportEventTitle;
  }
}

/// Cosa si segnala: il tipo e l'id del messaggio, dell'utente o della serata.
class ReportTarget {
  final ReportTargetType type;
  final String id;
  const ReportTarget(this.type, this.id);
}

/// Riga da inserire in `reports`. Solo le sei colonne che l'app può
/// scrivere: segnalante, stato, responsabile e snapshot li decide il server.
/// La nota vuota (o di soli spazi) non si manda.
Map<String, dynamic> reportRow(
    ReportTarget target, String reason, String note) {
  final trimmed = note.trim();
  return {
    'target_type': target.type.name,
    if (target.type == ReportTargetType.message) 'target_message_id': target.id,
    if (target.type == ReportTargetType.user) 'target_user_id': target.id,
    if (target.type == ReportTargetType.event) 'target_event_id': target.id,
    'reason': reason,
    if (trimmed.isNotEmpty) 'note': trimmed,
  };
}

enum ReportResult { sent, alreadyReported, rateLimited, failed }

/// Codice d'errore di Postgres -> esito. 23505: c'è già una segnalazione
/// aperta dello stesso utente sullo stesso bersaglio; EC429: tetto di 20 in
/// 24 ore. Tutto il resto (rete, bersaglio non più visibile, ...) è un
/// errore generico.
ReportResult reportResultFromCode(String? code) {
  switch (code) {
    case '23505':
      return ReportResult.alreadyReported;
    case 'EC429':
      return ReportResult.rateLimited;
    default:
      return ReportResult.failed;
  }
}

/// Errore dell'invio di un messaggio in chat: EC422 = filtro delle parole
/// (trigger `messages_filter_terms`), il resto è l'errore di sempre.
String sendMessageErrorForCode(String? code) =>
    code == 'EC422' ? kMessageBlockedTerms : "Invio non riuscito. Riprova.";
