import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_objects/data/level_repository.dart';
import 'package:hidden_objects/data/worlds/worlds.dart';
import 'package:hidden_objects/engine/level_session.dart';
import 'package:hidden_objects/engine/progression.dart';
import 'package:hidden_objects/models/player_data.dart';
import 'package:hidden_objects/models/world_def.dart';

void main() {
  final registry = WorldRegistry();
  final repo = LevelRepository(registry);

  test('there are 10 worlds and at least 100 levels', () {
    expect(registry.worlds.length, 10);
    expect(registry.totalLevels, greaterThanOrEqualTo(100));
  });

  test('every level is valid and solvable by construction', () {
    for (var id = 1; id <= registry.totalLevels; id++) {
      final cfg = repo.byId(id);
      expect(cfg, isNotNull, reason: 'level $id missing');
      final c = cfg!;
      final world = registry.byId(c.worldId);
      final byItem = {for (final i in world.items) i.id: i};
      final propIds = {for (final p in world.props) p.id};

      // Difficulty bands.
      final n = c.targets.length;
      switch (c.difficulty) {
        case Difficulty.easy:
          expect(n, inInclusiveRange(5, 7), reason: 'level $id easy count');
          break;
        case Difficulty.medium:
          expect(n, inInclusiveRange(7, 10), reason: 'level $id medium count');
          break;
        case Difficulty.hard:
          expect(n, inInclusiveRange(10, 15), reason: 'level $id hard count');
          break;
      }

      // Items exist, no duplicates.
      final all = c.sceneItemIds;
      expect(all.toSet().length, all.length, reason: 'level $id duplicate items');
      for (final t in all) {
        expect(byItem.containsKey(t), isTrue, reason: 'level $id unknown item $t');
      }

      // Anything hidden inside a prop needs that prop to be interactive.
      for (final t in all) {
        final h = byItem[t]!.hiddenIn;
        if (h != null) {
          expect(propIds.contains(h), isTrue, reason: 'level $id prop $h missing');
          expect(c.activeProps.contains(h), isTrue, reason: 'level $id: $t hidden in inactive $h');
        }
      }

      // Locks: unlocking item exists and the dependency chain has no cycle.
      for (final e in c.locks.entries) {
        expect(c.activeProps.contains(e.key), isTrue, reason: 'level $id lock on inactive ${e.key}');
        expect(all.contains(e.value), isTrue, reason: 'level $id lock item ${e.value} absent');
      }
      for (final start in c.locks.keys) {
        var prop = start;
        final seen = <String>{};
        while (c.locks.containsKey(prop)) {
          expect(seen.add(prop), isTrue, reason: 'level $id lock cycle at $prop');
          final need = c.locks[prop]!;
          final inside = byItem[need]!.hiddenIn;
          if (inside == null) break;
          prop = inside;
        }
      }

      // Scene builds and session can start.
      final s = LevelSession(c, world);
      expect(s.layout.items.length, greaterThanOrEqualTo(n), reason: 'level $id layout');
    }
  });

  test('level 1 is the tutorial', () {
    final c = repo.byId(1)!;
    expect(c.tutorial, isTrue);
    expect(c.targets.length, inInclusiveRange(5, 7));
  });

  test('explorer level curve is monotonic', () {
    var last = 0;
    for (var xp = 0; xp < 20000; xp += 50) {
      final l = Progression.explorerLevel(xp);
      expect(l, greaterThanOrEqualTo(last));
      last = l;
    }
    expect(Progression.explorerLevel(0), 1);
  });

  test('world unlock and sequential level unlock', () {
    final p = Progression(registry);
    final d = PlayerData();
    final first = registry.worlds.first;
    final second = registry.worlds[1];
    expect(p.isWorldUnlocked(first, d), isTrue);
    expect(p.isWorldUnlocked(second, d), isFalse);
    expect(p.isLevelUnlocked(1, d), isTrue);
    expect(p.isLevelUnlocked(2, d), isFalse);
    d.stars[1] = 3;
    expect(p.isLevelUnlocked(2, d), isTrue);
  });

  test('player data survives a JSON round trip', () {
    final d = PlayerData()
      ..coins = 123
      ..xp = 456
      ..stars[5] = 2;
    final r = PlayerData.fromJson(d.toJson());
    expect(r.coins, 123);
    expect(r.xp, 456);
    expect(r.stars[5], 2);
  });
}
