import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'italian_dates.dart';
import 'models.dart';
import 'theme.dart';

// Fascia metriche della dashboard gestore (Blocco C.1, tavola "Serate").
// Tutto viene da eventsNotifier + requestsNotifier già caricati: nessuna
// query in più.

/// Gli eventi del gestore [hostId]. `get_events_with_stats()` restituisce
/// tutti gli eventi pubblicati, anche quelli degli altri locali. Pura.
List<SupabaseEvent> eventsHostedBy(List<SupabaseEvent> events, String hostId) {
  return events.where((e) => e.organizerId == hostId).toList();
}

/// "richieste a ottobre"; "ad" solo davanti ad a- ("ad aprile"). Pura.
String requestsMonthLabel(DateTime now) {
  final month = italianMonthName(now);
  final preposition = month.startsWith('a') ? 'ad' : 'a';
  return 'richieste $preposition $month';
}

/// Etichetta degli ospiti confermati alla prossima serata: "stasera" se è
/// oggi, il giorno della settimana entro 6 giorni, la data oltre. Pura.
String nextEventLabel(DateTime? eventDate, DateTime now) {
  if (eventDate == null) return 'nessuna serata in programma';
  // Giorni di calendario contati in UTC: il cambio d'ora non li sposta.
  final days = DateTime.utc(eventDate.year, eventDate.month, eventDate.day)
      .difference(DateTime.utc(now.year, now.month, now.day))
      .inDays;
  if (days <= 0) return 'confermati stasera';
  if (days < 7) return 'confermati ${italianWeekdayName(eventDate)}';
  return 'confermati ${italianDayMonth(eventDate)}';
}

/// I tre numeri della fascia. Pura, testabile.
class GestoreMetrics {
  /// Richieste di qualunque stato ricevute nel mese di [computedAt].
  final int requestsThisMonth;

  /// Media di confermati/posti sulle serate già concluse, tra 0 e 1.
  /// Null se non ce n'è nessuna.
  final double? averageFill;

  /// La serata futura più vicina, con la sua data in ora locale.
  final SupabaseEvent? nextEvent;
  final DateTime? nextEventDate;

  final DateTime computedAt;

  const GestoreMetrics({
    required this.requestsThisMonth,
    required this.averageFill,
    required this.nextEvent,
    required this.nextEventDate,
    required this.computedAt,
  });

  String get requestsValue => '$requestsThisMonth';
  String get requestsLabel => requestsMonthLabel(computedAt);

  String get fillValue {
    final fill = averageFill;
    return fill == null ? '—' : '${(fill * 100).round()}%';
  }

  String get fillLabel => 'riempimento medio';

  String get nextValue {
    final event = nextEvent;
    if (event == null) return '—';
    return '${event.currentApprovedCount}/${event.maxParticipants}';
  }

  String get nextLabel => nextEventLabel(nextEventDate, computedAt);
}

/// Calcola le metriche. [hostEvents] sono già filtrati con [eventsHostedBy];
/// [requests] sono quelle del gestore (fetchHostRequests). Pura.
GestoreMetrics computeGestoreMetrics({
  required List<SupabaseEvent> hostEvents,
  required List<SupabaseParticipationRequest> requests,
  required DateTime now,
}) {
  final requestsThisMonth = requests.where((r) {
    final created = r.createdAt;
    return created != null &&
        created.year == now.year &&
        created.month == now.month;
  }).length;

  final fills = <double>[];
  SupabaseEvent? nextEvent;
  DateTime? nextEventDate;
  for (final event in hostEvents) {
    final date = DateTime.tryParse(event.eventDate)?.toLocal();
    if (date == null) continue;
    if (date.isBefore(now)) {
      if (event.maxParticipants > 0) {
        fills.add(math.min(1.0, event.tableCompletionPercentage));
      }
    } else if (nextEventDate == null || date.isBefore(nextEventDate)) {
      nextEvent = event;
      nextEventDate = date;
    }
  }

  return GestoreMetrics(
    requestsThisMonth: requestsThisMonth,
    averageFill:
        fills.isEmpty ? null : fills.reduce((a, b) => a + b) / fills.length,
    nextEvent: nextEvent,
    nextEventDate: nextEventDate,
    computedAt: now,
  );
}

/// Tre celle affiancate sotto l'intestazione della dashboard.
class GestoreMetricsStrip extends StatelessWidget {
  final GestoreMetrics metrics;

  const GestoreMetricsStrip({Key? key, required this.metrics})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _MetricCell(
                value: metrics.requestsValue,
                label: metrics.requestsLabel,
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: _MetricCell(
                value: metrics.fillValue,
                label: metrics.fillLabel,
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: _MetricCell(
                value: metrics.nextValue,
                label: metrics.nextLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String value;
  final String label;

  const _MetricCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    // Una sola frase per lo screen reader: "64, richieste a ottobre".
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(EcoraSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // "128/150" non deve andare a capo: si rimpicciolisce.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: EcoraTextStyles.metric, maxLines: 1),
            ),
            const SizedBox(height: EcoraSpace.s4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
