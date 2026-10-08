import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'theme.dart';

// Profondità che segue il telefono (Blocco D.4, primo momento 3D del design
// system). Si legge la gravità dall'accelerometro e si misura l'inclinazione
// rispetto a come il telefono era tenuto all'apertura della pagina: niente
// deriva, a differenza della velocità angolare del giroscopio sommata nel
// tempo.

/// Gravità misurata dal telefono (m/s², come l'accelerometro).
class Gravity {
  final double x;
  final double y;
  final double z;

  const Gravity(this.x, this.y, this.z);
}

/// Inclinazione che porta al massimo dell'effetto (circa 20°), come
/// differenza delle componenti normalizzate della gravità.
const double kTiltRange = 0.35;

/// Quanto pesa ogni nuova lettura nel filtro (più basso = più morbido).
const double kTiltSmoothing = 0.15;

/// Inclinazione da -1 a 1 sui due assi rispetto a [baseline]. Pura.
/// dx > 0: telefono girato verso destra; dy > 0: verso l'utente in alto.
Offset tiltFrom(Gravity baseline, Gravity current) {
  Offset unit(Gravity g) {
    final n = math.sqrt(g.x * g.x + g.y * g.y + g.z * g.z);
    if (n == 0) return Offset.zero;
    return Offset(g.x / n, g.y / n);
  }

  final d = unit(current) - unit(baseline);
  return Offset(
    (-d.dx / kTiltRange).clamp(-1.0, 1.0),
    (d.dy / kTiltRange).clamp(-1.0, 1.0),
  );
}

/// Filtro passa-basso: l'immagine non trema. Pura.
Offset smoothTilt(Offset previous, Offset next,
        [double alpha = kTiltSmoothing]) =>
    Offset.lerp(previous, next, alpha)!;

/// Matrice della copertina: prospettiva `perspective-screen` e rotazione
/// fino a `tilt-max`. Pura.
Matrix4 coverTiltMatrix(Offset tilt) {
  const max = EcoraDepth.tiltMaxDegrees * math.pi / 180;
  return Matrix4.identity()
    ..setEntry(3, 2, 1 / EcoraDepth.perspectiveScreen)
    ..rotateX(-tilt.dy * max)
    ..rotateY(tilt.dx * max);
}

Stream<Gravity> _accelerometer() =>
    accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
        .map((e) => Gravity(e.x, e.y, e.z));

/// Fornisce l'inclinazione del telefono ai discendenti, con
/// [DeviceTilt.of]. Ascolta il sensore solo mentre è montato, visibile e
/// con l'app in primo piano; con "rimuovi animazioni", senza sensore o in
/// errore l'inclinazione resta zero.
class DeviceTilt extends StatefulWidget {
  final Widget child;

  /// Sorgente della gravità, sostituibile nei test.
  final Stream<Gravity> Function()? source;

  const DeviceTilt({super.key, required this.child, this.source});

  /// L'inclinazione corrente; zero se non c'è un [DeviceTilt] sopra.
  static ValueListenable<Offset> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_TiltScope>()
          ?.notifier ??
      _zero;

  static final ValueNotifier<Offset> _zero = ValueNotifier(Offset.zero);

  @override
  State<DeviceTilt> createState() => _DeviceTiltState();
}

class _DeviceTiltState extends State<DeviceTilt> with WidgetsBindingObserver {
  final ValueNotifier<Offset> _tilt = ValueNotifier(Offset.zero);
  StreamSubscription<Gravity>? _subscription;
  Gravity? _baseline;
  bool _failed = false;
  bool _foreground = true;
  bool _visible = true;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  bool get _shouldListen =>
      !_failed && _foreground && _visible && !_reducedMotion;

  void _sync() {
    if (_shouldListen) {
      _subscription ??= (widget.source ?? _accelerometer)().listen(
        _onGravity,
        onError: (Object e) {
          debugPrint("Sensore di inclinazione non disponibile: $e");
          _failed = true;
          _stop();
        },
        cancelOnError: true,
      );
    } else {
      _stop();
    }
  }

  /// Smette di ascoltare e rimette la copertina dritta. Alla ripresa la
  /// posizione di riferimento è quella nuova.
  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    _baseline = null;
    _tilt.value = Offset.zero;
  }

  void _onGravity(Gravity g) {
    final baseline = _baseline ??= g;
    _tilt.value = smoothTilt(_tilt.value, tiltFrom(baseline, g));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _tilt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TiltScope(notifier: _tilt, child: widget.child);
  }
}

class _TiltScope extends InheritedWidget {
  final ValueNotifier<Offset> notifier;

  const _TiltScope({required this.notifier, required super.child});

  @override
  bool updateShouldNotify(_TiltScope oldWidget) =>
      oldWidget.notifier != notifier;
}

/// Inclina [child] come una copertina (rotazione in prospettiva).
class TiltingCover extends StatelessWidget {
  final Widget child;

  const TiltingCover({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: DeviceTilt.of(context),
      child: child,
      builder: (_, tilt, child) => Transform(
        alignment: Alignment.center,
        transform: coverTiltMatrix(tilt),
        child: child,
      ),
    );
  }
}

/// Sposta [child] di [distance] punti al massimo, nel verso
/// dell'inclinazione ([direction] 1) o opposto (-1).
class TiltParallax extends StatelessWidget {
  final Widget child;
  final double distance;
  final double direction;

  const TiltParallax({
    super.key,
    required this.child,
    required this.distance,
    this.direction = 1,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: DeviceTilt.of(context),
      child: child,
      builder: (_, tilt, child) => Transform.translate(
        offset: tilt * distance * direction,
        child: child,
      ),
    );
  }
}
