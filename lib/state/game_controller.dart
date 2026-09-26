import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/utils.dart';
import '../data/audio_catalog.dart';
import '../data/level_repository.dart';
import '../data/shop_catalog.dart';
import '../data/worlds/worlds.dart';
import '../engine/daily_challenge.dart';
import '../engine/level_session.dart';
import '../engine/progression.dart';
import '../engine/rewards.dart';
import '../models/level_config.dart';
import '../models/player_data.dart';
import '../models/world_def.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/leaderboard_service.dart';
import '../services/services.dart';

enum HintPayment { free, coins, none }

/// Everything the "Level complete" screen needs.
class LevelOutcome {
  LevelOutcome({
    required this.config,
    required this.stars,
    required this.prevStars,
    required this.reward,
    required this.levelBefore,
    required this.levelAfter,
    required this.seconds,
    this.unlockedWorld,
    this.streak,
    this.streakCoins = 0,
    this.streakSpecial = false,
    this.bonusFound = 0,
  });

  final LevelConfig config;
  final int stars;
  final int prevStars;
  final LevelReward reward;
  final int levelBefore;
  final int levelAfter;
  final int seconds;
  final WorldDef? unlockedWorld;
  final int? streak;
  final int streakCoins;
  final bool streakSpecial;
  final int bonusFound;

  bool get leveledUp => levelAfter > levelBefore;
  int get totalCoins => reward.coins + streakCoins;
}

/// App-wide game state: player data + services + rules. UI listens to it.
class GameController extends ChangeNotifier with WidgetsBindingObserver {
  GameController({
    required this.services,
    required this.data,
    WorldRegistry? registry,
    DateTime Function()? clock,
  })  : registry = registry ?? WorldRegistry(),
        _clock = clock ?? DateTime.now {
    levels = LevelRepository(this.registry);
    progression = Progression(this.registry);
  }

  final Services services;
  PlayerData data;
  final WorldRegistry registry;
  late final LevelRepository levels;
  late final Progression progression;
  final DateTime Function() _clock;

  int _sessionStartMs = 0;
  LevelConfig? _dailyCache;
  String _dailyCacheDay = '';

  AudioService get audio => services.audio;

  // ---- boot ----------------------------------------------------------------

  static Future<GameController> boot({Services? services}) async {
    final s = services ?? Services.defaults();
    final data = await s.save.load();
    final c = GameController(services: s, data: data);
    await c._init();
    return c;
  }

  Future<void> _init() async {
    final now = _clock();
    // Fresh players get a friendly random nickname.
    if (data.sessions == 0 && data.nickname == 'Explorer') {
      data.nickname = _randomNickname();
    }
    data.sessions++;
    if (data.hintRefillDay != dayKey(now)) {
      if (data.freeHints < RewardCalculator.startingFreeHints) {
        data.freeHints = RewardCalculator.startingFreeHints;
      }
      data.hintRefillDay = dayKey(now);
    }
    final wk = weekKey(now);
    if (data.weekId != wk) {
      data.weekId = wk;
      data.weeklyScore = 0;
    }
    // Persisted unlocks: never re-lock a world.
    for (final w in progression.newlyUnlockable(data)) {
      data.unlockedWorlds.add(w.id);
    }

    services.analytics.enabled = data.analyticsOn;
    services.ads.adsRemoved = data.adsRemoved;
    audio.registerTracks(defaultTracks());
    await Future.wait([
      audio.init(music: data.musicVol, sfx: data.sfxVol, mute: data.muted),
      services.analytics.init(),
      services.ads.init(),
    ]);
    // Generate the first music loops in the background.
    audio.preload(['menu', 'world_0']);
    _sessionStartMs = now.millisecondsSinceEpoch;
    services.analytics.log(Ev.appOpened, {'session': data.sessions});
    WidgetsBinding.instance.addObserver(this);
    services.save.scheduleSave(data);
  }

