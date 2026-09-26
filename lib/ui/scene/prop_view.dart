import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../engine/scene_layout.dart';
import '../../models/world_def.dart';

const ColorFilter _grayscale = ColorFilter.matrix(<double>[
  0.33, 0.33, 0.33, 0, 0, //
  0.33, 0.33, 0.33, 0, 0, //
  0.33, 0.33, 0.33, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// Shakes its child whenever [tick] changes.
class Wiggle extends StatefulWidget {
  const Wiggle({super.key, required this.tick, required this.child, this.amplitude = 0.14, this.alignment = Alignment.center});
  final int tick;
  final Widget child;
  final double amplitude;
  final Alignment alignment;

  @override
  State<Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<Wiggle> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void didUpdateWidget(covariant Wiggle old) {
    super.didUpdateWidget(old);
    if (old.tick != widget.tick) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        final angle = sin(v * pi * 5) * widget.amplitude * (1 - v);
        return Transform.rotate(angle: angle, alignment: widget.alignment, child: child);
      },
      child: widget.child,
    );
  }
}

/// Renders one piece of furniture/scenery in its current state.
class PropView extends StatelessWidget {
  const PropView({
    super.key,
    required this.prop,
    required this.opened,
    required this.locked,
    required this.wiggle,
  });

  final PlacedProp prop;
  final bool opened;
  final bool locked;
  final int wiggle;

  Widget _emoji(String e, double scale) => Center(
        child: Text(
          e,
          style: TextStyle(
            fontSize: prop.size * scale,
            height: 1.0,
            decoration: TextDecoration.none,
            shadows: [Shadow(color: alpha(Colors.black, 0.22), blurRadius: 6, offset: const Offset(0, 4))],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = prop.size;
    final def = prop.def;
    final active = prop.active;
    final dir = prop.pos.dx < kSceneW / 2 ? -1.0 : 1.0;
    Widget body;
    switch (prop.kind) {
      case PropKind.decor:
        body = _emoji(def.emoji, 0.72);
        break;
      case PropKind.curtain:
        body = TweenAnimationBuilder<double>(
          tween: Tween(end: opened ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(painter: _CurtainPainter(t, Color(def.color))),
        );
        break;
      case PropKind.cupboard:
      case PropKind.drawer:
      case PropKind.toybox:
        body = TweenAnimationBuilder<double>(
          tween: Tween(end: opened ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, t, _) => CustomPaint(painter: _CabinetPainter(prop.kind, t, Color(def.color))),
        );
        break;
      case PropKind.book:
        body = AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: KeyedSubtree(
            key: ValueKey(opened),
            child: _emoji(opened && def.openEmoji.isNotEmpty ? def.openEmoji : def.emoji, 0.72),
          ),
        );
        break;
      case PropKind.plant:
        body = TweenAnimationBuilder<double>(
          tween: Tween(end: opened ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, t, _) => Transform.translate(
            offset: Offset(dir * s * 0.62 * t, 0),
            child: Transform.rotate(angle: dir * 0.32 * t, alignment: Alignment.bottomCenter, child: _emoji(def.emoji, 0.78)),
          ),
        );
        break;
      case PropKind.movable:
        body = TweenAnimationBuilder<double>(
          tween: Tween(end: opened ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => Transform.translate(
            offset: Offset(dir * s * 0.66 * t, 0),
            child: _emoji(def.emoji, 0.72),
          ),
        );
        break;
      case PropKind.lamp:
        body = TweenAnimationBuilder<double>(
          tween: Tween(end: opened ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 350),
          builder: (context, t, _) => Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: s * 1.9 * t,
                height: s * 1.9 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [alpha(const Color(0xFFFFF3B0), 0.7 * t), alpha(const Color(0xFFFFF3B0), 0)]),
                ),
              ),
              ColorFiltered(
                colorFilter: t > 0.5 ? const ColorFilter.mode(Colors.transparent, BlendMode.dst) : _grayscale,
                child: _emoji(def.emoji, 0.66),
              ),
            ],
          ),
        );
        break;
      case PropKind.clock:
        body = Wiggle(tick: wiggle, amplitude: 0.35, child: _emoji(def.emoji, 0.72));
        break;
      case PropKind.dark:
        body = TweenAnimationBuilder<double>(
          tween: Tween(end: opened ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 700),
          builder: (context, t, _) => Opacity(
            opacity: 1 - t,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(size: Size(s, s * 0.8), painter: _DarkPatchPainter()),
                Text('?', style: kidQuestion(s * 0.3)),
              ],
            ),
          ),
        );
        break;
    }

    // Wiggle wrapper for interactive non-clock props when tapped.
    if (active && prop.kind != PropKind.clock && prop.kind != PropKind.dark) {
      body = Wiggle(tick: wiggle, amplitude: locked ? 0.1 : 0.05, alignment: Alignment.bottomCenter, child: body);
    }

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (prop.kind != PropKind.dark && prop.kind != PropKind.curtain)
            Positioned(
              left: s * 0.18,
              right: s * 0.18,
              bottom: s * 0.02,
              height: s * 0.09,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: alpha(Colors.black, 0.10),
                  borderRadius: BorderRadius.circular(s),
                ),
              ),
            ),
          Positioned.fill(child: body),
          if (active && locked && prop.kind != PropKind.dark)
            Positioned(
              right: s * 0.02,
              top: s * 0.0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: alpha(Colors.black, 0.25), blurRadius: 4)],
                ),
                child: Text('🔒', style: TextStyle(fontSize: max(16.0, s * 0.16), decoration: TextDecoration.none)),
              ),
            ),
        ],
      ),
    );
  }
}

