import 'dart:math';

import '../core/utils.dart';
import '../models/level_config.dart';
import '../models/world_def.dart';

/// Which game mechanics are switched on for a level. This is the single place
/// that describes the difficulty curve - change it (or ignore it and supply
/// your own [LevelConfig]s) without touching the engine.
class Mechanics {
  const Mechanics({
    this.kinds = const {},
    this.hiddenMin = 0,
    this.hiddenMax = 0,
    this.hiddenFrac = 0,
    this.behindMin = 0,
    this.behindMax = 0,
    this.zoom = 1.0,
    this.rooms = 1,
    this.chain = 0,
    this.timed = false,
    this.bonus = 0,
    this.intro,
  });

  /// Interactive prop kinds enabled.
  final Set<PropKind> kinds;
  final int hiddenMin;
  final int hiddenMax;
  final double hiddenFrac;
  final int behindMin;
  final int behindMax;
  final double zoom;
  final int rooms;

  /// 0 = none, 1 = key -> cupboard -> light, 2 = key -> cupboard -> light -> dark area -> loot
  final int chain;
  final bool timed;
  final int bonus;
  final String? intro;
}

const Set<PropKind> _tapKinds = {PropKind.clock, PropKind.plant};
const Set<PropKind> _hideKinds = {
  PropKind.clock,
  PropKind.plant,
  PropKind.curtain,
  PropKind.lamp,
  PropKind.book,
};
const Set<PropKind> _openKinds = {
  ..._hideKinds,
  PropKind.cupboard,
  PropKind.drawer,
  PropKind.toybox,
};
const Set<PropKind> _allKinds = {..._openKinds, PropKind.movable};

Difficulty difficultyForLevel(int n) {
  if (n <= 12) return Difficulty.easy;
  if (n <= 50) return Difficulty.medium;
  return Difficulty.hard;
}

/// Number of objects to find: easy 5-7, medium 7-10, hard 10-15.
int objectCountForLevel(int n) {
  if (n <= 12) return 5 + (n - 1) ~/ 5;
  if (n <= 50) return 7 + ((n - 13) * 4) ~/ 38;
  return min(15, 10 + ((n - 51) * 5) ~/ 49);
}

double _lerp(double a, double b, double t) => a + (b - a) * clampD(t, 0.0, 1.0);

double sizeMulForLevel(int n) {
  if (n <= 12) return _lerp(1.2, 1.05, (n - 1) / 11);
  if (n <= 50) return _lerp(0.95, 0.78, (n - 13) / 37);
  return _lerp(0.72, 0.6, (n - 51) / 49);
}

int parTimeFor(Difficulty d, int count) {
  switch (d) {
    case Difficulty.easy:
      return 9 * count + 15;
    case Difficulty.medium:
      return 12 * count + 25;
    case Difficulty.hard:
      return 15 * count + 35;
  }
}