  String _randomNickname() {
    const adj = ['Sunny', 'Happy', 'Brave', 'Lucky', 'Clever', 'Jolly', 'Sparkly', 'Curious'];
    const animal = ['Fox', 'Panda', 'Owl', 'Bunny', 'Turtle', 'Kitten', 'Otter', 'Koala'];
    final h = _clock().microsecondsSinceEpoch;
    return '${adj[h % adj.length]} ${animal[(h ~/ 7) % animal.length]}';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      services.save.flush();
      audio.pauseAll();
      final secs = (_clock().millisecondsSinceEpoch - _sessionStartMs) ~/ 1000;
      services.analytics.log(Ev.sessionEnd, {'seconds': secs});
    } else if (state == AppLifecycleState.resumed) {
      _sessionStartMs = _clock().millisecondsSinceEpoch;
      audio.resumeAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _changed() {
    services.save.scheduleSave(data);
    notifyListeners();
  }

  // ---- derived state ---------------------------------------------------------

  String get today => dayKey(_clock());
  DateTime get now => _clock();

  AppPalette get palette => ShopCatalog.palette(data.themeId);
  int get explorerLevel => Progression.explorerLevel(data.xp);
  String get characterEmoji => ShopCatalog.characterEmoji(data.character);
  String get hatEmoji => ShopCatalog.hatEmoji(data.hat);

  bool get isFirstRun => data.levelsCompleted == 0 && !data.onboardingDone;
  bool get hasProgress => data.levelsCompleted > 0;
  int get continueLevelId => progression.continueLevel(data);
  int get streak =>
      StreakLogic.visible(streak: data.streak, lastDay: data.lastDailyDay, today: today);
  bool get dailyDone => data.lastDailyDay == today;

  LevelConfig? levelById(int id) => levels.byId(id);

  LevelConfig dailyConfig() {
    final d = today;
    if (_dailyCache != null && _dailyCacheDay == d) return _dailyCache!;
    final unlocked = [
      for (final w in registry.worlds)
        if (progression.isWorldUnlocked(w, data)) w,
    ];
    _dailyCache = DailyChallenge.build(_clock(), registry, unlocked, data.levelsCompleted);
    _dailyCacheDay = d;
    return _dailyCache!;
  }

  WorldDef worldOf(LevelConfig c) => registry.byId(c.worldId);

  PlayerSnapshot snapshot() => PlayerSnapshot(
        nickname: data.nickname,
        avatar: characterEmoji,
        stars: data.totalStars,
        levels: data.levelsCompleted,
        streak: streak,
        weeklyScore: data.weeklyScore,
        weekId: data.weekId,
      );

  String musicFor(LevelConfig c) => c.musicId ?? worldOf(c).musicId;

  // ---- level lifecycle ---------------------------------------------------------

  LevelSession createSession(LevelConfig cfg) => LevelSession(cfg, worldOf(cfg));

  void levelStarted(LevelConfig cfg) {
    final replay = data.completed(cfg.id);
    if (cfg.isDaily) {
      services.analytics.log(Ev.dailyStarted, {'day': today});
    } else {
      services.analytics.log(Ev.levelStarted, {
        'level': cfg.id,
        'world': cfg.worldId,
        'difficulty': cfg.difficulty.name,
      });
      if (replay) services.analytics.log(Ev.levelReplayed, {'level': cfg.id});
    }
    if (!cfg.isDaily && !cfg.isBonus) {
      data.lastLevel = cfg.id;
      data.onboardingDone = true;
      _changed();
    }
  }

  void objectFound(LevelSession s, String itemId) {
    data.totalFound++;
    services.analytics.log(Ev.objectFound, {'level': s.cfg.id, 'item': itemId});
    services.save.scheduleSave(data);
  }

  void levelFailed(LevelSession s) {
    services.analytics.log(Ev.levelFailed, {
      'level': s.cfg.id,
      'found': s.targetsFound,
      'of': s.targetsTotal,
      'seconds': s.elapsedMs ~/ 1000,
    });
  }

  void levelQuit(LevelSession s) {
    if (s.completed) return;
    services.analytics.log(Ev.levelQuit, {
      'level': s.cfg.id,
      'found': s.targetsFound,
      'seconds': s.elapsedMs ~/ 1000,
    });
  }

  Future<LevelOutcome> completeLevel(LevelSession s) async {
    final cfg = s.cfg;
    final stars = s.starsEarned();
    final seconds = s.elapsedMs ~/ 1000;
    final noHints = s.hintsUsed == 0;
    final levelBefore = explorerLevel;
    final bonusKey = cfg.id.toString();

    int prev;
    if (cfg.isDaily) {
      prev = 0;
    } else if (cfg.isBonus) {
      prev = data.bonusBest[bonusKey] ?? 0;
    } else {
      prev = data.stars[cfg.id] ?? 0;
    }

    final reward = RewardCalculator.level(
      stars: stars,
      prevStars: prev,
      noHints: noHints,
      bonusFound: s.bonusFound,
      secondsUnderPar: cfg.parTimeSec - seconds,
      multiplier: cfg.rewardMultiplier,
    );

    data.coins += reward.coins;
    data.xp += reward.xp;
    data.weeklyScore += reward.score;

    int? streakValue;
    var streakCoins = 0;
    var special = false;
    if (cfg.isDaily) {
      if (data.lastDailyDay != today) {
        final newStreak = StreakLogic.next(
          streak: data.streak,
          lastDay: data.lastDailyDay,
          today: today,
        );
        data.streak = newStreak;
        if (newStreak > data.bestStreak) data.bestStreak = newStreak;
        data.lastDailyDay = today;
        data.dailyDays.add(today);
        streakValue = newStreak;
        streakCoins = RewardCalculator.streakCoins(newStreak) + RewardCalculator.dailyCompletionBonus;
        special = RewardCalculator.isSpecialDay(newStreak);
        data.coins += streakCoins;
        data.xp += RewardCalculator.dailyXp;
        data.weeklyScore += 200;
        if (special) data.owned.add('hat_golden');
        services.analytics.log(Ev.dailyCompleted, {'streak': newStreak, 'seconds': seconds});
        services.analytics.log(Ev.rewardClaimed, {'type': 'daily', 'coins': streakCoins});
      }
    } else if (cfg.isBonus) {
      if (stars > prev) data.bonusBest[bonusKey] = stars;
    } else {
      if (stars > prev) data.stars[cfg.id] = stars;
      final best = data.bestTime[cfg.id];
      if (best == null || seconds < best) data.bestTime[cfg.id] = seconds;
      data.levelsSinceAd++;
    }

    WorldDef? unlocked;
    for (final w in progression.newlyUnlockable(data)) {
      data.unlockedWorlds.add(w.id);
      unlocked ??= w;
      services.analytics.log(Ev.worldUnlocked, {'world': w.id});
    }

    services.analytics.log(Ev.levelCompleted, {
      'level': cfg.id,
      'stars': stars,
      'seconds': seconds,
      'hints': s.hintsUsed,
      'wrong': s.wrongTaps,
    });
    services.analytics.log(Ev.rewardClaimed, {'type': 'level', 'coins': reward.coins});

    _changed();
    unawaited(services.leaderboard.submit(snapshot()));
    return LevelOutcome(
      config: cfg,
      stars: stars,
      prevStars: prev,
      reward: reward,
      levelBefore: levelBefore,
      levelAfter: explorerLevel,
      seconds: seconds,
      unlockedWorld: unlocked,
      streak: streakValue,
      streakCoins: streakCoins,
      streakSpecial: special,
      bonusFound: s.bonusFound,
    );
  }

  /// Level to open after [cfg], or null when there is nothing next.
  LevelConfig? nextLevelAfter(LevelConfig cfg) {
    if (cfg.isDaily || cfg.isBonus) return null;
    final next = levels.next(cfg.id);
    if (next == null) return null;
    if (!progression.isLevelUnlocked(next.id, data)) return null;
    return next;
  }

  // ---- hints -----------------------------------------------------------------

  int get hintsAvailable => data.freeHints;
  bool get canAffordPaidHint => data.coins >= RewardCalculator.hintCost;

  HintPayment payForHint() {
    if (data.freeHints > 0) {
      data.freeHints--;
      data.totalHints++;
      _changed();
      return HintPayment.free;
    }
    if (data.coins >= RewardCalculator.hintCost) {
      data.coins -= RewardCalculator.hintCost;
      data.totalHints++;
      _changed();
      return HintPayment.coins;
    }
    return HintPayment.none;
  }

  /// Give a hint back (e.g. the level had nothing left to point at).
  void refundHint(HintPayment p) {
    if (p == HintPayment.free) data.freeHints++;
    if (p == HintPayment.coins) data.coins += RewardCalculator.hintCost;
    if (p != HintPayment.none) data.totalHints = clampI(data.totalHints - 1, 0, 1 << 30);
    _changed();
  }

  void hintUsed(LevelSession s, HintPayment p) {
    services.analytics.log(Ev.hintUsed, {'level': s.cfg.id, 'paid': p == HintPayment.coins});
  }

  // ---- economy -----------------------------------------------------------------

  void addCoins(int n) {
    data.coins += n;
    _changed();
  }

  bool spendCoins(int n) {
    if (data.coins < n) return false;
    data.coins -= n;
    _changed();
    return true;
  }

  Future<bool> _rewardedAd(String placement) async {
    final ok = await services.ads.showRewarded(placement);
    services.analytics.log(Ev.adWatched, {'placement': placement, 'completed': ok});
    return ok;
  }

  Future<bool> watchAdForCoins() async {
    final ok = await _rewardedAd('free_coins');
    if (ok) {
      addCoins(RewardCalculator.rewardedAdCoins);
      services.analytics.log(Ev.rewardClaimed, {'type': 'ad_coins'});
    }
    return ok;
  }

  Future<bool> watchAdForHints() async {
    final ok = await _rewardedAd('free_hints');
    if (ok) {
      data.freeHints += RewardCalculator.rewardedAdHints;
      _changed();
    }
    return ok;
  }

  Future<bool> watchAdForTime() => _rewardedAd('extra_time');

  /// Interstitial at a natural break (after completing a level, on "Next").
  Future<void> maybeInterstitial(int levelId) async {
    final nowMs = _clock().millisecondsSinceEpoch;
    final show = AdPolicy.shouldShowInterstitial(
      adsRemoved: data.adsRemoved,
      levelId: levelId,
      levelsSinceAd: data.levelsSinceAd,
      lastAdMs: data.lastAdMs,
      nowMs: nowMs,
    );
    if (!show) return;
    data.levelsSinceAd = 0;
    data.lastAdMs = nowMs;
    _changed();
    await services.ads.showInterstitial('level_break');
    services.analytics.log(Ev.adWatched, {'placement': 'interstitial', 'completed': true});
  }

  // ---- cosmetics -----------------------------------------------------------------

  bool owns(String id) => data.owned.contains(id);

  bool isEquipped(ShopItem i) {
    switch (i.category) {
      case ShopCategory.character:
        return data.character == i.id;
      case ShopCategory.hat:
        return data.hat == i.id;
      case ShopCategory.theme:
        return data.themeId == i.id;
    }
  }

  bool levelReached(ShopItem i) => explorerLevel >= i.unlockLevel;

  /// Returns null on success, otherwise a short reason.
  String? buy(ShopItem i) {
    if (owns(i.id)) return 'You already have this!';
    if (i.special) return 'This is a special reward.';
    if (!levelReached(i)) return 'Reach Explorer Level ${i.unlockLevel} to unlock!';
    if (data.coins < i.price) return 'You need ${i.price - data.coins} more coins.';
    data.coins -= i.price;
    data.owned.add(i.id);
    equip(i);
    services.analytics.log(Ev.purchase, {'item': i.id, 'currency': 'coins'});
    return null;
  }

  void equip(ShopItem i) {
    if (!owns(i.id)) return;
    switch (i.category) {
      case ShopCategory.character:
        data.character = i.id;
        break;
      case ShopCategory.hat:
        data.hat = i.id;
        break;
      case ShopCategory.theme:
        data.themeId = i.id;
        break;
    }
    _changed();
  }

  // ---- bonus rooms -----------------------------------------------------------------

  bool bonusRoomOpen(BonusRoomDef d) => explorerLevel >= d.unlockLevel;

  /// Pays the entry fee and returns the level, or null if not affordable.
  LevelConfig? enterBonusRoom(BonusRoomDef d) {
    if (!bonusRoomOpen(d)) return null;
    if (!spendCoins(RewardCalculator.bonusRoomEntryCost)) return null;
    return DailyChallenge.buildBonusRoom(d, registry);
  }

  // ---- real-money purchases (behind the abstraction) ---------------------------------

  Future<String?> buyProduct(String productId) async {
    final ok = await services.iap.purchase(productId);
    if (!ok) return null;
    services.analytics.log(Ev.purchase, {'item': productId, 'currency': 'real'});
    switch (productId) {
      case ProductIds.removeAds:
        data.adsRemoved = true;
        services.ads.adsRemoved = true;
        _changed();
        return 'Ads removed. Thank you!';
      case ProductIds.sparklePack:
        data.coins += 500;
        data.owned.add('hat_golden');
        _changed();
        return '+500 coins and the Golden Star hat!';
    }
    return 'Done!';
  }

  Future<void> restorePurchases() async {
    final owned = await services.iap.restore();
    if (owned.contains(ProductIds.removeAds)) {
      data.adsRemoved = true;
      services.ads.adsRemoved = true;
      _changed();
    }
  }

  // ---- settings -----------------------------------------------------------------------

  void setMusicVolume(double v) {
    data.musicVol = v;
    audio.apply(music: v);
    _changed();
  }

  void setSfxVolume(double v) {
    data.sfxVol = v;
    audio.apply(sfx: v);
    _changed();
  }

  void setMuted(bool v) {
    data.muted = v;
    audio.apply(mute: v);
    _changed();
  }

  void setAnalytics(bool v) {
    data.analyticsOn = v;
    services.analytics.enabled = v;
    _changed();
  }

  void setNickname(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    data.nickname = n.length > 16 ? n.substring(0, 16) : n;
    _changed();
  }

  bool introSeen(String key) => data.seenIntros.contains(key);
  void markIntroSeen(String key) {
    if (data.seenIntros.add(key)) _changed();
  }

  Future<void> resetProgress() async {
    await services.save.wipe();
    final fresh = PlayerData();
    fresh.nickname = _randomNickname();
    fresh.sessions = 1;
    fresh.hintRefillDay = today;
    fresh.weekId = weekKey(_clock());
    data = fresh;
    audio.apply(music: data.musicVol, sfx: data.sfxVol, mute: data.muted);
    _dailyCache = null;
    _changed();
    await services.save.flush();
  }
}
