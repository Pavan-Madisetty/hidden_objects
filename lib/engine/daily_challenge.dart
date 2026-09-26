import '../core/utils.dart';
import '../data/level_generator.dart';
import '../data/shop_catalog.dart';
import '../data/worlds/worlds.dart';
import '../models/level_config.dart';
import '../models/world_def.dart';

/// Builds the Daily Mystery and the Bonus Rooms. Both reuse the standard
/// generator, seeded so every player gets the same puzzle on the same day.
class DailyChallenge {
  static int levelIdFor(DateTime d) => 100000000 + int.parse(dayKey(d));

  static LevelConfig build(
    DateTime date,
    WorldRegistry registry,
    List<WorldDef> unlockedWorlds,
    int levelsCompleted,
  ) {
    final key = dayKey(date);
    final h = stableHash(key);
    final pool = unlockedWorlds.isEmpty ? [registry.worlds.first] : unlockedWorlds;
    final world = pool[h % pool.length];
    final hard = levelsCompleted >= 40;
    final diff = hard ? Difficulty.hard : Difficulty.medium;
    final count = hard ? 11 : 9;
    return const LevelGenerator().generate(
      world: world,
      idx: h % 10,
      levelId: levelIdFor(date),
      diff: diff,
      count: count,
      m: dailyMechanics(h % 7),
      sizeMul: hard ? 0.7 : 0.85,
      title: 'Daily Mystery',
      seed: h,
      isDaily: true,
      musicId: 'daily',
      forceTimed: true,
    );
  }

  static LevelConfig buildBonusRoom(BonusRoomDef def, WorldRegistry registry) {
    final world = registry.byId(def.worldId);
    return const LevelGenerator().generate(
      world: world,
      idx: def.levelId % 10,
      levelId: def.levelId,
      diff: Difficulty.medium,
      count: 9,
      m: bonusRoomMechanics(),
      sizeMul: 0.85,
      title: def.name,
      seed: def.levelId * 31 + 7,
      isBonus: true,
      musicId: 'bonus',
      rewardMultiplier: 2,
    );
  }
}

/// Forgiving daily streak: missing one day is free, missing more only halves
/// the streak instead of resetting it.
class StreakLogic {
  /// Returns the new streak value for completing today's challenge.
  static int next({required int streak, required String lastDay, required String today}) {
    if (lastDay == today) return streak;
    if (lastDay.isEmpty) return 1;
    final gap = daysBetweenKeys(lastDay, today);
    if (gap <= 2) return streak + 1; // consecutive, or one forgiven day
    return (streak ~/ 2) + 1;
  }

  /// Streak shown in the UI right now.
  static int visible({required int streak, required String lastDay, required String today}) {
    if (lastDay.isEmpty) return 0;
    final gap = daysBetweenKeys(lastDay, today);
    if (gap <= 2) return streak;
    return streak ~/ 2;
  }
}