/// The progressive-mechanics curve: one new idea per world, introduced gently.
Mechanics mechanicsFor(int worldIndex, int i) {
  switch (worldIndex) {
    case 0: // basic discovery, then "tap things that move"
      return Mechanics(
        kinds: i >= 8 ? _tapKinds : (i >= 5 ? {PropKind.clock} : <PropKind>{}),
        intro: i == 5 ? 'tap' : null,
      );
    case 1: // partially hidden objects, then first containers
      return Mechanics(
        kinds: i >= 5 ? _hideKinds : _tapKinds,
        behindMin: i == 0 ? 1 : 0,
        behindMax: min(3, 1 + i ~/ 3),
        hiddenMin: i >= 5 ? 1 : 0,
        hiddenMax: i >= 8 ? 2 : (i >= 5 ? 1 : 0),
        intro: i == 0 ? 'behind' : (i == 5 ? 'hidden' : null),
      );
    case 2: // zoom and pan
      return Mechanics(
        kinds: _hideKinds,
        behindMin: 1,
        behindMax: 3,
        hiddenMin: 1,
        hiddenMax: 2,
        zoom: 1.35 + i * 0.07,
        intro: i == 0 ? 'zoom' : null,
      );
    case 3: // drawers and cupboards
      return Mechanics(
        kinds: _openKinds,
        behindMin: 1,
        behindMax: 3,
        hiddenMin: 2,
        hiddenMax: i >= 5 ? 4 : 3,
        zoom: 1.3,
        intro: i == 0 ? 'open' : null,
      );
    case 4: // moving objects
      return Mechanics(
        kinds: _allKinds,
        behindMin: 1,
        behindMax: 3,
        hiddenMin: 2,
        hiddenMax: 4,
        zoom: 1.25,
        intro: i == 0 ? 'move' : null,
      );
    case 5: // multiple rooms
      return Mechanics(
        kinds: _allKinds,
        behindMin: 1,
        behindMax: 3,
        hiddenMin: 2,
        hiddenMax: 4,
        rooms: 2,
        intro: i == 0 ? 'rooms' : null,
      );
    case 6: // objects hidden behind interactive elements
      return Mechanics(
        kinds: _allKinds,
        behindMax: 2,
        hiddenMin: 3,
        hiddenFrac: 0.5,
        hiddenMax: 6,
        zoom: 1.2,
        intro: i == 0 ? 'secrets' : null,
      );
    case 7: // simple multi-step puzzles
      return Mechanics(
        kinds: _allKinds,
        behindMax: 2,
        hiddenMin: 1,
        hiddenMax: 3,
        chain: i == 0 ? 0 : (i < 5 ? 1 : 2),
        zoom: 1.15,
        intro: i == 1 ? 'chain' : null,
      );
    case 8: // timed challenges and bonus objectives
      return Mechanics(
        kinds: _allKinds,
        behindMax: 3,
        hiddenMin: 1,
        hiddenMax: 3,
        chain: i >= 5 ? 1 : 0,
        timed: true,
        bonus: 1,
        intro: i == 0 ? 'timed' : null,
      );
    default: // multi-step mystery levels combining everything
      return Mechanics(
        kinds: _allKinds,
        behindMax: 3,
        hiddenMin: 1,
        hiddenFrac: 0.4,
        hiddenMax: 6,
        rooms: 2,
        chain: i < 2 ? 1 : 2,
        bonus: i.isOdd ? 1 : 0,
        zoom: 1.2,
        intro: i == 0 ? 'mystery' : null,
      );
  }
}

class LevelGenerator {
  const LevelGenerator();

  /// Builds the config for the standard level [levelId] (1-based) whose
  /// position inside [world] is [idx].
  LevelConfig standard(WorldDef world, int idx, int levelId) {
    final diff = difficultyForLevel(levelId);
    var count = objectCountForLevel(levelId);
    // Gentle start in each new world, but never below the difficulty band.
    final bandMin = diff == Difficulty.easy ? 5 : (diff == Difficulty.medium ? 7 : 10);
    if (idx == 0 && count - 1 >= bandMin) count -= 1;
    final m = mechanicsFor(world.index, idx);
    return generate(
      world: world,
      idx: idx,
      levelId: levelId,
      diff: diff,
      count: count,
      m: m,
      sizeMul: sizeMulForLevel(levelId),
      title: '${world.name} ${idx + 1}',
    );
  }

