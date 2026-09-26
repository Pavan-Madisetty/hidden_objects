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
    final problems = <String>[];
    void check(bool ok, String msg) {
      if (!ok) problems.add(msg);
    }

    for (var id = 1; id <= registry.totalLevels; id++) {
      final cfg = repo.byId(id);
      if (cfg == null) {
        problems.add('level $id missing');
        continue;
      }
      final c = cfg;
      final world = registry.byId(c.worldId);
      final byItem = {for (final i in world.items) i.id: i};
      final propIds = {for (final p in world.props) p.id};

      final n = c.targets.length;
      switch (c.difficulty) {
        case Difficulty.easy:
          check(n >= 5 && n <= 7, 'level $id easy has $n targets (want 5-7)');
          break;
        case Difficulty.medium:
          check(n >= 7 && n <= 10, 'level $id medium has $n targets (want 7-10)');
          break;
        case Difficulty.hard:
          check(n >= 10 && n <= 15, 'level $id hard has $n targets (want 10-15)');
          break;
      }

      final all = c.sceneItemIds;
      check(all.toSet().length == all.length, 'level $id has duplicate items');
      var known = true;
      for (final t in all) {
        if (!byItem.containsKey(t)) {
          known = false;
          problems.add('level $id unknown item $t');
        }
      }
      if (!known) continue;

      for (final t in all) {
        final h = byItem[t]!.hiddenIn;
        if (h != null) {
          check(propIds.contains(h), 'level $id: prop $h missing for $t');
          check(c.activeProps.contains(h), 'level $id: $t hidden in inactive prop $h');
        }
      }

      for (final e in c.locks.entries) {
        check(c.activeProps.contains(e.key), 'level $id: lock on inactive prop ${e.key}');
        check(all.contains(e.value), 'level $id: lock item ${e.value} absent from scene');
      }
      for (final start in c.locks.keys) {
        var prop = start;
        final seen = <String>{};
        while (c.locks.containsKey(prop)) {
          if (!seen.add(prop)) {
            problems.add('level $id: lock cycle at $prop');
            break;
          }
          final need = c.locks[prop]!;
          final inside = byItem[need]?.hiddenIn;
          if (inside == null) break;
          prop = inside;
        }
      }

      try {
        final s = LevelSession(c, world);
        check(s.layout.items.length >= n, 'level $id: layout has fewer items than targets');
      } catch (e) {
        problems.add('level $id: session build threw $e');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
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
