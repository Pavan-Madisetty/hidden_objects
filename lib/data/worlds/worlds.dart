import '../../models/world_def.dart';
import 'world_01_bedroom.dart';
import 'world_02_kitchen.dart';
import 'world_03_school.dart';
import 'world_04_playground.dart';
import 'world_05_farm.dart';
import 'world_06_zoo.dart';
import 'world_07_pirate.dart';
import 'world_08_forest.dart';
import 'world_09_space.dart';
import 'world_10_castle.dart';

/// Registry of every world. To add a world: create a `buildXxx(index)` and
/// append it here (and give it music in audio_catalog.dart).
class WorldRegistry {
  WorldRegistry([List<WorldDef>? custom]) {
    final builders = <WorldDef Function(int)>[
      buildBedroom,
      buildKitchen,
      buildSchool,
      buildPlayground,
      buildFarm,
      buildZoo,
      buildPirate,
      buildForest,
      buildSpace,
      buildCastle,
    ];
    for (var i = 0; i < builders.length; i++) {
      worlds.add(builders[i](i));
    }
    if (custom != null) {
      for (final w in custom) {
        worlds.add(w);
      }
    }
  }

  final List<WorldDef> worlds = [];

  WorldDef byId(String id) =>
      worlds.firstWhere((w) => w.id == id, orElse: () => worlds.first);

  WorldDef? maybeById(String id) {
    for (final w in worlds) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Global id of the first level in [w] (levels are numbered 1..N in order).
  int firstLevelId(WorldDef w) {
    var id = 1;
    for (final x in worlds) {
      if (x.id == w.id) return id;
      id += x.levelCount;
    }
    return id;
  }

  int get totalLevels => worlds.fold(0, (a, w) => a + w.levelCount);

  WorldDef? worldOfLevel(int levelId) {
    var start = 1;
    for (final w in worlds) {
      if (levelId >= start && levelId < start + w.levelCount) return w;
      start += w.levelCount;
    }
    return null;
  }
}
