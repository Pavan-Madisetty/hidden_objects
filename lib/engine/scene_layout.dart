import 'dart:math';
import 'dart:ui';

import '../models/level_config.dart';
import '../models/world_def.dart';
import '../core/utils.dart';

/// A prop placed in the scene for one room.
class PlacedProp {
  const PlacedProp({
    required this.def,
    required this.pos,
    required this.size,
    required this.room,
    required this.active,
  });

  final PropDef def;

  /// Centre in scene units (already mirrored for room 1).
  final Offset pos;
  final double size;
  final int room;

  /// Interactive in this level.
  final bool active;

  String get id => def.id;
  PropKind get kind => def.kind;
  Rect get rect => Rect.fromCenter(center: pos, width: size, height: size);
}

/// An object placed in the scene.
class PlacedItem {
  const PlacedItem({
    required this.def,
    required this.pos,
    required this.size,
    required this.room,
    required this.isTarget,
    required this.isBonus,
  });

  final ItemDef def;
  final Offset pos;
  final double size;
  final int room;
  final bool isTarget;
  final bool isBonus;

  String get id => def.id;
  String? get hiddenIn => def.hiddenIn;
}

/// Per-level visual variation: mirrored scene, colour shift, floor pattern,
/// time-of-day tint. Derived from the level + difficulty (+ optional salt) so
/// every level - and every difficulty of the same level - looks different.
class SceneLook {
  const SceneLook({
    required this.seed,
    required this.mirror,
    required this.hue,
    required this.floorIndex,
    required this.tint,
    required this.tintAlpha,
    required this.vignette,
    required this.a,
    required this.b,
  });

  final int seed;
  final bool mirror;

  /// Hue rotation in degrees applied to the world colours.
  final double hue;
  final int floorIndex;
  final Color tint;
  final double tintAlpha;
  final double vignette;

  /// Free random numbers (0..1) for decoration placement.
  final double a;
  final double b;

  static const plain = SceneLook(
    seed: 0,
    mirror: false,
    hue: 0,
    floorIndex: -1,
    tint: Color(0x00000000),
    tintAlpha: 0,
    vignette: 0.13,
    a: 0.5,
    b: 0.5,
  );

  factory SceneLook.forSeed(int seed, Difficulty diff) {
    final r = Rng(seed ^ 0x5bd1e995);
    final Color tint;
    final double ta;
    final double vig;
    switch (diff) {
      case Difficulty.easy: // bright, sunny
        tint = const Color(0xFFFFF6D6);
        ta = 0.10;
        vig = 0.08;
        break;
      case Difficulty.medium: // golden hour
        tint = const Color(0xFFFFB35A);
        ta = 0.13;
        vig = 0.16;
        break;
      case Difficulty.hard: // dusk, moody
        tint = const Color(0xFF3B2A8F);
        ta = 0.24;
        vig = 0.30;
        break;
    }
    final sign = r.chance(0.5) ? 1.0 : -1.0;
    return SceneLook(
      seed: seed,
      mirror: r.chance(0.5),
      hue: sign * (12 + r.nextDouble() * 38),
      floorIndex: r.nextInt(FloorPattern.values.length),
      tint: tint,
      tintAlpha: ta,
      vignette: vig,
      a: r.nextDouble(),
      b: r.nextDouble(),
    );
  }
}

/// Turns (world data + level config) into concrete positions.
///
/// Nothing is placed at a fixed spot: furniture swaps sides, the whole scene
/// may be mirrored, and loose objects are scattered with a spacing rule that
/// depends on the difficulty (Hard = more cluttered, smaller gaps).
class SceneLayout {
  SceneLayout._(this.props, this.items, this.look);

  final List<PlacedProp> props;
  final List<PlacedItem> items;
  final SceneLook look;

