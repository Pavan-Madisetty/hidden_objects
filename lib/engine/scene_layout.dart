import 'dart:math';
import 'dart:ui';

import '../data/item_library.dart';
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

/// A wall shelf (normalised, before mirroring) that objects can sit on.
class Shelf {
  const Shelf(this.y, this.x0, this.x1);
  final double y;
  final double x0;
  final double x1;
}

/// Decorative clutter: makes the scene busy like a real "I spy" picture.
/// Never tappable and never the same picture as something you must find.
class PlacedClutter {
  const PlacedClutter({required this.emoji, required this.pos, required this.size, required this.angle, required this.room});
  final String emoji;
  final Offset pos;
  final double size;
  final double angle;
  final int room;
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
    this.shelves = const [],
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

  /// Wall shelves (drawn only in indoor worlds).
  final List<Shelf> shelves;

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
      shelves: [
        Shelf(0.29 + r.nextDouble() * 0.06, r.chance(0.5) ? 0.02 : 0.30, r.chance(0.5) ? 0.66 : 0.98),
        Shelf(0.44 + r.nextDouble() * 0.05, r.chance(0.5) ? 0.02 : 0.36, r.chance(0.5) ? 0.62 : 0.98),
      ],
    );
  }
}

/// Turns (world data + level config) into concrete positions.
///
/// Nothing is placed at a fixed spot: furniture swaps sides, the whole scene
/// may be mirrored, and loose objects are scattered with a spacing rule that
/// depends on the difficulty (Hard = more cluttered, smaller gaps).
class SceneLayout {
  SceneLayout._(this.props, this.items, this.look, this.clutter);

  final List<PlacedProp> props;
  final List<PlacedItem> items;
  final SceneLook look;
  final List<PlacedClutter> clutter;

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
    final placed = <PlacedItem>[];
    final loose = <ItemDef>[];
    final looseRoom = <String, int>{};
    final indoor = world.theme.style == SceneStyle.room;

    // Behind / hidden items follow their furniture.
    for (final id in cfg.sceneItemIds) {
      final def = world.itemById(id);
      if (def == null) continue;
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
      final flip = (r == 1) != look.mirror;
      for (var attempt = 0; attempt < 90 && best == null; attempt++) {
        if (attempt > 0 && attempt % 30 == 0) relax *= 0.85;
        double x;
        double y;
        if (indoor && attempt < 40 && rng.chance(0.4)) {
          // sit on a wall shelf
          final sh = look.shelves[rng.nextInt(look.shelves.length)];
          final bx = (sh.x0 + rng.nextDouble() * (sh.x1 - sh.x0)) * kSceneW;
          x = flip ? kSceneW - bx : bx;
          y = sh.y * kSceneH - rad * 0.85;
        } else {
          x = 40 + rad + rng.nextDouble() * (kSceneW - 80 - 2 * rad);
          y = kSceneH * 0.07 + rad + rng.nextDouble() * (kSceneH * 0.88 - 2 * rad);
        }
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
    // Keep the level's own order (tray order, stable keys).
    final byId = {for (final i in placed) i.id: i};
    final items = <PlacedItem>[
      for (final id in cfg.sceneItemIds)
        if (byId.containsKey(id)) byId[id]!,
    ];

    // ---- clutter: a busy, lived-in scene -----------------------------------------
    final clutterCount = switch (cfg.difficulty) {
      Difficulty.easy => 14,
      Difficulty.medium => 28,
      Difficulty.hard => 44,
    };
    final used = <String>{for (final i in items) i.def.emoji};
    final themed = rng.shuffled(ItemLibrary.forWorld(world.id));
    final restLib = rng.shuffled(ItemLibrary.all);
    final pool = <String>[];
    for (final d in [...themed, ...restLib]) {
      if (used.add(d.emoji)) pool.add(d.emoji);
      if (pool.length >= clutterCount * rooms) break;
    }
    final clutter = <PlacedClutter>[];
    var pi = 0;
    for (var r = 0; r < rooms; r++) {
      final flip = (r == 1) != look.mirror;
      final anchors = [
        for (final it in items)
          if (it.room == r) it,
      ];
      for (var k = 0; k < clutterCount && pi < pool.length; k++) {
        final size = 54 + rng.nextDouble() * 34;
        Offset? c;
        for (var attempt = 0; attempt < 25 && c == null; attempt++) {
          double x;
          double y;
          if (indoor && rng.chance(0.3)) {
            final sh = look.shelves[rng.nextInt(look.shelves.length)];
            final bx = (sh.x0 + rng.nextDouble() * (sh.x1 - sh.x0)) * kSceneW;
            x = flip ? kSceneW - bx : bx;
            y = sh.y * kSceneH - size * 0.42;
          } else {
            x = 30 + rng.nextDouble() * (kSceneW - 60);
            y = kSceneH * 0.05 + rng.nextDouble() * kSceneH * 0.9;
          }
          final cand = Offset(x, y);
          var ok = true;
          for (final it in anchors) {
            if ((it.pos - cand).distance < (it.size + size) * 0.3) {
              ok = false;
              break;
            }
          }
          if (ok) c = cand;
        }
        if (c == null) continue;
        clutter.add(PlacedClutter(
          emoji: pool[pi++],
          pos: c,
          size: size,
          angle: (rng.nextDouble() - 0.5) * 0.9,
          room: r,
        ));
      }
    }
    return SceneLayout._(props, items, look, clutter);
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
