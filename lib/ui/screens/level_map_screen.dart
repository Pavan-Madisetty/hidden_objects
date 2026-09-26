import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../models/world_def.dart';
import '../../services/audio_service.dart';
import '../../state/app_scope.dart';
import '../../state/game_controller.dart';
import '../widgets/bouncy.dart';
import '../widgets/dialogs.dart';
import '../widgets/mascot.dart';
import '../widgets/sky_background.dart';
import 'flow.dart';

const double _headerH = 128;
const double _nodeGap = 92;
const double _connectorH = 44;

double _pathHeight(WorldDef w) => w.levelCount * _nodeGap + 24;

/// The adventure map: every world in order, with a winding path of levels.
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  final ScrollController _scroll = ScrollController();
  bool _jumped = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double _offsetFor(GameController c, WorldDef target, int levelId) {
    var y = 8.0;
    for (final w in c.registry.worlds) {
      if (w.id == target.id) {
        final first = c.registry.firstLevelId(w);
        final idx = clampI(levelId - first, 0, w.levelCount - 1);
        // nodes are laid out top-down: level 1 at the top of the path
        return y + _headerH + idx * _nodeGap - 140;
      }
      y += _headerH + (c.progression.isWorldUnlocked(w, c.data) ? _pathHeight(w) : 0) + _connectorH;
    }
    return y;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final worlds = c.registry.worlds;
    final current = c.continueLevelId;
    final currentWorld = c.registry.worldOfLevel(current) ?? worlds.first;

    if (!_jumped) {
      _jumped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final off = _offsetFor(c, currentWorld, current);
        _scroll.jumpTo(clampD(off, 0.0, _scroll.position.maxScrollExtent));
      });
    }

    return Scaffold(
      body: SkyBackground(
        palette: c.palette,
        emojis: const ['🗺️', '⭐', '🧭', '🔍', '🌈', '🎈'],
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    RoundButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Adventure Map', style: kid(26, color: Colors.white, weight: FontWeight.w900))),
                    StatChip(emoji: '⭐', value: '${c.data.totalStars}'),
                    const SizedBox(width: 6),
                    StatChip(emoji: '🪙', value: '${c.data.coins}'),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
                  itemCount: worlds.length,
                  itemBuilder: (context, i) => _WorldSection(world: worlds[i], controller: c, currentLevel: current),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldSection extends StatelessWidget {
  const _WorldSection({required this.world, required this.controller, required this.currentLevel});
  final WorldDef world;
  final GameController controller;
  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final unlocked = c.progression.isWorldUnlocked(world, c.data);
    final done = c.progression.completedIn(world, c.data);
    final stars = c.progression.starsIn(world, c.data);
    final first = c.registry.firstLevelId(world);
    final theme = world.theme;
    final isLast = c.registry.worlds.last.id == world.id;

    return Column(
      children: [
        Bouncy(
          onTap: unlocked ? null : () => _showRequirements(context),
          child: Container(
            height: _headerH - 12,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: unlocked
                    ? [lighten(theme.accent, 0.1), darken(theme.accent, 0.12)]
                    : const [Color(0xFFB9B3CC), Color(0xFF8E88A6)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: alpha(Colors.black, 0.25), blurRadius: 10, offset: const Offset(0, 6))],
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(color: alpha(Colors.white, 0.9), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(unlocked ? world.emoji : '🔒', style: const TextStyle(fontSize: 36, decoration: TextDecoration.none)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('World ${world.index + 1}', style: kid(12, color: alpha(Colors.white, 0.85))),
                      Text(world.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: kid(22, color: Colors.white, weight: FontWeight.w900)),
                      if (unlocked)
                        Row(
                          children: [
                            Text('⭐ $stars/${world.levelCount * 3}', style: kid(13, color: Colors.white)),
                            const SizedBox(width: 12),
                            Text('✅ $done/${world.levelCount}', style: kid(13, color: Colors.white)),
                          ],
                        )
                      else
                        for (final r in c.progression.missingRequirements(world, c.data))
                          Text('• $r', maxLines: 2, overflow: TextOverflow.ellipsis, style: kid(12, color: Colors.white, weight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (unlocked)
          SizedBox(
            height: _pathHeight(world),
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                final pts = <Offset>[
                  for (var i = 0; i < world.levelCount; i++)
                    Offset(w * (0.5 + 0.28 * sin(i * 1.1 + world.index)), 40 + i * _nodeGap),
                ];
                return Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _PathPainter(pts, world.theme.accent))),
                    for (var i = 0; i < world.levelCount; i++)
                      Positioned(
                        left: pts[i].dx - 40,
                        top: pts[i].dy - 40,
                        width: 80,
                        height: 90,
                        child: _LevelNode(
                          levelId: first + i,
                          number: first + i,
                          isLast: i == world.levelCount - 1,
                          controller: c,
                          isCurrent: first + i == currentLevel,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        if (!isLast)
          SizedBox(
            height: _connectorH,
            child: Center(
              child: Text('⬇️', style: TextStyle(fontSize: 26, color: alpha(Colors.white, 0.9), decoration: TextDecoration.none)),
            ),
          ),
      ],
    );
  }

  void _showRequirements(BuildContext context) {
    final c = controller;
    final reqs = c.progression.missingRequirements(world, c.data);
    c.audio.sfx(Sfx.wrong);
    infoDialog(
      context,
      emoji: '🔒',
      title: world.name,
      message: 'To unlock this world:\n\n${reqs.map((r) => '• $r').join('\n')}',
      ok: 'Got it',
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.pts, this.color);
  final List<Offset> pts;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final midY = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
    }
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = alpha(Colors.white, 0.35);
    canvas.drawPath(path, glow);
    // dashed line
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = alpha(darken(color, 0.15), 0.75);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final seg = m.extractPath(d, min(d + 10, m.length));
        canvas.drawPath(seg, dash);
        d += 20;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => old.pts != pts || old.color != color;
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.levelId,
    required this.number,
    required this.isLast,
    required this.controller,
    required this.isCurrent,
  });

  final int levelId;
  final int number;
  final bool isLast;
  final GameController controller;
  final bool isCurrent;

  Color _diffColor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return const Color(0xFF33C481);
      case Difficulty.medium:
        return const Color(0xFFFF9F1C);
      case Difficulty.hard:
        return const Color(0xFFFF5A8A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cfg = c.levelById(levelId);
    if (cfg == null) return const SizedBox.shrink();
    final unlocked = c.progression.isLevelUnlocked(levelId, c.data);
    final stars = c.data.stars[levelId] ?? 0;
    final done = stars > 0;
    final base = unlocked ? _diffColor(cfg.difficulty) : const Color(0xFFB9B3CC);

    Widget node = Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lighten(base, 0.25), base],
        ),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(color: darken(base, 0.3), offset: const Offset(0, 4)),
          BoxShadow(color: alpha(Colors.black, 0.2), blurRadius: 8, offset: const Offset(0, 7)),
        ],
      ),
      alignment: Alignment.center,
      child: unlocked
          ? Text(isLast ? '🏁' : '$number', style: kid(isLast ? 26 : 22, color: Colors.white, weight: FontWeight.w900))
          : const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
    );

    if (isCurrent && unlocked) {
      node = _Bob(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            node,
            Positioned(
              top: -34,
              child: Mascot(emoji: c.characterEmoji, hat: c.hatEmoji, size: 30),
            ),
          ],
        ),
      );
    }

    return Bouncy(
      onTap: () {
        if (!unlocked) {
          c.audio.sfx(Sfx.wrong);
          showSnack(context, number == 1 ? 'Unlock this world first!' : 'Finish level ${number - 1} first!');
          return;
        }
        c.audio.sfx(Sfx.tap);
        openLevel(context, cfg);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 2),
          node,
          const SizedBox(height: 4),
          if (unlocked)
            StarRow(stars: stars, size: 16, gap: 0)
          else
            const SizedBox(height: 16),
          if (done && stars < 3)
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _Bob extends StatefulWidget {
  const _Bob({required this.child});
  final Widget child;

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)), child: child),
      child: widget.child,
    );
  }
}