  /// [salt] makes every attempt different (0 keeps a level reproducible, used
  /// by the tutorial, the daily challenge and tests).
  factory SceneLayout.build(WorldDef world, LevelConfig cfg, {int salt = 0}) {
    final rooms = max(1, cfg.roomCount);
    final seed = stableHash('${cfg.id}|${cfg.difficulty.name}|${cfg.targets.join(',')}') ^ (salt * 2654435761 & 0x7fffffff);
    final rng = Rng(seed);
    final look = SceneLook.forSeed(seed, cfg.difficulty);

    Offset place(Offset norm, int room) {
      final x = norm.dx * kSceneW;
      final flip = (room == 1) != look.mirror;
      return Offset(flip ? kSceneW - x : x, norm.dy * kSceneH);
    }

    // ---- furniture: swap sides + a little jitter ---------------------------
    String nearestSlot(Offset n) {
      var best = 'A';
      var bd = 1e9;
      Cells.slots.forEach((k, g) {
        final d = (g.x - n.dx) * (g.x - n.dx) + (g.y - n.dy) * (g.y - n.dy);
        if (d < bd) {
          bd = d;
          best = k;
        }
      });
      return best;
    }

    final swap = <String, String>{};
    for (final pair in const [
      ['A', 'B'],
      ['C', 'D'],
      ['E', 'F'],
    ]) {
      if (rng.chance(0.5)) {
        swap[pair[0]] = pair[1];
        swap[pair[1]] = pair[0];
      }
    }
    final slotOf = <String, String>{}; // prop id -> original slot
    final newPos = <String, Offset>{}; // prop id -> normalised position
    for (final def in world.props) {
      final from = nearestSlot(def.pos);
      slotOf[def.id] = from;
      final to = swap[from] ?? from;
      final gf = Cells.slots[from]!;
      final gt = Cells.slots[to]!;
      final jx = (rng.nextDouble() - 0.5) * 0.04;
      final jy = (rng.nextDouble() - 0.5) * 0.03;
      newPos[def.id] = Offset(
        clampD(def.pos.dx + (gt.x - gf.x) + jx, 0.1, 0.9),
        clampD(def.pos.dy + (gt.y - gf.y) + jy, 0.08, 0.92),
      );
    }

    final props = <PlacedProp>[];
    for (final def in world.props) {
      final isDark = def.kind == PropKind.dark;
      if (isDark && !cfg.activeProps.contains(def.id)) continue;
      final active = def.kind.isInteractive && cfg.activeProps.contains(def.id);
      final pinned = rooms > 1 && active && def.kind.isContainer;
      final np = newPos[def.id]!;
      if (pinned) {
        final r = clampI(cfg.rooms[def.id] ?? 0, 0, rooms - 1);
        props.add(PlacedProp(def: def, pos: place(np, r), size: def.size, room: r, active: true));
      } else {
        for (var r = 0; r < rooms; r++) {
          props.add(PlacedProp(def: def, pos: place(np, r), size: def.size, room: r, active: active));
        }
      }
    }

    // ---- items ---------------------------------------------------------------
    final ids = cfg.sceneItemIds.toSet();
    final placed = <PlacedItem>[];
    final loose = <ItemDef>[];
    final looseRoom = <String, int>{};

    // Behind / hidden items follow their furniture.
    for (final def in world.items) {
      if (!ids.contains(def.id)) continue;
      final r = rooms > 1 ? clampI(cfg.rooms[def.id] ?? 0, 0, rooms - 1) : 0;
      final mul = def.isHidden ? clampD(cfg.sizeMul, 0.85, 1.2) : cfg.sizeMul;
      Offset? norm;
      if (def.hiddenIn != null) {
        final p = world.propById(def.hiddenIn!);
        if (p == null) continue;
        final base = newPos[p.id]!;
        norm = p.kind == PropKind.lamp ? Offset(base.dx, base.dy + 0.10) : base;
      } else if (def.isBehind) {
        final key = def.cell!.substring(1); // 'bA' -> 'A'
        final g = Cells.slots[key];
        final off = Cells.behind[def.cell!]!;
        String? owner;
        slotOf.forEach((pid, sl) {
          if (sl == key && owner == null) owner = pid;
        });
        if (g != null && owner != null) {
          final base = newPos[owner!]!;
          norm = Offset(base.dx + (off.dx - g.x), base.dy + (off.dy - g.y));
        } else {
          norm = off;
        }
      }
      if (norm == null) {
        loose.add(def);
        looseRoom[def.id] = r;
        continue;
      }
      placed.add(PlacedItem(
        def: def,
        pos: place(norm, r),
        size: def.size * mul,
        room: r,
        isTarget: cfg.targets.contains(def.id),
        isBonus: cfg.bonus.contains(def.id),
      ));
    }

    // Loose objects: random scatter that avoids furniture and other objects.
    final spacing = switch (cfg.difficulty) {
      Difficulty.easy => 1.2,
      Difficulty.medium => 1.0,
      Difficulty.hard => 0.8,
    };
    final order = rng.shuffled(loose);
    for (final def in order) {
      final r = looseRoom[def.id] ?? 0;
      final size = def.size * cfg.sizeMul;
      final rad = size / 2;
      final obstacles = [
        for (final p in props)
          if (p.room == r) p.rect.inflate(6),
      ];
      final others = [
        for (final it in placed)
          if (it.room == r) it,
      ];
      Offset? best;
      var relax = 1.0;
      for (var attempt = 0; attempt < 90 && best == null; attempt++) {
        if (attempt > 0 && attempt % 30 == 0) relax *= 0.85;
        final x = 40 + rad + rng.nextDouble() * (kSceneW - 80 - 2 * rad);
        final y = kSceneH * 0.07 + rad + rng.nextDouble() * (kSceneH * 0.88 - 2 * rad);
        final c = Offset(x, y);
        var ok = true;
        for (final o in obstacles) {
          final dx = max(max(o.left - c.dx, c.dx - o.right), 0.0);
          final dy = max(max(o.top - c.dy, c.dy - o.bottom), 0.0);
          if (sqrt(dx * dx + dy * dy) < rad * relax) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        for (final it in others) {
          final need = (rad + it.size / 2) * 0.62 * spacing * relax;
          if ((it.pos - c).distance < need) {
            ok = false;
            break;
          }
        }
        if (ok) best = c;
      }
      // Fallback: the classic fixed cells (never leaves an object out).
      best ??= place(def.normPos, r);
      placed.add(PlacedItem(
        def: def,
        pos: best,
        size: size,
        room: r,
        isTarget: cfg.targets.contains(def.id),
        isBonus: cfg.bonus.contains(def.id),
      ));
    }
    // Keep the original world order (stable widget keys / tray order).
    final byId = {for (final i in placed) i.id: i};
    final items = <PlacedItem>[
      for (final d in world.items)
        if (byId.containsKey(d.id)) byId[d.id]!,
    ];
    return SceneLayout._(props, items, look);
  }

  PlacedItem? item(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  PlacedProp? prop(String id) {
    for (final p in props) {
      if (p.id == id) return p;
    }
    return null;
  }
}