  LevelConfig generate({
    required WorldDef world,
    required int idx,
    required int levelId,
    required Difficulty diff,
    required int count,
    required Mechanics m,
    required double sizeMul,
    required String title,
    int? seed,
    bool isDaily = false,
    bool isBonus = false,
    String? musicId,
    int rewardMultiplier = 1,
    bool forceTimed = false,
  }) {
    final rng = Rng(seed ?? levelId * 7919 + 13);
    final chain = world.supportsChains ? m.chain : 0;

    bool kindOn(String propId) {
      final p = world.propById(propId);
      return p != null && m.kinds.contains(p.kind);
    }

    // ---- mystery chain (key -> cupboard -> light -> dark area -> loot) ----
    final must = <String>[];
    final locks = <String, String>{};
    if (chain >= 1) {
      must.addAll([WorldDef.keyItem, WorldDef.lightItem]);
      locks[WorldDef.lockedProp] = WorldDef.keyItem;
    }
    if (chain >= 2) {
      must.add(WorldDef.lootItem);
      locks[WorldDef.darkProp] = WorldDef.lightItem;
    }
    if (count < must.length + 2) count = must.length + 2;

    final targets = <String>[...must];
    var remaining = count - targets.length;
    final backAllowed = m.behindMax > 0;

    // ---- objects hidden inside interactive props ----
    final hiddenCands = world.items
        .where((i) =>
            i.isHidden &&
            !targets.contains(i.id) &&
            i.hiddenIn != WorldDef.darkProp &&
            (kindOn(i.hiddenIn!) || (chain >= 1 && i.hiddenIn == WorldDef.lockedProp)))
        .map((i) => i.id)
        .toList();
    var hMin = max(m.hiddenMin, (count * m.hiddenFrac).round());
    var hMax = max(m.hiddenMax, hMin);
    if (hMin > hiddenCands.length) hMin = hiddenCands.length;
    if (hMax > hiddenCands.length) hMax = hiddenCands.length;
    var hiddenCount = hMin + rng.nextInt(hMax - hMin + 1);
    hiddenCount = min(hiddenCount, remaining);
    final shuffledHidden = rng.shuffled(hiddenCands);
    final pickedHidden = shuffledHidden.take(hiddenCount).toList();
    targets.addAll(pickedHidden);
    remaining -= pickedHidden.length;

    // ---- partially hidden (behind furniture) ----
    final behindCands = backAllowed
        ? rng
            .shuffled(world.items.where((i) => i.isBehind && !targets.contains(i.id)).map((i) => i.id))
        : <String>[];
    var bMin = min(m.behindMin, behindCands.length);
    var bMax = min(m.behindMax, behindCands.length);
    if (bMax < bMin) bMax = bMin;
    var behindCount = bMin + rng.nextInt(bMax - bMin + 1);
    behindCount = min(behindCount, remaining);
    final pickedBehind = behindCands.take(behindCount).toList();
    targets.addAll(pickedBehind);
    remaining -= pickedBehind.length;

    // ---- loose objects in plain sight ----
    final freeCands = rng.shuffled(
      world.items.where((i) => i.isFree && !targets.contains(i.id)).map((i) => i.id),
    );
    final pickedFree = freeCands.take(remaining).toList();
    targets.addAll(pickedFree);
    remaining -= pickedFree.length;
    if (remaining > 0) {
      // Not enough loose objects: fall back to any remaining behind objects.
      final extra = world.items
          .where((i) => i.isBehind && !targets.contains(i.id))
          .map((i) => i.id)
          .take(remaining);
      targets.addAll(extra);
    }

    // ---- decoys ----
    final decoyPool = <String>[
      ...world.items
          .where((i) => (i.isFree || (i.isBehind && backAllowed)) && !targets.contains(i.id))
          .map((i) => i.id),
    ];
    final decoys = <String>[];

    if (diff == Difficulty.hard && world.similar.isNotEmpty) {
      final pair = rng.pick(world.similar);
      final a = world.itemById(pair[0]);
      final b = world.itemById(pair[1]);
      if (a != null && b != null && !a.isHidden && !b.isHidden) {
        final okA = !a.isBehind || backAllowed;
        final okB = !b.isBehind || backAllowed;
        if (okA && okB) {
          if (!targets.contains(a.id) && !targets.contains(b.id)) {
            // swap one plain target for pair member a
            final replaceable = targets
                .where((t) => !must.contains(t) && !(world.itemById(t)?.isHidden ?? true))
                .toList();
            if (replaceable.isNotEmpty) {
              final r = rng.pick(replaceable);
              targets[targets.indexOf(r)] = a.id;
              decoyPool.remove(a.id);
              decoyPool.add(r);
              decoys.add(b.id);
              decoyPool.remove(b.id);
            }
          } else if (targets.contains(a.id) && !targets.contains(b.id)) {
            decoys.add(b.id);
            decoyPool.remove(b.id);
          } else if (targets.contains(b.id) && !targets.contains(a.id)) {
            decoys.add(a.id);
            decoyPool.remove(a.id);
          }
        }
      }
    }

    final wantDecoys = switch (diff) {
      Difficulty.easy => 3 + idx % 3,
      Difficulty.medium => 6 + idx % 4,
      Difficulty.hard => 9 + idx % 4,
    };
    final shuffledPool = rng.shuffled(decoyPool);
    for (final d in shuffledPool) {
      if (decoys.length >= wantDecoys) break;
      decoys.add(d);
    }

    // ---- bonus objectives ----
    final bonus = <String>[];
    if (m.bonus > 0) {
      final bonusPool = rng.shuffled(
        world.items
            .where((i) =>
                (i.isFree || i.isBehind && backAllowed) &&
                !targets.contains(i.id) &&
                !decoys.contains(i.id))
            .map((i) => i.id),
      );
      for (final b in bonusPool.take(m.bonus)) {
        bonus.add(b);
      }
      // If the pool was exhausted, convert decoys into bonus items.
      while (bonus.length < m.bonus && decoys.isNotEmpty) {
        bonus.add(decoys.removeLast());
      }
    }

    // ---- active props ----
    final active = <String>{};
    for (final p in world.props) {
      if (m.kinds.contains(p.kind)) active.add(p.id);
    }
    if (chain >= 1) active.add(WorldDef.lockedProp);
    if (chain >= 2) active.add(WorldDef.darkProp);
    // Never leave a target hidden in a prop that is not interactive.
    for (final t in targets) {
      final it = world.itemById(t);
      if (it?.hiddenIn != null) active.add(it!.hiddenIn!);
    }
    final targetsInDark = targets.any((t) => world.itemById(t)?.hiddenIn == WorldDef.darkProp);
    if (targetsInDark) active.add(WorldDef.darkProp);

    // ---- rooms ----
    final rooms = <String, int>{};
    final roomCount = m.rooms;
    if (roomCount > 1) {
      var k = 0;
      for (final p in world.props) {
        if (p.kind.isContainer && active.contains(p.id)) {
          rooms[p.id] = k % roomCount;
          k++;
        }
      }
      if (locks.isNotEmpty) {
        rooms[WorldDef.lockedProp] = 1;
        rooms[WorldDef.darkProp] = 0;
      }
      final sceneItems = rng.shuffled([...targets, ...decoys, ...bonus]);
      var n = 0;
      for (final id in sceneItems) {
        final def = world.itemById(id);
        if (def == null) continue;
        if (def.isHidden) {
          rooms[id] = rooms[def.hiddenIn!] ?? 0;
        } else if (id == WorldDef.keyItem && locks.isNotEmpty) {
          rooms[id] = 0;
        } else {
          rooms[id] = n % roomCount;
          n++;
        }
      }
    }

    final par = parTimeFor(diff, targets.length);
    final timed = m.timed || forceTimed;
    return LevelConfig(
      id: levelId,
      worldId: world.id,
      indexInWorld: idx,
      title: title,
      difficulty: diff,
      targets: targets,
      decoys: decoys,
      bonus: bonus,
      activeProps: active,
      locks: locks,
      rooms: rooms,
      roomCount: roomCount,
      sizeMul: sizeMul,
      initialZoom: m.zoom,
      timeLimitSec: timed ? max(75, (par * 1.7).round()) : null,
      parTimeSec: par,
      introKey: m.intro,
      tutorial: false,
      musicId: musicId,
      isDaily: isDaily,
      isBonus: isBonus,
      rewardMultiplier: rewardMultiplier,
    );
  }
}

/// Mechanics for the Daily Mystery (a special, slightly richer scene).
Mechanics dailyMechanics(int variant) => Mechanics(
      kinds: _allKinds,
      behindMin: 1,
      behindMax: 3,
      hiddenMin: 2,
      hiddenMax: 4,
      bonus: 1,
      zoom: 1.15,
      chain: variant % 3 == 0 ? 1 : 0,
      intro: 'daily',
    );

/// Mechanics for the optional Bonus Rooms.
Mechanics bonusRoomMechanics() => Mechanics(
      kinds: _allKinds,
      behindMin: 1,
      behindMax: 3,
      hiddenMin: 2,
      hiddenMax: 4,
      bonus: 2,
      zoom: 1.1,
      intro: 'bonusRoom',
    );
