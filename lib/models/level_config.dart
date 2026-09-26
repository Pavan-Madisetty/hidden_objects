import 'world_def.dart';

/// Pure data describing one playable level. Levels can be produced by the
/// procedural generator, loaded from JSON, or hand-written - the engine only
/// ever sees a [LevelConfig].
class LevelConfig {
  const LevelConfig({
    required this.id,
    required this.worldId,
    required this.indexInWorld,
    required this.title,
    required this.difficulty,
    required this.targets,
    this.decoys = const [],
    this.bonus = const [],
    this.activeProps = const {},
    this.locks = const {},
    this.rooms = const {},
    this.roomCount = 1,
    this.sizeMul = 1.0,
    this.initialZoom = 1.0,
    this.timeLimitSec,
    this.parTimeSec = 60,
    this.introKey,
    this.tutorial = false,
    this.musicId,
    this.isDaily = false,
    this.isBonus = false,
    this.rewardMultiplier = 1,
  });

  /// Global 1-based level number. Special levels use ids >= 9000.
  final int id;
  final String worldId;
  final int indexInWorld;
  final String title;
  final Difficulty difficulty;

  /// Item ids that must be found.
  final List<String> targets;

  /// Item ids that are shown but are not needed.
  final List<String> decoys;

  /// Optional bonus objectives (extra coins).
  final List<String> bonus;

  /// Props that are interactive in this level.
  final Set<String> activeProps;

  /// propId -> itemId that must be found before the prop can be opened.
  final Map<String, String> locks;

  /// prop/item id -> room index (multi-room levels).
  final Map<String, int> rooms;
  final int roomCount;

  /// Multiplier applied to loose-object sizes (smaller = harder).
  final double sizeMul;

  /// 1.0 = whole scene visible. >1 starts zoomed in (pan to explore).
  final double initialZoom;
  final int? timeLimitSec;
  final int parTimeSec;
  final String? introKey;
  final bool tutorial;
  final String? musicId;
  final bool isDaily;
  final bool isBonus;
  final int rewardMultiplier;

  bool get isTimed => timeLimitSec != null;
  bool get hasChain => locks.isNotEmpty;

  /// Ids of every item present in the scene.
  List<String> get sceneItemIds => [...targets, ...decoys, ...bonus];

  Map<String, dynamic> toJson() => {
        'id': id,
        'world': worldId,
        'index': indexInWorld,
        'title': title,
        'difficulty': difficulty.name,
        'targets': targets,
        'decoys': decoys,
        'bonus': bonus,
        'activeProps': activeProps.toList(),
        'locks': locks,
        'rooms': rooms,
        'roomCount': roomCount,
        'sizeMul': sizeMul,
        'zoom': initialZoom,
        'timeLimit': timeLimitSec,
        'par': parTimeSec,
        'intro': introKey,
        'tutorial': tutorial,
        'music': musicId,
        'daily': isDaily,
        'bonusLevel': isBonus,
        'rewardMul': rewardMultiplier,
      };

  factory LevelConfig.fromJson(Map<String, dynamic> j) {
    List<String> strs(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : <String>[];
    Map<String, T> mapOf<T>(dynamic v, T Function(dynamic) conv) {
      final out = <String, T>{};
      if (v is Map) {
        v.forEach((k, val) => out[k.toString()] = conv(val));
      }
      return out;
    }

    return LevelConfig(
      id: (j['id'] as num).toInt(),
      worldId: j['world'] as String,
      indexInWorld: (j['index'] as num?)?.toInt() ?? 0,
      title: (j['title'] as String?) ?? 'Level ${j['id']}',
      difficulty: Difficulty.values.firstWhere(
        (d) => d.name == j['difficulty'],
        orElse: () => Difficulty.easy,
      ),
      targets: strs(j['targets']),
      decoys: strs(j['decoys']),
      bonus: strs(j['bonus']),
      activeProps: strs(j['activeProps']).toSet(),
      locks: mapOf<String>(j['locks'], (v) => v.toString()),
      rooms: mapOf<int>(j['rooms'], (v) => (v as num).toInt()),
      roomCount: (j['roomCount'] as num?)?.toInt() ?? 1,
      sizeMul: (j['sizeMul'] as num?)?.toDouble() ?? 1.0,
      initialZoom: (j['zoom'] as num?)?.toDouble() ?? 1.0,
      timeLimitSec: (j['timeLimit'] as num?)?.toInt(),
      parTimeSec: (j['par'] as num?)?.toInt() ?? 60,
      introKey: j['intro'] as String?,
      tutorial: (j['tutorial'] as bool?) ?? false,
      musicId: j['music'] as String?,
      isDaily: (j['daily'] as bool?) ?? false,
      isBonus: (j['bonusLevel'] as bool?) ?? false,
      rewardMultiplier: (j['rewardMul'] as num?)?.toInt() ?? 1,
    );
  }
}
