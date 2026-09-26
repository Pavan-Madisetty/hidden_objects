/// Everything that is persisted about the player. Plain data + JSON so it can
/// be stored locally today and synced to the cloud later.
class PlayerData {
  PlayerData();

  static const int currentVersion = 1;

  int version = currentVersion;
  String nickname = 'Explorer';
  int coins = 100;
  int xp = 0;
  int freeHints = 5;
  String hintRefillDay = '';

  /// levelId -> best stars (1..3). Presence == completed.
  Map<int, int> stars = {};

  /// levelId -> best time in seconds.
  Map<int, int> bestTime = {};

  Set<String> unlockedWorlds = {'bedroom'};

  // Daily challenge / streak
  int streak = 0;
  int bestStreak = 0;
  String lastDailyDay = '';
  Set<String> dailyDays = {};

  // Weekly leaderboard score
  String weekId = '';
  int weeklyScore = 0;

  // Settings
  double musicVol = 0.6;
  double sfxVol = 0.85;
  bool muted = false;
  bool analyticsOn = true;
  bool adsRemoved = false;

  // Cosmetics
  Set<String> owned = {'char_kit', 'hat_none', 'theme_sunny'};
  String character = 'char_kit';
  String hat = 'hat_none';
  String themeId = 'theme_sunny';

  // Misc
  Set<String> seenIntros = {};
  bool onboardingDone = false;
  int totalFound = 0;
  int totalHints = 0;
  int sessions = 0;
  int lastLevel = 1;
  int levelsSinceAd = 0;
  int lastAdMs = 0;
  Map<String, int> bonusBest = {};

  int get totalStars => stars.values.fold(0, (a, b) => a + b);
  int get levelsCompleted => stars.length;
  bool completed(int levelId) => stars.containsKey(levelId);

  Map<String, dynamic> toJson() => {
        'version': version,
        'nickname': nickname,
        'coins': coins,
        'xp': xp,
        'freeHints': freeHints,
        'hintRefillDay': hintRefillDay,
        'stars': stars.map((k, v) => MapEntry(k.toString(), v)),
        'bestTime': bestTime.map((k, v) => MapEntry(k.toString(), v)),
        'unlockedWorlds': unlockedWorlds.toList(),
        'streak': streak,
        'bestStreak': bestStreak,
        'lastDailyDay': lastDailyDay,
        'dailyDays': dailyDays.toList(),
        'weekId': weekId,
        'weeklyScore': weeklyScore,
        'musicVol': musicVol,
        'sfxVol': sfxVol,
        'muted': muted,
        'analyticsOn': analyticsOn,
        'adsRemoved': adsRemoved,
        'owned': owned.toList(),
        'character': character,
        'hat': hat,
        'themeId': themeId,
        'seenIntros': seenIntros.toList(),
        'onboardingDone': onboardingDone,
        'totalFound': totalFound,
        'totalHints': totalHints,
        'sessions': sessions,
        'lastLevel': lastLevel,
        'levelsSinceAd': levelsSinceAd,
        'lastAdMs': lastAdMs,
        'bonusBest': bonusBest,
      };

  factory PlayerData.fromJson(Map<String, dynamic> j) {
    final d = PlayerData();
    int i(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    double dbl(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    bool b(String k, bool def) => (j[k] as bool?) ?? def;
    String s(String k, String def) => (j[k] as String?) ?? def;
    Set<String> set(String k, Set<String> def) =>
        j[k] is List ? (j[k] as List).map((e) => e.toString()).toSet() : def;
    Map<int, int> intMap(String k) {
      final out = <int, int>{};
      final v = j[k];
      if (v is Map) {
        v.forEach((key, val) {
          final kk = int.tryParse(key.toString());
          if (kk != null && val is num) out[kk] = val.toInt();
        });
      }
      return out;
    }

    d.version = i('version', currentVersion);
    d.nickname = s('nickname', d.nickname);
    d.coins = i('coins', d.coins);
    d.xp = i('xp', 0);
    d.freeHints = i('freeHints', d.freeHints);
    d.hintRefillDay = s('hintRefillDay', '');
    d.stars = intMap('stars');
    d.bestTime = intMap('bestTime');
    d.unlockedWorlds = set('unlockedWorlds', {'bedroom'});
    if (d.unlockedWorlds.isEmpty) d.unlockedWorlds = {'bedroom'};
    d.streak = i('streak', 0);
    d.bestStreak = i('bestStreak', 0);
    d.lastDailyDay = s('lastDailyDay', '');
    d.dailyDays = set('dailyDays', {});
    d.weekId = s('weekId', '');
    d.weeklyScore = i('weeklyScore', 0);
    d.musicVol = dbl('musicVol', d.musicVol);
    d.sfxVol = dbl('sfxVol', d.sfxVol);
    d.muted = b('muted', false);
    d.analyticsOn = b('analyticsOn', true);
    d.adsRemoved = b('adsRemoved', false);
    d.owned = set('owned', d.owned)..addAll({'char_kit', 'hat_none', 'theme_sunny'});
    d.character = s('character', d.character);
    d.hat = s('hat', d.hat);
    d.themeId = s('themeId', d.themeId);
    d.seenIntros = set('seenIntros', {});
    d.onboardingDone = b('onboardingDone', false);
    d.totalFound = i('totalFound', 0);
    d.totalHints = i('totalHints', 0);
    d.sessions = i('sessions', 0);
    d.lastLevel = i('lastLevel', 1);
    d.levelsSinceAd = i('levelsSinceAd', 0);
    d.lastAdMs = i('lastAdMs', 0);
    final bb = j['bonusBest'];
    if (bb is Map) {
      bb.forEach((k, v) {
        if (v is num) d.bonusBest[k.toString()] = v.toInt();
      });
    }
    return d;
  }

  /// Conflict resolution used by cloud sync: keep the "furthest" progress.
  void mergeFrom(PlayerData o) {
    o.stars.forEach((k, v) {
      if (v > (stars[k] ?? 0)) stars[k] = v;
    });
    o.bestTime.forEach((k, v) {
      final cur = bestTime[k];
      if (cur == null || v < cur) bestTime[k] = v;
    });
    unlockedWorlds.addAll(o.unlockedWorlds);
    owned.addAll(o.owned);
    seenIntros.addAll(o.seenIntros);
    dailyDays.addAll(o.dailyDays);
    if (o.xp > xp) xp = o.xp;
    if (o.coins > coins) coins = o.coins;
    if (o.bestStreak > bestStreak) bestStreak = o.bestStreak;
    if (o.totalFound > totalFound) totalFound = o.totalFound;
  }
}
