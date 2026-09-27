import 'dart:ui';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/level_config.dart';
import '../models/world_def.dart';
import 'scene_layout.dart';

enum TapKind {
  found,
  bonusFound,
  wrong,
  propOpened,
  propWiggle,
  propLocked,
  propDark,
}

class TapOutcome {
  const TapOutcome(
    this.kind, {
    this.item,
    this.prop,
    this.pos = Offset.zero,
    this.message = '',
    this.unlocked = const [],
    this.emptyOpen = false,
  });

  final TapKind kind;
  final PlacedItem? item;
  final PlacedProp? prop;
  final Offset pos;
  final String message;

  /// Ids of props that just became unlocked because [item] was found.
  final List<String> unlocked;

  /// A prop was opened but held nothing.
  final bool emptyOpen;
}

class HintResult {
  const HintResult(this.center, this.radius, this.room, {this.itemId, this.propId});
  final Offset center;
  final double radius;
  final int room;
  final String? itemId;
  final String? propId;
}

/// Pure game-state for one play of a level. No widgets in here, so it is easy
/// to unit-test and to reuse for any level configuration.
class LevelSession extends ChangeNotifier {
  LevelSession(this.cfg, this.world, {int salt = 0}) : layout = SceneLayout.build(world, cfg, salt: salt);

  final LevelConfig cfg;
  final WorldDef world;
  final SceneLayout layout;

  final Set<String> found = {};
  final List<String> foundOrder = [];
  final Set<String> opened = {};
  final Map<String, int> wiggles = {};
  final Map<String, int> wobbles = {};

  int wrongTaps = 0;
  int hintsUsed = 0;
  int room = 0;
  bool completed = false;
  bool failed = false;
  bool paused = false;
  int elapsedMs = 0;
  int extraMs = 0; // bonus time granted (e.g. after a rewarded ad)
  final ValueNotifier<int> seconds = ValueNotifier<int>(0);

  int get targetsTotal => cfg.targets.length;
  int get targetsFound => cfg.targets.where(found.contains).length;
  int get bonusFound => cfg.bonus.where(found.contains).length;
  bool get running => !paused && !completed && !failed;

  int? get timeLeftSec {
    final lim = cfg.timeLimitSec;
    if (lim == null) return null;
    return max(0, lim + (extraMs ~/ 1000) - elapsedMs ~/ 1000);
  }

  // ---- state queries -----------------------------------------------------

  PropKind? _kindOf(String propId) => world.propById(propId)?.kind;

  bool isLocked(String propId) {
    final need = cfg.locks[propId];
    return need != null && !found.contains(need);
  }

  bool isOpen(String propId) => opened.contains(propId);

  /// Should the item be painted at all?
  bool isDrawn(PlacedItem it) {
    if (found.contains(it.id)) return false;
    final h = it.hiddenIn;
    if (h == null) return true;
    final k = _kindOf(h);
    if (k == null) return false;
    if (k.popsIn) return opened.contains(h);
    return true; // revealsBehind kinds paint it underneath the prop
  }

  bool isTappable(PlacedItem it) {
    if (found.contains(it.id)) return false;
    final h = it.hiddenIn;
    return h == null || opened.contains(h);
  }

  /// Is this item painted beneath the props (partially covered)?
  bool isBehindLayer(PlacedItem it) {
    if (it.def.isBehind) return true;
    final h = it.hiddenIn;
    if (h == null) return false;
    final k = _kindOf(h);
    return k != null && k.revealsBehind;
  }

  int remainingIn(int r) {
    var n = 0;
    for (final it in layout.items) {
      if (it.isTarget && it.room == r && !found.contains(it.id)) n++;
    }
    return n;
  }

  // ---- input -------------------------------------------------------------

  void setRoom(int r) {
    if (r == room) return;
    room = r;
    notifyListeners();
  }

  TapOutcome tapAt(Offset p, {double scale = 1.0}) {
    if (!running) return TapOutcome(TapKind.wrong, pos: p);
    final minR = 26.0 / max(0.2, scale);

    bool hit(PlacedItem it) {
      final r = max(it.size * 0.55, minR);
      return (it.pos - p).distance <= r;
    }

    final inRoom = layout.items.where((i) => i.room == room).toList();

    // 1. front layer: loose items + popped-in hidden items
    for (final it in inRoom.reversed) {
      if (!isBehindLayer(it) && isDrawn(it) && isTappable(it) && hit(it)) {
        return _tapItem(it, p);
      }
    }
    // 2. items revealed from behind an opened prop
    for (final it in inRoom.reversed) {
      if (it.hiddenIn != null && isBehindLayer(it) && isTappable(it) && !found.contains(it.id) && hit(it)) {
        return _tapItem(it, p);
      }
    }
    // 3. interactive props
    for (final pp in layout.props.reversed) {
      if (pp.room != room || !pp.active) continue;
      if (pp.kind == PropKind.dark && !isLocked(pp.id)) continue;
      final r = pp.rect.deflate(pp.size * 0.07);
      if (r.contains(p)) return _tapProp(pp, p);
    }
    // 4. partially covered loose items
    for (final it in inRoom.reversed) {
      if (it.def.isBehind && !found.contains(it.id) && hit(it)) {
        return _tapItem(it, p);
      }
    }
    wrongTaps++;
    notifyListeners();
    return TapOutcome(TapKind.wrong, pos: p);
  }

