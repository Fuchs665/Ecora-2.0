import 'package:flutter/material.dart';
import 'theme.dart';

// Skeleton della dashboard gestore (Blocco C.2): stessi ingombri della
// fascia metriche e delle righe serata, finché le letture iniziali non
// finiscono. Pulsano solo i segnaposto, le card restano ferme.

/// Mezzo ciclo della pulsazione. Nessun token in EcoraMotion: è un
/// movimento continuo, non una transizione.
const Duration _kPulse = Duration(milliseconds: 1200);

class DashboardSkeleton extends StatefulWidget {
  const DashboardSkeleton({Key? key}) : super(key: key);

  @override
  State<DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: _kPulse);
    _opacity = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con "rimuovi animazioni" i segnaposto restano fermi e pieni.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: "Caricamento delle serate",
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MetricsPlaceholder(opacity: _opacity),
            const SizedBox(height: EcoraSpace.s24),
            // Intestazione della lista.
            _Bar(opacity: _opacity, width: 136, height: 12),
            const SizedBox(height: EcoraSpace.s12),
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: EcoraSpace.s12),
                child: _EventRowPlaceholder(opacity: _opacity),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un rettangolo segnaposto. Senza [width] prende la larghezza del padre
/// per [widthFactor].
class _Bar extends StatelessWidget {
  final Animation<double> opacity;
  final double? width;
  final double widthFactor;
  final double height;

  const _Bar({
    required this.opacity,
    this.width,
    this.widthFactor = 1,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bar = FadeTransition(
      opacity: opacity,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: EcoraColors.elevated,
          borderRadius: BorderRadius.circular(EcoraRadius.control),
        ),
      ),
    );
    if (width != null) return bar;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: bar,
    );
  }
}

/// Come GestoreMetricsStrip: tre celle con numero e due righe di etichetta.
class _MetricsPlaceholder extends StatelessWidget {
  final Animation<double> opacity;

  const _MetricsPlaceholder({required this.opacity});

  @override
  Widget build(BuildContext context) {
    Widget cell() => Padding(
          padding: const EdgeInsets.all(EcoraSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Riga del numero, alta come EcoraTextStyles.metric.
              SizedBox(
                height: 30,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _Bar(opacity: opacity, width: 48, height: 20),
                ),
              ),
              const SizedBox(height: EcoraSpace.s4),
              // Due righe di etichetta in bodySmall.
              SizedBox(
                height: 17,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _Bar(opacity: opacity, widthFactor: 0.9, height: 10),
                ),
              ),
              SizedBox(
                height: 17,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _Bar(opacity: opacity, widthFactor: 0.6, height: 10),
                ),
              ),
            ],
          ),
        );

    return Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cell()),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: cell()),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: cell()),
          ],
        ),
      ),
    );
  }
}

/// Come una riga serata della lista: copertina 72×72, titolo e sottotitolo.
class _EventRowPlaceholder extends StatelessWidget {
  final Animation<double> opacity;

  const _EventRowPlaceholder({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoraSpace.s12),
        child: Row(
          children: [
            _Bar(opacity: opacity, width: 72, height: 72),
            const SizedBox(width: EcoraSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bar(opacity: opacity, widthFactor: 0.6, height: 14),
                  const SizedBox(height: EcoraSpace.s8),
                  _Bar(opacity: opacity, widthFactor: 0.4, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
