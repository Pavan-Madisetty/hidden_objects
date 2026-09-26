import 'dart:convert';

import '../models/level_config.dart';
import '../models/world_def.dart';
import 'level_generator.dart';
import 'worlds/worlds.dart';

/// A provider of level configurations. Add new sources (JSON packs, remote
/// content, hand-authored lists) without touching the engine.
abstract class LevelSource {
  LevelConfig? tryBuild(int levelId, WorldRegistry registry);
}

/// Hand-authored levels which take priority over the generator.
class HandAuthoredSource implements LevelSource {
  HandAuthoredSource(this._levels);
  final Map<int, LevelConfig> _levels;

  @override
  LevelConfig? tryBuild(int levelId, WorldRegistry registry) => _levels[levelId];
}

/// Generates levels from world data + the mechanics curve.
class ProceduralLevelSource implements LevelSource {
  const ProceduralLevelSource([this.generator = const LevelGenerator()]);
  final LevelGenerator generator;

  @override
  LevelConfig? tryBuild(int levelId, WorldRegistry registry) {
    final world = registry.worldOfLevel(levelId);
    if (world == null) return null;
    final idx = levelId - registry.firstLevelId(world);
    return generator.standard(world, idx, levelId);
  }
}

/// Levels described as JSON, e.g. downloaded content packs:
/// `[{"id":101,"world":"bedroom","title":"Bonus","difficulty":"easy",
///    "targets":["teddy","apple"],"decoys":["cap"]}]`
class JsonLevelSource implements LevelSource {
  JsonLevelSource(String json) {
    final data = jsonDecode(json);
    if (data is List) {
      for (final e in data) {
        if (e is Map<String, dynamic>) {
          final c = LevelConfig.fromJson(e);
          _levels[c.id] = c;
        }
      }
    }
  }

  final Map<int, LevelConfig> _levels = {};

  @override
  LevelConfig? tryBuild(int levelId, WorldRegistry registry) => _levels[levelId];
}

class LevelRepository {
  LevelRepository(this.registry, {List<LevelSource>? sources})
      : sources = sources ?? [HandAuthoredSource(_handAuthored(registry)), const ProceduralLevelSource()];

  final WorldRegistry registry;

  /// Highest priority first.
  final List<LevelSource> sources;
  final Map<int, LevelConfig> _cache = {};

  int get totalLevels => registry.totalLevels;

  LevelConfig? byId(int id) {
    final cached = _cache[id];
    if (cached != null) return cached;
    for (final s in sources) {
      final c = s.tryBuild(id, registry);
      if (c != null) {
        _cache[id] = c;
        return c;
      }
    }
    return null;
  }

  LevelConfig? next(int id) => byId(id + 1);

  List<LevelConfig> levelsOf(WorldDef w) {
    final first = registry.firstLevelId(w);
    return [
      for (var i = 0; i < w.levelCount; i++)
        if (byId(first + i) != null) byId(first + i)!,
    ];
  }

  /// Level 1 is hand-authored so the very first minute is perfectly tuned:
  /// five big, friendly objects and an on-screen demonstration.
  static Map<int, LevelConfig> _handAuthored(WorldRegistry reg) {
    return {
      1: const LevelConfig(
        id: 1,
        worldId: 'bedroom',
        indexInWorld: 0,
        title: 'My Bedroom 1',
        difficulty: Difficulty.easy,
        targets: ['teddy', 'apple', 'balloon', 'duck', 'cookie'],
        decoys: ['cap', 'crayon', 'rocket'],
        sizeMul: 1.3,
        parTimeSec: 60,
        tutorial: true,
      ),
    };
  }
}
