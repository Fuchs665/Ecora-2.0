import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

// Presenze dopo la serata (Blocco B.2c). Il database (migrazione 0015)
// decide chi può segnare e quando; qui la stessa finestra serve solo a
// mostrare le serate giuste.

/// Quanto tempo dopo la serata si possono segnare le presenze.
const Duration kAttendanceWindow = Duration(days: 7);

/// Vero se la serata del [eventDate] è iniziata da non più di 7 giorni. Pura.
bool isAttendanceOpen(DateTime eventDate, DateTime now) {
  return !now.isBefore(eventDate) &&
      !now.isAfter(eventDate.add(kAttendanceWindow));
}

/// Le serate del gestore in cui segnare chi è venuto: iniziate da non più
/// di 7 giorni e con almeno un ospite approvato. Più recenti prima. Pura.
List<SupabaseEvent> eventsAwaitingAttendance(
    List<SupabaseEvent> hostEvents, DateTime now) {
  final open = <SupabaseEvent, DateTime>{};
  for (final event in hostEvents) {
    final date = DateTime.tryParse(event.eventDate)?.toLocal();
    if (date == null || event.currentApprovedCount == 0) continue;
    if (isAttendanceOpen(date, now)) open[event] = date;
  }
  return open.keys.toList()..sort((a, b) => open[b]!.compareTo(open[a]!));
}

/// Riga dell'elenco: la richiesta approvata e il nome dell'ospite.
class AttendanceGuest {
  final String requestId;
  final String name;

  const AttendanceGuest({required this.requestId, required this.name});
}

/// Elenco "Chi è venuto?" di una serata: per ogni ospite approvato,
/// Presente o Assente. Ogni scelta si salva subito; se il salvataggio
/// fallisce la scelta torna com'era e compare l'errore.
class AttendanceSheet extends StatefulWidget {
  final String eventTitle;
  final List<AttendanceGuest> guests;

  /// Presenze già segnate: request id -> venuto.
  final Future<Map<String, bool>> Function() loadMarks;

  /// Salva una scelta: null se riuscita, altrimenti il messaggio d'errore.
  final Future<String?> Function(String requestId, bool attended) onMark;

  const AttendanceSheet({
    Key? key,
    required this.eventTitle,
    required this.guests,
    required this.loadMarks,
    required this.onMark,
  }) : super(key: key);

  @override
  State<AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends State<AttendanceSheet> {
  Map<String, bool> _marks = {};
  final Set<String> _saving = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final marks = await widget.loadMarks();
      if (!mounted) return;
      setState(() {
        _marks = Map.of(marks);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Impossibile caricare le presenze. Riprova più tardi.";
      });
    }
  }

  Future<void> _mark(String requestId, bool attended) async {
    if (_saving.contains(requestId)) return;
    final previous = _marks[requestId];
    setState(() {
      _marks[requestId] = attended;
      _saving.add(requestId);
      _error = null;
    });
    final error = await widget.onMark(requestId, attended);
    if (!mounted) return;
    setState(() {
      _saving.remove(requestId);
      if (error != null) {
        if (previous == null) {
          _marks.remove(requestId);
        } else {
          _marks[requestId] = previous;
        }
        _error = error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final marked = widget.guests.where((g) => _marks.containsKey(g.requestId));
    final error = _error;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          EcoraSpace.s20,
          EcoraSpace.s24,
          EcoraSpace.s20,
          EcoraSpace.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("CHI È VENUTO?", style: textTheme.labelSmall),
            const SizedBox(height: EcoraSpace.s4),
            Text(widget.eventTitle, style: textTheme.titleLarge),
            const SizedBox(height: EcoraSpace.s8),
            Text(
              "Le assenze contano per la reputazione dell'ospite anche negli "
              "altri locali. Puoi correggere fino a 7 giorni dopo la serata.",
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: EcoraSpace.s16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(EcoraSpace.s24),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: "Caricamento presenze",
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final guest in widget.guests)
                      _GuestRow(
                        name: guest.name,
                        mark: _marks[guest.requestId],
                        saving: _saving.contains(guest.requestId),
                        onChanged: (attended) =>
                            _mark(guest.requestId, attended),
                      ),
                  ],
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: EcoraSpace.s8),
              Text(
                error,
                style: textTheme.bodySmall
                    ?.copyWith(color: EcoraColors.danger),
              ),
            ],
            const SizedBox(height: EcoraSpace.s12),
            Text(
              "Segnati ${marked.length} su ${widget.guests.length}",
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestRow extends StatelessWidget {
  final String name;
  final bool? mark;
  final bool saving;
  final ValueChanged<bool> onChanged;

  const _GuestRow({
    required this.name,
    required this.mark,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = mark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EcoraSpace.s8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: EcoraSpace.s8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text("Presente")),
              ButtonSegment(value: false, label: Text("Assente")),
            ],
            selected: current == null ? const {} : {current},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            // La scelta fatta deve vedersi a colpo d'occhio: ottone pieno.
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: EcoraColors.brass,
              selectedForegroundColor: EcoraColors.onBrass,
            ),
            onSelectionChanged: saving
                ? null
                : (selection) {
                    // Toccare la scelta già attiva non la toglie: una
                    // presenza segnata si corregge, non si cancella.
                    if (selection.isEmpty) return;
                    onChanged(selection.first);
                  },
          ),
        ],
      ),
    );
  }
}
