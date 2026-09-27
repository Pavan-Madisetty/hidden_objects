import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../engine/level_session.dart';
import '../../engine/scene_layout.dart';
import '../../models/world_def.dart';
import '../widgets/particles.dart';
import 'item_view.dart';
import 'prop_view.dart';
import 'scene_painter.dart';

/// The explorable scene: zoom (pinch / wheel / buttons), pan (drag), tap to
/// find objects and open things. All coordinates inside are "scene units".
class SceneView extends StatefulWidget {
  const SceneView({
    super.key,
    required this.session,
    required this.theme,
    required this.onOutcome,
    this.hint,
    this.handAt,
  });

  final LevelSession session;
  final WorldTheme theme;
  final void Function(TapOutcome outcome) onOutcome;
  final HintResult? hint;

  /// Scene position where the tutorial finger should tap.
  final Offset? handAt;

  @override
  State<SceneView> createState() => SceneViewState();
}

class SceneViewState extends State<SceneView> with SingleTickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  final ParticleSystem particles = ParticleSystem();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
  Animation<Matrix4>? _tween;
  Size _viewport = Size.zero;
  double _fit = 1.0;
  bool _placed = false;

  double get _minScale => _fit;
  double get _maxScale => max(_fit * 4.5, 1.8);

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final t = _tween;
      if (t != null) _tc.value = t.value;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _tc.dispose();
    particles.dispose();
    super.dispose();
  }

  // ---- camera -----------------------------------------------------------------

  Matrix4 _matrixFor(Offset scenePoint, double scale) {
    final vw = _viewport.width;
    final vh = _viewport.height;
    var tx = vw / 2 - scenePoint.dx * scale;
    var ty = vh / 2 - scenePoint.dy * scale;
    const margin = 24.0;
    final sw = kSceneW * scale;
    final sh = kSceneH * scale;
    tx = sw + 2 * margin <= vw ? (vw - sw) / 2 : clampD(tx, vw - sw - margin, margin);
    ty = sh + 2 * margin <= vh ? (vh - sh) / 2 : clampD(ty, vh - sh - margin, margin);
    return Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);
  }

  void _animateTo(Matrix4 target) {
    _tween = Matrix4Tween(begin: _tc.value, end: target)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic));
    _anim.forward(from: 0);
  }

  void _placeInitial() {
    final z = widget.session.cfg.initialZoom;
    _tc.value = _matrixFor(const Offset(kSceneW / 2, kSceneH / 2), clampD(_fit * z, _minScale, _maxScale));
    _placed = true;
  }

  /// Smoothly centres the camera on a scene position (used by hints).
  void focusOn(Offset scenePoint, {double? zoom}) {
    if (_viewport == Size.zero) return;
    final cur = _tc.value.getMaxScaleOnAxis();
    final target = clampD(zoom ?? max(cur, _fit * 1.7), _minScale, _maxScale);
    _animateTo(_matrixFor(scenePoint, target));
  }

  void zoomBy(double factor) {
    if (_viewport == Size.zero) return;
    final cur = _tc.value.getMaxScaleOnAxis();
    final next = clampD(cur * factor, _minScale, _maxScale);
    final center = _tc.toScene(Offset(_viewport.width / 2, _viewport.height / 2));
    _animateTo(_matrixFor(center, next));
  }

  void resetView() {
    if (_viewport == Size.zero) return;
    _animateTo(_matrixFor(const Offset(kSceneW / 2, kSceneH / 2), _fit));
  }

  /// Sparkle burst in scene coordinates.
  void burst(Offset scenePos, {bool big = false}) {
    particles.burst(scenePos, count: big ? 22 : 14, speed: big ? 170 : 130, size: big ? 11 : 8);
  }

  void puff(Offset scenePos) {
    particles.burst(
      scenePos,
      count: 6,
      colors: const [Color(0xAAFFFFFF)],
      shape: ParticleShape.circle,
      speed: 45,
      life: 0.35,
      size: 12,
    );
  }

  // ---- input --------------------------------------------------------------------

  void _onTap(Offset local) {
    final scale = _tc.value.getMaxScaleOnAxis();
    final out = widget.session.tapAt(local, scale: scale);
    if (out.kind == TapKind.wrong && out.item == null) puff(local);
    widget.onOutcome(out);
  }

  // ---- build ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final vp = Size(box.maxWidth, box.maxHeight);
        if (vp != _viewport) {
          _viewport = vp;
          _fit = min(vp.width / kSceneW, vp.height / kSceneH);
          if (!_placed) {
            _placeInitial();
          }
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: InteractiveViewer(
            transformationController: _tc,
            constrained: false,
            minScale: _minScale,
            maxScale: _maxScale,
            boundaryMargin: const EdgeInsets.all(24),
            child: SizedBox(
              width: kSceneW,
              height: kSceneH,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onTap(d.localPosition),
                child: ParticleLayer(
                  system: particles,
                  child: AnimatedBuilder(
                    animation: widget.session,
                    builder: (context, _) => _buildScene(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScene() {
    final s = widget.session;
    final room = s.room;
    final layout = s.layout;

    final behindItems = <Widget>[];
    final frontItems = <Widget>[];
    for (final it in layout.items) {
      if (it.room != room) continue;
      if (!s.isDrawn(it) && !s.found.contains(it.id)) continue;
      final popIn = it.hiddenIn != null && !s.isBehindLayer(it);
      final w = Positioned(
        key: ValueKey('i-${it.id}'),
        left: it.pos.dx - it.size / 2,
        top: it.pos.dy - it.size / 2,
        width: it.size,
        height: it.size,
        child: IgnorePointer(
          child: ItemView(
            item: it,
            found: s.found.contains(it.id),
            wobble: s.wobbles[it.id] ?? 0,
            popIn: popIn,
          ),
        ),
      );
      if (s.isBehindLayer(it)) {
        behindItems.add(w);
      } else {
        frontItems.add(w);
      }
    }

    final props = <Widget>[];
    for (final p in layout.props) {
      if (p.room != room) continue;
      props.add(Positioned(
        key: ValueKey('p-${p.id}-${p.room}'),
        left: p.pos.dx - p.size / 2,
        top: p.pos.dy - p.size / 2,
        width: p.size,
        height: p.size,
        child: IgnorePointer(
          child: PropView(
            prop: p,
            opened: s.isOpen(p.id),
            locked: s.isLocked(p.id),
            wiggle: s.wiggles[p.id] ?? 0,
          ),
        ),
      ));
    }

    final clutter = <Widget>[
      for (final cl in layout.clutter)
        if (cl.room == room)
          Positioned(
            left: cl.pos.dx - cl.size / 2,
            top: cl.pos.dy - cl.size / 2,
            width: cl.size,
            height: cl.size,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: cl.angle,
                child: Center(
                  child: Text(
                    cl.emoji,
                    style: TextStyle(
                      fontSize: cl.size * 0.8,
                      decoration: TextDecoration.none,
                      shadows: [Shadow(color: alpha(Colors.black, 0.25), blurRadius: 4, offset: const Offset(0, 3))],
                    ),
                  ),
                ),
              ),
            ),
          ),
    ];

    final hint = widget.hint;
    final hand = widget.handAt;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: SizedBox(
        key: ValueKey('room-$room'),
        width: kSceneW,
        height: kSceneH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: SceneBackdropPainter(widget.theme, room, look: layout.look)),
              ),
            ),
            RepaintBoundary(child: Stack(clipBehavior: Clip.none, children: clutter)),
            ...behindItems,
            ...props,
            ...frontItems,
            if (hint != null && hint.room == room)
              Positioned(
                left: hint.center.dx - hint.radius,
                top: hint.center.dy - hint.radius,
                child: IgnorePointer(child: HintRing(radius: hint.radius)),
              ),
            if (hand != null)
              Positioned(
                left: hand.dx - 60,
                top: hand.dy - 60,
                width: 120,
                height: 120,
                child: const IgnorePointer(child: Center(child: TutorialHand())),
              ),
          ],
        ),
      ),
    );
  }
}
