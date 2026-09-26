import 'dart:math';

import '../data/worlds/worlds.dart';
import '../models/player_data.dart';
import '../models/world_def.dart';
import '../core/utils.dart';

/// XP / Explorer level maths and world/level unlock rules.
class Progression {
  Progression(this.registry);
  final WorldRegistry registry;

  /// Total XP needed to *reach* [level] (level 1 = 0).
  static int xpToReach(int level) => 100 * (level - 1) * level ~/ 2;

  static int explorerLevel(int xp) {
    var l = 1;
    while (xp >= xpToReach(l + 1)) {
      l++;
      if (l > 200) break;
    }
    return l;
  }

  /// 0..1 progress towards the next Explorer level.
  static double levelProgress(int xp) {
    final l = explorerLevel(xp);
    final a = xpToReach(l);
    final b = xpToReach(l + 1);
    return clampD((xp - a) / max(1, b - a), 0.0, 1.0);
  }

  static int xpIntoLevel(int xp) => xp - xpToReach(explorerLevel(xp));
  static int xpForNext(int xp) {
    final l = explorerLevel(xp);
    return xpToReach(l + 1) - xpToReach(l);
  }

  /// Levels finished in [w].
  int completedIn(WorldDef w, PlayerData d) {
    final first = registry.firstLevelId(w);
    var n = 0;
    for (var i = 0; i < w.levelCount; i++) {
      if (d.completed(first + i)) n++;
    }
    return n;
  }

  int starsIn(WorldDef w, PlayerData d) {
    final first = registry.firstLevelId(w);
    var n = 0;
    for (var i = 0; i < w.levelCount; i++) {
      n += d.stars[first + i] ?? 0;
    }
    return n;
  }

  /// Levels needed in the previous world before this one opens.
  static const int kNeededInPrevious = 7;

  WorldDef? previousWorld(WorldDef w) {
    if (w.index <= 0) return null;
    final i = registry.worlds.indexWhere((x) => x.id == w.id);
    return i > 0 ? registry.worlds[i - 1] : null;
  }

  /// Does the player currently satisfy the requirements of [w]?
  bool meetsRequirements(WorldDef w, PlayerData d) {
    if (w.index == 0) return true;
    if (explorerLevel(d.xp) < w.requiredExplorerLevel) return false;
    final prev = previousWorld(w);
    if (prev == null) return true;
    return completedIn(prev, d) >= min(kNeededInPrevious, prev.levelCount);
  }

  bool isWorldUnlocked(WorldDef w, PlayerData d) =>
      d.unlockedWorlds.contains(w.id) || meetsRequirements(w, d);

  /// Human readable list of what is still missing.
  List<String> missingRequirements(WorldDef w, PlayerData d) {
    final out = <String>[];
    if (explorerLevel(d.xp) < w.requiredExplorerLevel) {
      out.add('Reach Explorer Level ${w.requiredExplorerLevel}');
    }
    final prev = previousWorld(w);
    if (prev != null) {
      final need = min(kNeededInPrevious, prev.levelCount);
      final have = completedIn(prev, d);
      if (have < need) out.add('Finish $need levels in ${prev.name} ($have/$need)');
    }
    return out;
  }

  /// Worlds that became available (and are not yet recorded as unlocked).
  List<WorldDef> newlyUnlockable(PlayerData d) => [
        for (final w in registry.worlds)
          if (!d.unlockedWorlds.contains(w.id) && meetsRequirements(w, d)) w,
      ];

  /// Sequential unlock inside a world; a world must be open first.
  bool isLevelUnlocked(int levelId, PlayerData d) {
    final w = registry.worldOfLevel(levelId);
    if (w == null) return false;
    if (!isWorldUnlocked(w, d)) return false;
    final first = registry.firstLevelId(w);
    if (levelId == first) return true;
    return d.completed(levelId - 1) || d.completed(levelId);
  }

  /// The level "Continue" should open: first unfinished level in the
  /// furthest unlocked world.
  int continueLevel(PlayerData d) {
    for (final w in registry.worlds) {
      if (!isWorldUnlocked(w, d)) break;
      final first = registry.firstLevelId(w);
      for (var i = 0; i < w.levelCount; i++) {
        if (!d.completed(first + i)) return first + i;
      }
    }
    // Everything done: replay the last level of the last unlocked world.
    return max(1, registry.totalLevels);
  }
}
