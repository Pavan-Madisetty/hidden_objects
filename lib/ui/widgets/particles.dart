import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum ParticleShape { circle, star, rect }

class _P {
  _P({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.color,
    required this.shape,
    required this.gravity,
    required this.rot,
    required this.vr,
  }) : maxLife = life;

  double x, y, vx, vy, life, size, rot, vr;
  final double maxLife;
  final Color color;
  final ParticleShape shape;
  final double gravity;
}

/// Lightweight particle engine used for sparkles and (gentle) confetti.
class ParticleSystem extends ChangeNotifier {
  final List<_P> _ps = [];
  final Random _r = Random();

  static const List<Color> sparkleColors = [
    Color(0xFFFFE066),
    Color(0xFFFFFFFF),
    Color(0xFFFFB3D9),
    Color(0xFF9BE7FF),
  ];
  static const List<Color> confettiColors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFC42E),
    Color(0xFF4ECDC4),
    Color(0xFF6C8CFF),
    Color(0xFFFF8AD8),
    Color(0xFF8BE36B),
  ];

  bool get isEmpty => _ps.isEmpty;

  void burst(
    Offset at, {
    int count = 14,
    List<Color>? colors,
    double speed = 130,
    double life = 0.7,
    double size = 8,
    ParticleShape shape = ParticleShape.star,
  }) {
    final cs = colors ?? sparkleColors;
    for (var i = 0; i < count; i++) {
      final a = _r.nextDouble() * pi * 2;
      final v = speed * (0.4 + _r.nextDouble() * 0.8);
      _ps.add(_P(
        x: at.dx,
        y: at.dy,
        vx: cos(a) * v,
        vy: sin(a) * v - 20,
        life: life * (0.7 + _r.nextDouble() * 0.6),
        size: size * (0.6 + _r.nextDouble() * 0.8),
        color: cs[_r.nextInt(cs.length)],
        shape: shape,
        gravity: 120,
        rot: _r.nextDouble() * pi,
        vr: (_r.nextDouble() - 0.5) * 6,
      ));
    }
    notifyListeners();
  }

  /// A short, soft confetti shower across [width].
  void confetti(double width, {int count = 70}) {
    for (var i = 0; i < count; i++) {
      _ps.add(_P(
        x: _r.nextDouble() * width,
        y: -20 - _r.nextDouble() * 120,
        vx: (_r.nextDouble() - 0.5) * 60,
        vy: 90 + _r.nextDouble() * 120,
        life: 2.0 + _r.nextDouble() * 1.0,
        size: 7 + _r.nextDouble() * 6,
        color: confettiColors[_r.nextInt(confettiColors.length)],
        shape: _r.nextBool() ? ParticleShape.rect : ParticleShape.circle,
        gravity: 30,
        rot: _r.nextDouble() * pi,
        vr: (_r.nextDouble() - 0.5) * 8,
      ));
    }
    notifyListeners();
  }

  void update(double dt) {
    if (_ps.isEmpty) return;
    for (final p in _ps) {
      p.life -= dt;
      p.vy += p.gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vr * dt;
    }
    _ps.removeWhere((p) => p.life <= 0);
    notifyListeners();
  }

  void paintAll(Canvas canvas) {
    final paint = Paint();
    for (final p in _ps) {
      final t = (p.life / p.maxLife);
      final a = t > 0.35 ? 1.0 : (t / 0.35);
      paint.color = p.color.withAlpha((a * 255).round());
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rot);
      switch (p.shape) {
        case ParticleShape.circle:
          canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
          break;
        case ParticleShape.rect:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
              const Radius.circular(2),
            ),
            paint,
          );
          break;
        case ParticleShape.star:
          final path = Path();
          const pts = 4;
          for (var i = 0; i < pts * 2; i++) {
            final r = i.isEven ? p.size : p.size * 0.3;
            final ang = pi * i / pts;
            final px = cos(ang) * r;
            final py = sin(ang) * r;
            if (i == 0) {
              path.moveTo(px, py);
            } else {
              path.lineTo(px, py);
            }
          }
          path.close();
          canvas.drawPath(path, paint);
          break;
      }
      canvas.restore();
    }
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.system) : super(repaint: system);
  final ParticleSystem system;

  @override
  void paint(Canvas canvas, Size size) => system.paintAll(canvas);

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.system != system;
}

/// Drives a [ParticleSystem] and paints it above its child. Never blocks taps.
class ParticleLayer extends StatefulWidget {
  const ParticleLayer({super.key, required this.system, this.child});
  final ParticleSystem system;
  final Widget? child;

  @override
  State<ParticleLayer> createState() => _ParticleLayerState();
}

class _ParticleLayerState extends State<ParticleLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = min(0.05, (elapsed - _last).inMicroseconds / 1e6);
      _last = elapsed;
      widget.system.update(dt);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (widget.child != null) widget.child!,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _ParticlePainter(widget.system)),
            ),
          ),
        ),
      ],
    );
  }
}