  TapOutcome _tapItem(PlacedItem it, Offset p) {
    if (it.isTarget || it.isBonus) {
      found.add(it.id);
      foundOrder.add(it.id);
      final unlocked = <String>[];
      for (final e in cfg.locks.entries) {
        if (e.value == it.id) {
          unlocked.add(e.key);
          if (_kindOf(e.key) == PropKind.dark) opened.add(e.key);
        }
      }
      if (cfg.targets.every(found.contains)) completed = true;
      notifyListeners();
      return TapOutcome(
        it.isBonus && !it.isTarget ? TapKind.bonusFound : TapKind.found,
        item: it,
        pos: it.pos,
        unlocked: unlocked,
      );
    }
    // A decoy: gentle wobble, no penalty.
    wrongTaps++;
    wobbles[it.id] = (wobbles[it.id] ?? 0) + 1;
    notifyListeners();
    return TapOutcome(TapKind.wrong, item: it, pos: it.pos, message: it.def.name);
  }

  TapOutcome _tapProp(PlacedProp pp, Offset p) {
    final id = pp.id;
    if (isLocked(id)) {
      final need = world.itemById(cfg.locks[id]!);
      final label = need == null ? 'something' : '${need.emoji} ${need.name}';
      if (pp.kind == PropKind.dark) {
        return TapOutcome(TapKind.propDark,
            prop: pp, pos: pp.pos, message: 'It is too dark here. Find the $label first!');
      }
      return TapOutcome(TapKind.propLocked,
          prop: pp, pos: pp.pos, message: 'Locked! Find the $label first.');
    }
    wiggles[id] = (wiggles[id] ?? 0) + 1;
    if (!opened.contains(id)) {
      opened.add(id);
      final hasContent = layout.items.any((i) => i.hiddenIn == id);
      notifyListeners();
      return TapOutcome(TapKind.propOpened,
          prop: pp, pos: pp.pos, emptyOpen: !hasContent && pp.kind.isContainer);
    }
    notifyListeners();
    return TapOutcome(TapKind.propWiggle, prop: pp, pos: pp.pos);
  }

  // ---- hints ---------------------------------------------------------------

  /// Highlights an approximate area - never the exact answer.
  HintResult? requestHint() {
    final unfound = layout.items.where((i) => i.isTarget && !found.contains(i.id)).toList();
    if (unfound.isEmpty) return null;

    final findable = unfound.where((i) => i.hiddenIn == null || opened.contains(i.hiddenIn)).toList();
    HintResult? result;
    if (findable.isNotEmpty) {
      findable.sort((a, b) {
        final ra = a.room == room ? 0 : 1;
        final rb = b.room == room ? 0 : 1;
        return ra.compareTo(rb);
      });
      final sameRoom = findable.where((i) => i.room == findable.first.room).toList();
      final it = sameRoom[hintsUsed % sameRoom.length];
      final ang = hintsUsed * 2.4;
      final off = Offset(cos(ang), sin(ang)) * 24;
      result = HintResult(it.pos + off, 82, it.room, itemId: it.id);
    } else {
      // Everything left is inside something: point at the next thing to open.
      for (final it in unfound) {
        final h = it.hiddenIn;
        if (h == null) continue;
        if (opened.contains(h) || isLocked(h)) continue;
        for (final pp in layout.props) {
          if (pp.id == h) {
            result = HintResult(pp.pos, pp.size * 0.72 + 12, pp.room, propId: h);
            break;
          }
        }
        if (result != null) break;
      }
    }
    if (result != null) {
      hintsUsed++;
      notifyListeners();
    }
    return result;
  }

  // ---- time --------------------------------------------------------------

  void tick(int ms) {
    if (!running) return;
    elapsedMs += ms;
    final s = elapsedMs ~/ 1000;
    if (s != seconds.value) seconds.value = s;
    final lim = cfg.timeLimitSec;
    if (lim != null && elapsedMs >= (lim * 1000 + extraMs)) {
      failed = true;
      notifyListeners();
    }
  }

  void addTime(int sec) {
    extraMs += sec * 1000;
    if (failed) {
      failed = false;
    }
    notifyListeners();
  }

  void setPaused(bool v) {
    if (paused == v) return;
    paused = v;
    notifyListeners();
  }

  /// 3 stars: fast + no hints. 2 stars: reasonably quick. 1 star: finished.
  int starsEarned() {
    final secs = elapsedMs / 1000.0;
    if (hintsUsed == 0 && secs <= cfg.parTimeSec) return 3;
    if (secs <= cfg.parTimeSec * 2) return 2;
    return 1;
  }

  @override
  void dispose() {
    seconds.dispose();
    super.dispose();
  }
}
