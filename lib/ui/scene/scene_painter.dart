import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../engine/scene_layout.dart' show SceneLook;
import '../../models/world_def.dart';

/// Paints the storybook backdrop of a world: wall/sky, floor/ground and soft
/// decoration. Objects and props are widgets on top of this.
/// [variant] 1 draws the mirrored second room of multi-room levels.
class SceneBackdropPainter extends CustomPainter {
  SceneBackdropPainter(WorldTheme base, this.variant, {this.look = SceneLook.plain})
      : theme = _varied(base, look);

  final WorldTheme theme;
  final int variant;
  final SceneLook look;

  static Color _hue(Color c, double deg) {
    if (deg == 0) return c;
    final hsl = HSLColor.fromColor(c);
    return hsl.withHue(((hsl.hue + deg) % 360 + 360) % 360).toColor();
  }

  static WorldTheme _varied(WorldTheme t, SceneLook l) {
    if (identical(l, SceneLook.plain)) return t;
    return WorldTheme(
      style: t.style,
      skyTop: _hue(t.skyTop, l.hue),
      skyBottom: _hue(t.skyBottom, l.hue),
      groundA: _hue(t.groundA, l.hue * 0.6),
      groundB: _hue(t.groundB, l.hue * 0.6),
      accent: _hue(t.accent, l.hue * 1.3),
      floor: l.floorIndex < 0 ? t.floor : FloorPattern.values[l.floorIndex % FloorPattern.values.length],
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    if ((variant == 1) != look.mirror) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    switch (theme.style) {
      case SceneStyle.room:
        _room(canvas, w, h);
        break;
      case SceneStyle.outdoor:
        _outdoor(canvas, w, h);
        break;
      case SceneStyle.sea:
        _sea(canvas, w, h);
        break;
      case SceneStyle.space:
        _space(canvas, w, h);
        break;
      case SceneStyle.castle:
        _castle(canvas, w, h);
        break;
    }
    canvas.restore();
    final rect = Offset.zero & size;
    // time-of-day tint: bright (easy), golden (medium), dusk (hard)
    if (look.tintAlpha > 0) {
      canvas.drawRect(rect, Paint()..color = alpha(look.tint, look.tintAlpha));
    }
    // soft vignette for depth
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [const Color(0x00000000), alpha(Colors.black, look.vignette)],
          stops: const [0.72, 1.0],
        ).createShader(rect),
    );
  }

  Color get _skyTop => variant == 1 ? mix(theme.skyTop, theme.accent, 0.18) : theme.skyTop;
  Color get _skyBottom => variant == 1 ? mix(theme.skyBottom, theme.accent, 0.12) : theme.skyBottom;

  Paint _fill(Color c) => Paint()..color = c;

  Paint _grad(Rect r, Color a, Color b) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [a, b],
    ).createShader(r);

  void _cloud(Canvas c, double cx, double cy, double s, {double a = 0.92}) {
    final p = _fill(alpha(Colors.white, a));
    c.drawCircle(Offset(cx, cy), 16 * s, p);
    c.drawCircle(Offset(cx + 18 * s, cy - 8 * s), 20 * s, p);
    c.drawCircle(Offset(cx + 40 * s, cy), 15 * s, p);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 16 * s, cy, 72 * s, 15 * s), Radius.circular(8 * s)),
      p,
    );
  }

  void _sun(Canvas c, double cx, double cy, double r) {
    c.drawCircle(Offset(cx, cy), r * 1.7, _fill(alpha(const Color(0xFFFFF3B0), 0.35)));
    c.drawCircle(Offset(cx, cy), r * 1.3, _fill(alpha(const Color(0xFFFFF3B0), 0.5)));
    c.drawCircle(Offset(cx, cy), r, _fill(const Color(0xFFFFE066)));
  }

  void _floor(Canvas c, double w, double h, double top) {
    final rect = Rect.fromLTWH(0, top, w, h - top);
    c.drawRect(rect, _fill(theme.groundA));
    final line = Paint()
      ..color = alpha(theme.groundB, 0.9)
      ..strokeWidth = 2;
    switch (theme.floor) {
      case FloorPattern.planks:
        var row = 0;
        for (var y = top + 40; y < h; y += 44) {
          c.drawLine(Offset(0, y), Offset(w, y), line);
          final off = (row % 2) * 70.0;
          for (var x = off; x < w; x += 140) {
            c.drawLine(Offset(x, y - 44), Offset(x, y), line);
          }
          row++;
        }
        break;
      case FloorPattern.checker:
        const s = 60.0;
        var r = 0;
        for (var y = top; y < h; y += s) {
          var cc = 0;
          for (var x = 0.0; x < w; x += s) {
            if ((r + cc) % 2 == 0) {
              c.drawRect(Rect.fromLTWH(x, y, s, s), _fill(theme.groundB));
            }
            cc++;
          }
          r++;
        }
        break;
      case FloorPattern.stripes:
        for (var x = 0.0; x < w; x += 100) {
          c.drawRect(Rect.fromLTWH(x, top, 50, h - top), _fill(alpha(theme.groundB, 0.7)));
        }
        break;
    }
    // soft shadow under the wall
    c.drawRect(
      Rect.fromLTWH(0, top, w, 26),
      _grad(Rect.fromLTWH(0, top, w, 26), alpha(Colors.black, 0.14), alpha(Colors.black, 0.0)),
    );
  }

  void _rug(Canvas c, double w, double h) {
    final center = Offset(w * (0.36 + look.b * 0.28), h * (0.70 + look.a * 0.06));
    c.drawOval(Rect.fromCenter(center: center, width: 380, height: 120), _fill(alpha(theme.accent, 0.22)));
    c.drawOval(
      Rect.fromCenter(center: center, width: 320, height: 92),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = alpha(Colors.white, 0.35),
    );
  }

  // ---- rooms -----------------------------------------------------------------

  void _window(Canvas c, Rect r) {
    final frame = RRect.fromRectAndRadius(r.inflate(7), const Radius.circular(18));
    c.drawRRect(frame, _fill(Colors.white));
    final glass = RRect.fromRectAndRadius(r, const Radius.circular(12));
    c.drawRRect(glass, _grad(r, const Color(0xFF9BE0FF), const Color(0xFFE6F8FF)));
    c.save();
    c.clipRRect(glass);
    _sun(c, r.right - 34, r.top + 30, 15);
    _cloud(c, r.left + 20, r.bottom - 38, 0.7);
    c.restore();
    final bar = Paint()
      ..color = Colors.white
      ..strokeWidth = 6;
    c.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), bar);
    c.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), bar);
  }

  void _room(Canvas c, double w, double h) {
    final horizon = h * 0.55;
    final wall = Rect.fromLTWH(0, 0, w, horizon);
    c.drawRect(wall, _grad(wall, _skyTop, _skyBottom));
    // wallpaper: dots, stripes or stars (varies per level)
    final dot = _fill(alpha(Colors.white, 0.2));
    final pat = look.seed % 3;
    if (pat == 1) {
      for (var x = 0.0; x < w; x += 60) {
        c.drawRect(Rect.fromLTWH(x, 0, 28, horizon), _fill(alpha(Colors.white, 0.10)));
      }
    } else {
      var row = 0;
      for (var y = 18.0; y < horizon - 18; y += 38) {
        for (var x = (row % 2) * 24.0 + 12; x < w; x += 48) {
          if (pat == 2) {
            c.drawCircle(Offset(x, y), 2.6, dot);
            c.drawCircle(Offset(x + 8, y + 6), 1.6, dot);
          } else {
            c.drawCircle(Offset(x, y), 4, dot);
          }
        }
        row++;
      }
    }
    // bunting
    final bunt = [theme.accent, const Color(0xFFFFD166), const Color(0xFF6EC6FF), const Color(0xFF8BE36B)];
    final rope = Paint()
      ..color = alpha(Colors.white, 0.8)
      ..strokeWidth = 2;
    c.drawLine(Offset(0, 14), Offset(w, 14), rope);
    for (var i = 0; i < 13; i++) {
      final x = 20 + i * 46.0;
      final p = Path()
        ..moveTo(x, 14)
        ..lineTo(x + 26, 14)
        ..lineTo(x + 13, 40)
        ..close();
      c.drawPath(p, _fill(alpha(bunt[i % bunt.length], 0.75)));
    }
    // window (slot A)
    final wx = 0.06 + look.a * 0.5; // window slides along the wall
    final ww = 0.22 + look.b * 0.08;
    _window(c, Rect.fromLTRB(w * wx, h * 0.105, w * (wx + ww), h * (0.27 + look.b * 0.04)));
    // baseboard
    c.drawRect(Rect.fromLTWH(0, horizon - 12, w, 16), _fill(darken(_skyBottom, 0.1)));
    _floor(c, w, h, horizon + 4);
    _rug(c, w, h);
  }

  // ---- outdoors -----------------------------------------------------------------

  void _hills(Canvas c, double w, double base, Color color, double amp, double phase) {
    final p = Path()..moveTo(0, base + 30);
    p.lineTo(0, base);
    for (var x = 0.0; x <= w; x += 20) {
      p.lineTo(x, base - amp * (0.5 + 0.5 * sin(x / 90 + phase)));
    }
    p.lineTo(w, base + 30);
    p.close();
    c.drawPath(p, _fill(color));
  }

  void _outdoor(Canvas c, double w, double h) {
    final horizon = h * 0.5;
    final sky = Rect.fromLTWH(0, 0, w, horizon + 20);
    c.drawRect(sky, _grad(sky, _skyTop, _skyBottom));
    _sun(c, w * (0.15 + look.a * 0.7), h * 0.085, 34);
    _cloud(c, w * (0.05 + look.b * 0.3), h * 0.07, 1.0);
    _cloud(c, w * (0.3 + look.a * 0.3), h * 0.16, 0.8, a: 0.85);
    _cloud(c, w * (0.5 + look.b * 0.3), h * 0.31, 0.9, a: 0.8);
    _hills(c, w, horizon - 6, mix(theme.groundA, _skyBottom, 0.55), 46, 0.5);
    _hills(c, w, horizon + 12, mix(theme.groundA, _skyBottom, 0.3), 34, 2.4);
    final ground = Rect.fromLTWH(0, horizon + 18, w, h - horizon - 18);
    c.drawRect(ground, _grad(ground, theme.groundA, theme.groundB));
    // mowed stripes
    for (var y = horizon + 40; y < h; y += 56) {
      c.drawRect(Rect.fromLTWH(0, y, w, 26), _fill(alpha(Colors.white, 0.06)));
    }
    // flowers
    final rnd = Random(4 + look.seed % 1000);
    const cols = [Color(0xFFFFFFFF), Color(0xFFFFB3D9), Color(0xFFFFE066), Color(0xFFB39DFF)];
    for (var i = 0; i < 46; i++) {
      final x = rnd.nextDouble() * w;
      final y = horizon + 40 + rnd.nextDouble() * (h - horizon - 50);
      c.drawCircle(Offset(x, y), 3.4, _fill(alpha(cols[i % cols.length], 0.75)));
      c.drawCircle(Offset(x, y), 1.4, _fill(alpha(const Color(0xFFFFB100), 0.9)));
    }
  }

  void _sea(Canvas c, double w, double h) {
    final sky = Rect.fromLTWH(0, 0, w, h * 0.42);
    c.drawRect(sky, _grad(sky, _skyTop, _skyBottom));
    _sun(c, w * 0.82, h * 0.09, 32);
    _cloud(c, w * 0.1, h * 0.08, 0.9);
    _cloud(c, w * 0.5, h * 0.2, 0.7, a: 0.8);
    final seaTop = h * 0.4;
    final seaRect = Rect.fromLTWH(0, seaTop, w, h * 0.28);
    c.drawRect(seaRect, _grad(seaRect, lighten(theme.accent, 0.35), theme.accent));
    // island
    c.drawOval(Rect.fromCenter(center: Offset(w * 0.8, seaTop + 6), width: 150, height: 44), _fill(const Color(0xFFF2D49B)));
    // waves
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = alpha(Colors.white, 0.4);
    for (var row = 0; row < 5; row++) {
      final y = seaTop + 24 + row * 32.0;
      final p = Path()..moveTo(-10, y);
      for (var x = -10.0; x <= w + 10; x += 6) {
        p.lineTo(x, y + sin(x / 24 + row * 1.7) * 5);
      }
      c.drawPath(p, wave);
    }
    // deck
    final deckTop = h * 0.66;
    c.drawRect(Rect.fromLTWH(0, deckTop, w, h - deckTop), _fill(theme.groundA));
    final seam = Paint()
      ..color = alpha(theme.groundB, 0.9)
      ..strokeWidth = 2.5;
    var r = 0;
    for (var y = deckTop + 36; y < h; y += 46) {
      c.drawLine(Offset(0, y), Offset(w, y), seam);
      for (var x = (r % 2) * 90.0; x < w; x += 180) {
        c.drawLine(Offset(x, y - 46), Offset(x, y), seam);
      }
      r++;
    }
    c.drawRect(Rect.fromLTWH(0, deckTop - 8, w, 14), _fill(darken(theme.groundA, 0.18)));
    c.drawRect(Rect.fromLTWH(0, deckTop + 6, w, 22), _grad(Rect.fromLTWH(0, deckTop + 6, w, 22), alpha(Colors.black, 0.14), alpha(Colors.black, 0)));
  }

  void _space(Canvas c, double w, double h) {
    final bg = Rect.fromLTWH(0, 0, w, h);
    c.drawRect(bg, _grad(bg, _skyTop, _skyBottom));
    final rnd = Random(9);
    for (var i = 0; i < 80; i++) {
      final x = rnd.nextDouble() * w;
      final y = rnd.nextDouble() * h * 0.7;
      c.drawCircle(Offset(x, y), 0.8 + rnd.nextDouble() * 1.8, _fill(alpha(Colors.white, 0.5 + rnd.nextDouble() * 0.4)));
    }
    // sparkle stars
    for (var i = 0; i < 9; i++) {
      final x = rnd.nextDouble() * w;
      final y = rnd.nextDouble() * h * 0.55;
      final s = 4 + rnd.nextDouble() * 4;
      final p = Path()
        ..moveTo(x, y - s * 2)
        ..lineTo(x + s * 0.5, y - s * 0.5)
        ..lineTo(x + s * 2, y)
        ..lineTo(x + s * 0.5, y + s * 0.5)
        ..lineTo(x, y + s * 2)
        ..lineTo(x - s * 0.5, y + s * 0.5)
        ..lineTo(x - s * 2, y)
        ..lineTo(x - s * 0.5, y - s * 0.5)
        ..close();
      c.drawPath(p, _fill(alpha(const Color(0xFFFFF3B0), 0.85)));
    }
    // planet with ring
    final pc = Offset(w * 0.84, h * 0.12);
    c.drawCircle(pc, 44, _fill(const Color(0xFFFFA66B)));
    c.drawCircle(pc.translate(-10, -10), 20, _fill(alpha(Colors.white, 0.18)));
    c.drawOval(
      Rect.fromCenter(center: pc, width: 130, height: 28),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = alpha(const Color(0xFFFFE066), 0.85),
    );
    c.drawCircle(Offset(w * 0.1, h * 0.46), 22, _fill(alpha(const Color(0xFF5DE0E6), 0.55)));
    // moon surface
    final top = h * 0.6;
    final moon = Path()..moveTo(0, top + 16);
    for (var x = 0.0; x <= w; x += 12) {
      moon.lineTo(x, top - 22 * (0.5 + 0.5 * sin(x / 80 + 1.0)));
    }
    moon
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    c.drawPath(moon, _grad(Rect.fromLTWH(0, top - 30, w, h - top + 30), theme.groundA, theme.groundB));
    for (var i = 0; i < 9; i++) {
      final x = rnd.nextDouble() * w;
      final y = top + 30 + rnd.nextDouble() * (h - top - 60);
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 46 + rnd.nextDouble() * 30, height: 16), _fill(alpha(Colors.black, 0.09)));
    }
  }

  void _castle(Canvas c, double w, double h) {
    final horizon = h * 0.57;
    final wall = Rect.fromLTWH(0, 0, w, horizon);
    c.drawRect(wall, _grad(wall, _skyTop, _skyBottom));
    // bricks
    final brick = Paint()
      ..color = alpha(Colors.white, 0.28)
      ..strokeWidth = 2;
    var row = 0;
    for (var y = 0.0; y < horizon; y += 34) {
      c.drawLine(Offset(0, y), Offset(w, y), brick);
      for (var x = (row % 2) * 34.0; x < w; x += 68) {
        c.drawLine(Offset(x, y), Offset(x, y + 34), brick);
      }
      row++;
    }
    // arched window (slot A)
    final win = Rect.fromLTRB(w * 0.1, h * 0.12, w * 0.34, h * 0.31);
    final arch = Path()
      ..moveTo(win.left, win.bottom)
      ..lineTo(win.left, win.top + win.width / 2)
      ..arcToPoint(Offset(win.right, win.top + win.width / 2), radius: Radius.circular(win.width / 2))
      ..lineTo(win.right, win.bottom)
      ..close();
    c.drawPath(arch, _fill(darken(_skyBottom, 0.2)));
    c.save();
    c.clipPath(arch);
    c.drawRect(win, _grad(win, const Color(0xFF9BE0FF), const Color(0xFFE6F8FF)));
    _cloud(c, win.left + 10, win.bottom - 30, 0.6);
    c.restore();
    c.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = alpha(Colors.white, 0.9),
    );
    // hanging flags
    final flag = [theme.accent, const Color(0xFFFFD166), const Color(0xFF6EC6FF)];
    for (var i = 0; i < 6; i++) {
      final x = 60 + i * 96.0;
      final p = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 22, 0)
        ..lineTo(x + 22, 34)
        ..lineTo(x + 11, 24)
        ..lineTo(x, 34)
        ..close();
      c.drawPath(p, _fill(alpha(flag[i % 3], 0.7)));
    }
    c.drawRect(Rect.fromLTWH(0, horizon - 12, w, 16), _fill(darken(_skyBottom, 0.12)));
    _floor(c, w, h, horizon + 4);
    _rug(c, w, h);
  }

  @override
  bool shouldRepaint(covariant SceneBackdropPainter old) =>
      old.variant != variant || !identical(old.look, look) || old.theme.style != theme.style;
}