TextStyle kidQuestion(double size) => TextStyle(
      fontSize: size,
      color: alpha(Colors.white, 0.85),
      fontWeight: FontWeight.w900,
      decoration: TextDecoration.none,
    );

// ---- painters ------------------------------------------------------------------

void _rr(Canvas c, Rect r, Color fill, {double radius = 8, Color? border, double bw = 2.5}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
  c.drawRRect(rr, Paint()..color = fill);
  if (border != null) {
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bw
        ..color = border,
    );
  }
}

class _CurtainPainter extends CustomPainter {
  _CurtainPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final open = clampD(t, 0.0, 1.0);
    // rod
    _rr(canvas, Rect.fromLTWH(w * 0.0, h * 0.03, w, 7), darken(color, 0.35), radius: 4);
    canvas.drawCircle(Offset(w * 0.02, h * 0.03 + 3), 7, Paint()..color = darken(color, 0.4));
    canvas.drawCircle(Offset(w * 0.98, h * 0.03 + 3), 7, Paint()..color = darken(color, 0.4));
    final panelW = w * 0.5 * (1 - 0.74 * open);
    final top = h * 0.06;
    final bottom = h * 0.94;
    void panel(double left, double width) {
      final rect = Rect.fromLTRB(left, top, left + width, bottom);
      final p = Path()..moveTo(rect.left, rect.top);
      p.lineTo(rect.right, rect.top);
      p.lineTo(rect.right, rect.bottom - 8);
      // scalloped hem
      final n = max(2, (width / 14).round());
      for (var i = n; i > 0; i--) {
        final x0 = rect.left + width * i / n;
        final x1 = rect.left + width * (i - 1) / n;
        p.quadraticBezierTo((x0 + x1) / 2, rect.bottom + 6, x1, rect.bottom - 8);
      }
      p.close();
      canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(colors: [lighten(color, 0.12), color, darken(color, 0.1)]).createShader(rect),
      );
      final fold = Paint()
        ..color = alpha(Colors.black, 0.10)
        ..strokeWidth = 2;
      final folds = max(2, (width / 16).round());
      for (var i = 1; i < folds; i++) {
        final x = rect.left + width * i / folds;
        canvas.drawLine(Offset(x, rect.top + 4), Offset(x, rect.bottom - 10), fold);
      }
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = darken(color, 0.25),
      );
    }

    panel(0, panelW);
    panel(w - panelW, panelW);
    // tie-back ribbons when open
    if (open > 0.3) {
      final rp = Paint()
        ..color = alpha(Colors.white, 0.85)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(0, h * 0.5), Offset(panelW, h * 0.5), rp);
      canvas.drawLine(Offset(w - panelW, h * 0.5), Offset(w, h * 0.5), rp);
    }
  }

  @override
  bool shouldRepaint(covariant _CurtainPainter old) => old.t != t || old.color != color;
}

