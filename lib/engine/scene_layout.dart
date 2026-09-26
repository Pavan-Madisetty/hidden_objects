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

/// Turns (world data + level config) into concrete positions.
class SceneLayout {
  SceneLayout._(this.props, this.items);

  final List<PlacedProp> props;
  final List<PlacedItem> items;

  factory SceneLayout.build(WorldDef world, LevelConfig cfg) {
    final rooms = max(1, cfg.roomCount);
    Offset place(Offset norm, int room) {
      final x = norm.dx * kSceneW;
      return Offset(room == 1 ? kSceneW - x : x, norm.dy * kSceneH);
    }

    final props = <PlacedProp>[];
    for (final def in world.props) {
      final isDark = def.kind == PropKind.dark;
      if (isDark && !cfg.activeProps.contains(def.id)) continue;
      final active = def.kind.isInteractive && cfg.activeProps.contains(def.id);
      final pinned = rooms > 1 && active && def.kind.isContainer;
      if (pinned) {
        final r = clampI(cfg.rooms[def.id] ?? 0, 0, rooms - 1);
        props.add(PlacedProp(
          def: def,
          pos: place(def.pos, r),
          size: def.size,
          room: r,
          active: true,
        ));
      } else {
        for (var r = 0; r < rooms; r++) {
          props.add(PlacedProp(
            def: def,
            pos: place(def.pos, r),
            size: def.size,
            room: r,
            active: active,
          ));
        }
      }
    }

    final items = <PlacedItem>[];
    final ids = cfg.sceneItemIds.toSet();
    for (final def in world.items) {
      if (!ids.contains(def.id)) continue;
      final r = rooms > 1 ? clampI(cfg.rooms[def.id] ?? 0, 0, rooms - 1) : 0;
      Offset norm;
      if (def.hiddenIn != null) {
        final p = world.propById(def.hiddenIn!);
        if (p == null) continue;
        norm = p.pos;
        if (p.kind == PropKind.lamp) norm = Offset(norm.dx, norm.dy + 0.10);
      } else {
        norm = def.normPos;
      }
      final mul = def.isHidden ? clampD(cfg.sizeMul, 0.85, 1.2) : cfg.sizeMul;
      items.add(PlacedItem(
        def: def,
        pos: place(norm, r),
        size: def.size * mul,
        room: r,
        isTarget: cfg.targets.contains(def.id),
        isBonus: cfg.bonus.contains(def.id),
      ));
    }
    return SceneLayout._(props, items);
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
