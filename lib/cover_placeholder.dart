import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'motion.dart';
import 'theme.dart';

// Immagini di rete con cache su disco e placeholder "Luce" disegnato
// (Blocco D.2a). Nessuna foto hardcoded, nessun testo.

/// Disegna la Luce: base scura, un bagliore ambra in basso a destra e uno
/// smeraldo in alto a sinistra. Solo token di `EcoraColors`.
class LucePainter extends CustomPainter {
  const LucePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EcoraColors.lightBase, EcoraColors.lightTeal],
        ).createShader(rect),
    );
    final shortest = size.shortestSide;
    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(Offset(size.width * 0.15, size.height * 0.1), shortest * 0.9,
        EcoraColors.lightEmerald);
    glow(Offset(size.width * 0.9, size.height * 0.95), shortest * 1.1,
        EcoraColors.lightAmber);
  }

  @override
  bool shouldRepaint(LucePainter oldDelegate) => false;
}

/// Placeholder di copertina: riempie lo spazio disponibile.
class CoverPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;

  const CoverPlaceholder({Key? key, this.width, this.height}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const CustomPaint(painter: LucePainter(), child: SizedBox.expand()),
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

  const EcoraNetworkImage({
    Key? key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final placeholder = CoverPlaceholder(width: width, height: height);
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
