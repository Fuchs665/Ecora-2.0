import 'package:flutter/widgets.dart';
import 'theme.dart';

// Movimento (Blocco D.1). Tutto si spegne con "rimuovi animazioni".

/// True se il sistema chiede di ridurre il movimento.
bool motionReduced(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Durata da usare per una transizione: zero se il movimento è ridotto.
Duration motionDuration(BuildContext context, Duration normal) =>
    motionReduced(context) ? Duration.zero : normal;

/// `AnimatedSize` che con il movimento ridotto non anima: `AnimatedSize` con
/// durata zero rilancia un'eccezione di layout, quindi qui si salta del tutto.
class EcoraAnimatedSize extends StatelessWidget {
  final Alignment alignment;
  final Widget child;

  const EcoraAnimatedSize({
    Key? key,
    this.alignment = Alignment.topLeft,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (motionReduced(context)) return child;
    return AnimatedSize(
      duration: EcoraMotion.base,
      curve: EcoraMotion.enterCurve,
      alignment: alignment,
      child: child,
    );
  }
}

/// Tag unico dell'Hero della copertina di una serata.
String eventCoverHeroTag(String eventId) => 'event-cover-$eventId';

/// Hero della copertina: con il movimento ridotto restituisce il figlio così
/// com'è, senza volo tra le pagine.
class EcoraHero extends StatelessWidget {
  final String tag;
  final Widget child;

  const EcoraHero({Key? key, required this.tag, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (motionReduced(context)) return child;
    return Hero(tag: tag, child: child);
  }
}

/// `IndexedStack` con dissolvenza in ingresso del tab nuovo. Tutti i tab
/// restano montati, quindi conservano scroll e stato (a differenza di un
/// `AnimatedSwitcher`).
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const FadeIndexedStack({
    Key? key,
    required this.index,
    required this.children,
  }) : super(key: key);

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: EcoraMotion.base,
    value: 1,
  );
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: EcoraMotion.enterCurve);

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (motionReduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: IndexedStack(index: widget.index, children: widget.children),
    );
  }
}