class _CabinetPainter extends CustomPainter {
  _CabinetPainter(this.kind, this.t, this.color);
  final PropKind kind;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final outline = darken(color, 0.32);
    final inner = darken(color, 0.62);
    final open = clampD(t, 0.0, 1.05);
    switch (kind) {
      case PropKind.cupboard:
        {
          final body = Rect.fromLTWH(s * 0.12, s * 0.06, s * 0.76, s * 0.88);
          _rr(canvas, body.inflate(4), darken(color, 0.15), radius: 10, border: outline);
          _rr(canvas, body.deflate(4), inner, radius: 6);
          // shelf in the dark interior
          canvas.drawRect(
            Rect.fromLTWH(body.left + 6, body.center.dy, body.width - 12, 4),
            Paint()..color = alpha(Colors.white, 0.12),
          );
          final half = body.width / 2 - 4;
          final dw = half * (1 - 0.86 * clampD(open, 0.0, 1.0));
          final leftDoor = Rect.fromLTWH(body.left + 4, body.top + 4, dw, body.height - 8);
          final rightDoor = Rect.fromLTWH(body.right - 4 - dw, body.top + 4, dw, body.height - 8);
          for (final d in [leftDoor, rightDoor]) {
            _rr(canvas, d, color, radius: 6, border: outline);
            if (d.width > 14) {
              _rr(canvas, d.deflate(9), lighten(color, 0.12), radius: 4, border: alpha(outline, 0.5), bw: 1.5);
            }
          }
          if (open < 0.4) {
            canvas.drawCircle(Offset(body.center.dx - 8, body.center.dy), 5, Paint()..color = const Color(0xFFFFE066));
            canvas.drawCircle(Offset(body.center.dx + 8, body.center.dy), 5, Paint()..color = const Color(0xFFFFE066));
          }
        }
        break;
      case PropKind.drawer:
        {
          final body = Rect.fromLTWH(s * 0.1, s * 0.12, s * 0.8, s * 0.8);
          _rr(canvas, body, darken(color, 0.08), radius: 10, border: outline);
          final rowH = body.height / 3;
          for (var i = 0; i < 3; i++) {
            var dy = 0.0;
            var dark = false;
            if (i == 0) {
              dy = rowH * 0.55 * clampD(open, 0.0, 1.0);
              dark = open > 0.05;
            }
            final rect = Rect.fromLTWH(body.left + 6, body.top + 6 + rowH * i + dy, body.width - 12, rowH - 8);
            if (dark) {
              _rr(canvas, Rect.fromLTWH(rect.left + 4, body.top + 6, rect.width - 8, rowH - 4), inner, radius: 6);
            }
            _rr(canvas, rect, lighten(color, 0.06 * (i + 1)), radius: 7, border: outline);
            _rr(canvas, Rect.fromCenter(center: rect.center, width: rect.width * 0.28, height: 8), const Color(0xFFFFE066), radius: 4);
          }
          for (final x in [body.left + 8, body.right - 22]) {
            _rr(canvas, Rect.fromLTWH(x, body.bottom - 2, 14, 8), outline, radius: 3);
          }
        }
        break;
      case PropKind.toybox:
        {
          final body = Rect.fromLTWH(s * 0.1, s * 0.42, s * 0.8, s * 0.48);
          _rr(canvas, body, color, radius: 8, border: outline);
          // decorative stripe + star
          _rr(canvas, Rect.fromLTWH(body.left, body.top + body.height * 0.36, body.width, body.height * 0.18), lighten(color, 0.25), radius: 0);
          _star(canvas, body.center.translate(0, body.height * 0.08), body.height * 0.2, const Color(0xFFFFE066));
          // opening
          if (open > 0.05) {
            _rr(canvas, Rect.fromLTWH(body.left + 6, body.top - 4, body.width - 12, 12), inner, radius: 5);
          }
          // lid hinged at the back-left
          canvas.save();
          final hinge = Offset(body.left + 2, body.top - 2);
          canvas.translate(hinge.dx, hinge.dy);
          canvas.rotate(-0.85 * clampD(open, 0.0, 1.05));
          final lid = Rect.fromLTWH(-2, -body.height * 0.22, body.width + 4, body.height * 0.24);
          _rr(canvas, lid, lighten(color, 0.1), radius: 8, border: outline);
          canvas.restore();
        }
        break;
      default:
        break;
    }
  }

  void _star(Canvas c, Offset center, double r, Color col) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(center.dx + cos(a) * rad, center.dy + sin(a) * rad);
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    c.drawPath(p, Paint()..color = col);
  }

  @override
  bool shouldRepaint(covariant _CabinetPainter old) => old.t != t || old.color != color || old.kind != kind;
}

class _DarkPatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawOval(
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [alpha(const Color(0xFF241552), 0.92), alpha(const Color(0xFF241552), 0.7), alpha(const Color(0xFF241552), 0.0)],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(covariant _DarkPatchPainter old) => false;
}
