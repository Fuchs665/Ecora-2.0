import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'motion.dart';
import 'theme.dart';

// Immagini di rete con cache su disco e copertina "Luce" disegnata
// (Blocco D.2a), generata dall'id della serata e viva in primo piano
// (Blocco D.3). Nessuna foto hardcoded, nessun testo.

/// Dove stanno i tre bagliori della Luce, come frazioni della superficie
/// (Blocco D.3, specifica "EventCover" del design system). Lo stesso id dà
/// sempre la stessa luce: il seme è un hash FNV-1a calcolato qui, stabile
/// tra avvii e versioni di Dart (String.hashCode non lo è).
class LuceSeed {
  final Offset amber;
  final Offset emerald;
  final Offset teal;

  const LuceSeed(this.amber, this.emerald, this.teal);

  /// La luce di quando la serata non è nota (caricamento, avatar).
  static const LuceSeed fallback =
      LuceSeed(Offset(0.9, 0.95), Offset(0.15, 0.1), Offset(0.55, 0.6));

  /// Posizioni tra il 20% e il 90% di larghezza e altezza.
  factory LuceSeed.fromId(String id) {
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    double next() {
      // xorshift a 32 bit: sei valori diversi dallo stesso seme.
      hash ^= (hash << 13) & 0xffffffff;
      hash ^= hash >> 17;
      hash ^= (hash << 5) & 0xffffffff;
      return 0.2 + 0.7 * (hash % 10000) / 9999;
    }

    return LuceSeed(
      Offset(next(), next()),
      Offset(next(), next()),
      Offset(next(), next()),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LuceSeed &&
      other.amber == amber &&
      other.emerald == emerald &&
      other.teal == teal;

  @override
  int get hashCode => Object.hash(amber, emerald, teal);
}

/// Disegna la Luce: fondo scuro e tre bagliori (ambra, smeraldo, teal) nelle
/// posizioni del seme. [phase] da 0 a 1 li sposta di poco, in direzioni
/// diverse: è il movimento lento della copertina. Solo token di
/// `EcoraColors`.
class LucePainter extends CustomPainter {
  final LuceSeed seed;
  final double phase;

  const LucePainter({this.seed = LuceSeed.fallback, this.phase = 0});

  /// Spostamento massimo dei bagliori, in frazioni della superficie.
  static const double drift = 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = EcoraColors.lightBase);
    final shortest = size.shortestSide;
    final d = drift * (2 * phase - 1);
    void glow(Offset at, Offset dir, double radius, Color color) {
      final center = Offset(
        (at.dx + dir.dx * d) * size.width,
        (at.dy + dir.dy * d) * size.height,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.75), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(seed.teal, const Offset(-1, 0.5), shortest * 1.0,
        EcoraColors.lightTeal);
    glow(seed.emerald, const Offset(0.5, -1), shortest * 0.9,
        EcoraColors.lightEmerald);
    glow(seed.amber, const Offset(1, 1), shortest * 0.8,
        EcoraColors.lightAmber);
  }

  @override
  bool shouldRepaint(LucePainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.phase != phase;
}

/// Un ciclo della Luce viva (specifica: 13 secondi).
const Duration kLuceCycle = Duration(seconds: 13);

/// Placeholder di copertina: riempie lo spazio disponibile. Con [seed] la
/// luce è quella della serata; con [animated] i bagliori si muovono piano,
/// tranne con "rimuovi animazioni" (luce ferma).
class CoverPlaceholder extends StatefulWidget {
  final double? width;
  final double? height;
  final LuceSeed seed;
  final bool animated;

  const CoverPlaceholder({
    Key? key,
    this.width,
    this.height,
    this.seed = LuceSeed.fallback,
    this.animated = false,
  }) : super(key: key);

  @override
  State<CoverPlaceholder> createState() => _CoverPlaceholderState();
}

class _CoverPlaceholderState extends State<CoverPlaceholder>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CoverPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Avvia o ferma il movimento secondo [CoverPlaceholder.animated] e
  /// "rimuovi animazioni".
  void _sync() {
    final move = widget.animated &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (move) {
      final controller = _controller ??=
          AnimationController(vsync: this, duration: kLuceCycle);
      if (!controller.isAnimating) controller.repeat(reverse: true);
    } else {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final Widget paint = controller == null
        ? CustomPaint(
            painter: LucePainter(seed: widget.seed),
            child: const SizedBox.expand(),
          )
        : AnimatedBuilder(
            animation: controller,
            builder: (_, __) => CustomPaint(
              painter: LucePainter(
                seed: widget.seed,
                phase: Curves.easeInOut.transform(controller.value),
              ),
              child: const SizedBox.expand(),
            ),
          );
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: RepaintBoundary(child: paint),
    );
  }
}

/// Immagine di rete con cache su disco. Con URL vuoto, in caricamento o in
/// errore mostra [CoverPlaceholder] della stessa misura. Con "rimuovi
/// animazioni" la dissolvenza è azzerata. Va bene dentro un `EcoraHero`.
class EcoraNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Id della serata: la Luce di riserva è la sua (Blocco D.3).
  final String? seedId;

  /// Luce viva (in movimento) quando manca la foto: solo in primo piano.
  final bool animated;

  const EcoraNetworkImage({
    Key? key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.seedId,
    this.animated = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final id = seedId;
    final placeholder = CoverPlaceholder(
      width: width,
      height: height,
      seed: id == null || id.isEmpty ? LuceSeed.fallback : LuceSeed.fromId(id),
      animated: animated,
    );
    if (url.trim().isEmpty) return placeholder;
    final fade = motionDuration(context, EcoraMotion.base);
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fade,
      fadeOutDuration: fade,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}
