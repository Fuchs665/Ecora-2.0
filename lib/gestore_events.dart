import 'package:flutter/material.dart';
import 'cover_placeholder.dart';
import 'italian_dates.dart';
import 'models.dart';
import 'motion.dart';
import 'theme.dart';

// Card delle serate della dashboard gestore (Blocco C.5, tavola "Serate").

/// Divide le serate del gestore in "prossima" e "in programma". Le serate
/// già iniziate non compaiono (le gestisce "Da chiudere"); quelle con data
/// illeggibile vanno in coda a "in programma". Pura.
({SupabaseEvent? next, List<SupabaseEvent> upcoming}) splitHostEvents(
    List<SupabaseEvent> hostEvents, DateTime now) {
  final dated = <SupabaseEvent, DateTime>{};
  final undated = <SupabaseEvent>[];
  for (final event in hostEvents) {
    final date = DateTime.tryParse(event.eventDate)?.toLocal();
    if (date == null) {
      undated.add(event);
    } else if (!date.isBefore(now)) {
      dated[event] = date;
    }
  }
  final sorted = dated.keys.toList()
    ..sort((a, b) => dated[a]!.compareTo(dated[b]!));
  final all = [...sorted, ...undated];
  if (all.isEmpty) return (next: null, upcoming: <SupabaseEvent>[]);
  return (next: all.first, upcoming: all.sublist(1));
}

/// "sabato 17 ottobre" dalla data della serata; vuota se illeggibile. Pura.
String eventDateLabel(String eventDate) {
  final date = DateTime.tryParse(eventDate)?.toLocal();
  if (date == null) return '';
  final dayMonth = italianDayMonth(date).replaceFirst(RegExp(r"^(il |l')"), '');
  return '${italianWeekdayName(date)} $dayMonth';
}

String _confirmedLabel(SupabaseEvent e) =>
    "${e.currentApprovedCount} / ${e.maxParticipants} coppie confermate";

/// Card "Prossima serata": copertina, posti e richieste da valutare.
class NextEventCard extends StatelessWidget {
  final SupabaseEvent event;
  final int pendingCount;
  final VoidCallback onTap;
  final VoidCallback onEvaluate;

  const NextEventCard({
    Key? key,
    required this.event,
    required this.pendingCount,
    required this.onTap,
    required this.onEvaluate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final date = eventDateLabel(event.eventDate);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EcoraHero(
                    tag: eventCoverHeroTag(event.id),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        EcoraNetworkImage(url: event.imageUrl),
                      ],
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(color: EcoraColors.coverScrim),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(EcoraSpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text("PROSSIMA SERATA",
                            style: textTheme.labelSmall
                                ?.copyWith(color: EcoraColors.ink)),
                        if (date.isNotEmpty)
                          Text(date,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: EcoraColors.ink)),
                        Text(event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleLarge
                                ?.copyWith(color: EcoraColors.ink)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(EcoraSpace.s16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_confirmedLabel(event), style: textTheme.bodyMedium),
                      EcoraAnimatedSize(
                        child: pendingCount > 0
                            ? Text(
                                pendingCount == 1
                                    ? "1 richiesta da valutare"
                                    : "$pendingCount richieste da valutare",
                                style: textTheme.bodySmall
                                    ?.copyWith(color: EcoraColors.warning),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: motionDuration(context, EcoraMotion.base),
                  child: pendingCount > 0
                      ? FilledButton(
                          key: const ValueKey('valuta'),
                          onPressed: onEvaluate,
                          child: const Text("Valuta"),
                        )
                      : const SizedBox.shrink(key: ValueKey('no-valuta')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Riga della lista "In programma": tassello della data, titolo, posti.
class UpcomingEventTile extends StatelessWidget {
  final SupabaseEvent event;
  final int pendingCount;
  final VoidCallback onTap;

  const UpcomingEventTile({
    Key? key,
    required this.event,
    required this.pendingCount,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final date = DateTime.tryParse(event.eventDate)?.toLocal();
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EcoraRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(EcoraSpace.s12),
          child: Row(
            children: [
              AnimatedContainer(
                duration: motionDuration(context, EcoraMotion.base),
                curve: EcoraMotion.enterCurve,
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: EcoraSpace.s8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: pendingCount > 0
                          ? EcoraColors.brass
                          : EcoraColors.lineControl),
                  borderRadius: BorderRadius.circular(EcoraRadius.control),
                ),
                child: Column(
                  children: [
                    Text(date == null ? '–' : '${date.day}',
                        style: textTheme.titleLarge),
                    Text(
                      date == null
                          ? ''
                          : italianMonthName(date)
                              .substring(0, 3)
                              .toUpperCase(),
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EcoraSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: textTheme.titleMedium),
                    Text(_confirmedLabel(event), style: textTheme.bodySmall),
                    if (pendingCount > 0)
                      Text(
                        pendingCount == 1
                            ? "1 richiesta in attesa"
                            : "$pendingCount richieste in attesa",
                        style: textTheme.bodySmall
                            ?.copyWith(color: EcoraColors.warning),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: EcoraColors.brass),
            ],
          ),
        ),
      ),
    );
  }
}
