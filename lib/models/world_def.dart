import 'dart:ui';

/// Logical size of every scene, in "scene units". Scenes are portrait-ish so
/// they fit a phone; larger scenes are explored with zoom + pan.
const double kSceneW = 600;
const double kSceneH = 760;

enum Difficulty { easy, medium, hard }

enum PropKind {
  decor, // static scenery (never interactive)
  curtain, // slides apart, item is behind it
  cupboard, // doors swing open, item pops in
  drawer, // drawer slides out, item pops in
  toybox, // lid lifts, item pops in
  book, // book opens, item pops in
  plant, // leaves sway aside, item is behind it
  lamp, // lamp turns on, item appears in the light
  clock, // just wiggles - teaches "not everything has a secret"
  movable, // slides away, item is beneath it
  dark, // dark area, lit up once its required item is found
}

extension PropKindX on PropKind {
  /// Can this kind hide an item?
  bool get isContainer =>
      this != PropKind.decor && this != PropKind.clock;

  /// Hidden item appears (pops in) on top when opened.
  bool get popsIn =>
      this == PropKind.cupboard ||
      this == PropKind.drawer ||
      this == PropKind.toybox ||
      this == PropKind.book ||
      this == PropKind.lamp;

  /// Hidden item is drawn beneath the prop and is uncovered when opened.
  bool get revealsBehind =>
      this == PropKind.curtain ||
      this == PropKind.plant ||
      this == PropKind.movable ||
      this == PropKind.dark;

  bool get isInteractive => this != PropKind.decor;
}

enum SceneStyle { room, outdoor, sea, space, castle }

enum FloorPattern { planks, checker, stripes }

class WorldTheme {
  const WorldTheme({
    required this.style,
    required this.skyTop,
    required this.skyBottom,
    required this.groundA,
    required this.groundB,
    required this.accent,
    this.floor = FloorPattern.planks,
  });

  final SceneStyle style;
  final Color skyTop;
  final Color skyBottom;
  final Color groundA;
  final Color groundB;
  final Color accent;
  final FloorPattern floor;
}

/// Geometry of the 8 furniture slots shared by every world (normalised
/// centre + size in scene units). Sharing slots keeps every scene balanced
/// and guarantees objects never overlap by accident.
class SlotGeom {
  const SlotGeom(this.x, this.y, this.size);
  final double x;
  final double y;
  final double size;
}

/// Placement cells for loose objects, in normalised scene coordinates.
class Cells {
  static const Map<String, SlotGeom> slots = {
    'A': SlotGeom(0.22, 0.20, 170),
    'B': SlotGeom(0.78, 0.22, 150),
    'C': SlotGeom(0.25, 0.56, 190),
    'D': SlotGeom(0.75, 0.56, 170),
    'E': SlotGeom(0.20, 0.86, 130),
    'F': SlotGeom(0.80, 0.86, 130),
    'G': SlotGeom(0.50, 0.72, 120),
    'H': SlotGeom(0.50, 0.12, 90),
  };

  /// Free cells: fully visible spots.
  static const Map<String, Offset> free = {
    'f1': Offset(0.55, 0.32),
    'f2': Offset(0.08, 0.38),
    'f3': Offset(0.92, 0.40),
    'f4': Offset(0.47, 0.42),
    'f5': Offset(0.62, 0.40),
    'f6': Offset(0.07, 0.73),
    'f7': Offset(0.93, 0.73),
    'f8': Offset(0.50, 0.56),
    'f11': Offset(0.42, 0.93),
    'f12': Offset(0.58, 0.93),
    'f13': Offset(0.39, 0.25),
    'f14': Offset(0.61, 0.22),
    'f15': Offset(0.94, 0.10),
    'f16': Offset(0.06, 0.08),
    'f17': Offset(0.25, 0.39),
    'f18': Offset(0.75, 0.38),
  };

  /// Behind cells: partially covered by the furniture in that slot.
  static const Map<String, Offset> behind = {
    'bA': Offset(0.33, 0.27),
    'bB': Offset(0.68, 0.28),
    'bC': Offset(0.38, 0.62),
    'bD': Offset(0.63, 0.63),
    'bE': Offset(0.29, 0.90),
    'bF': Offset(0.71, 0.90),
    'bG': Offset(0.50, 0.79),
  };
}

/// A piece of furniture / scenery. May be interactive.
class PropDef {
  PropDef(
    this.id,
    this.kind, {
    String? slot,
    Offset? at,
    double? size,
    this.emoji = '',
    this.openEmoji = '',
    this.name = '',
    this.color = 0xFFC8925B,
  })  : pos = at ??
            Offset(Cells.slots[slot]!.x, Cells.slots[slot]!.y),
        size = size ?? Cells.slots[slot]!.size;

  final String id;
  final PropKind kind;
  final Offset pos; // normalised
  final double size; // scene units
  final String emoji;
  final String openEmoji;
  final String name;
  final int color;
}

/// A findable object (or decoy) in a world's pool.
class ItemDef {
  const ItemDef(
    this.id,
    this.emoji,
    this.name, {
    this.cell,
    this.hiddenIn,
    this.size = 78,
  });

  final String id;
  final String emoji;
  final String name;

  /// Key in [Cells.free] or [Cells.behind]; null when hidden in a prop.
  final String? cell;

  /// Id of the prop hiding this item.
  final String? hiddenIn;
  final double size;

  bool get isBehind => cell != null && cell!.startsWith('b');
  bool get isHidden => hiddenIn != null;
  bool get isFree => cell != null && cell!.startsWith('f');

  Offset get normPos => isBehind ? Cells.behind[cell]! : (Cells.free[cell] ?? const Offset(0.5, 0.5));
}

/// A themed world (10 levels by default). Adding a new world = adding a
/// WorldDef to the registry - no engine changes required.
class WorldDef {
  WorldDef({
    required this.id,
    required this.index,
    required this.name,
    required this.emoji,
    required this.blurb,
    required this.theme,
    required this.musicId,
    required this.props,
    required this.items,
    this.requiredExplorerLevel = 1,
    this.levelCount = 10,
    this.similar = const [],
  });

  final String id;
  final int index;
  final String name;
  final String emoji;
  final String blurb;
  final WorldTheme theme;
  final String musicId;
  final List<PropDef> props;
  final List<ItemDef> items;
  final int requiredExplorerLevel;
  final int levelCount;

  /// Pairs of item ids that look alike (used by hard levels).
  final List<List<String>> similar;

  // Role ids shared by every world so mystery chains are data driven.
  static const String keyItem = 'key';
  static const String lightItem = 'light';
  static const String lootItem = 'loot';
  static const String lockedProp = 'cupboard';
  static const String darkProp = 'dark';

  PropDef? propById(String id) {
    for (final p in props) {
      if (p.id == id) return p;
    }
    return null;
  }

  ItemDef? itemById(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  bool get supportsChains =>
      propById(lockedProp) != null &&
      propById(darkProp) != null &&
      itemById(keyItem) != null &&
      itemById(lightItem) != null &&
      itemById(lootItem) != null;
}
