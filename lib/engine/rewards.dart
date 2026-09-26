import 'dart:math';

/// One line of the "what did I earn" breakdown.
class RewardLine {
  const RewardLine(this.label, this.coins);
  final String label;
  final int coins;
}

class LevelReward {
  const LevelReward({
    required this.stars,
    required this.newStars,
    required this.firstClear,
    required this.lines,
    required this.coins,
    required this.xp,
    required this.score,
  });

  final int stars;

  /// Stars gained compared with the previous best.
  final int newStars;
  final bool firstClear;
  final List<RewardLine> lines;
  final int coins;
  final int xp;

  /// Points that count towards the weekly leaderboard.
  final int score;
}

/// All reward numbers live here so they are easy to tune.
class RewardCalculator {
  static const int hintCost = 25;
  static const int hintCooldownSec = 8;
  static const int startingFreeHints = 3;

  static LevelReward level({
    required int stars,
    required int prevStars,
    required bool noHints,
    required int bonusFound,
    required int secondsUnderPar,
    int multiplier = 1,
  }) {
    final first = prevStars == 0;
    final newStars = max(0, stars - prevStars);
    final lines = <RewardLine>[];
    if (first) {
      lines.add(const RewardLine('Level complete', 50));
      lines.add(RewardLine('$stars-star bonus', stars * 20));
      lines.add(const RewardLine('First time bonus', 30));
    } else {
      lines.add(const RewardLine('Level complete', 15));
      if (newStars > 0) lines.add(RewardLine('New stars', newStars * 30));
    }
    if (noHints) lines.add(const RewardLine('No hints used', 15));
    if (bonusFound > 0) lines.add(RewardLine('Bonus objects', bonusFound * 25));

    var coins = lines.fold<int>(0, (a, l) => a + l.coins);
    coins *= multiplier;
    final xp = first ? 40 + 15 * stars + (noHints ? 10 : 0) : 8 + 15 * newStars;
    final score = stars * 100 + max(0, secondsUnderPar) * 2 + (first ? 50 : 0);
    return LevelReward(
      stars: stars,
      newStars: newStars,
      firstClear: first,
      lines: lines,
      coins: coins,
      xp: xp,
      score: score,
    );
  }

  /// Streak reward table (day of streak 1..7, then it cycles).
  static int streakCoins(int streakDay) {
    const table = [50, 75, 100, 125, 150, 175, 300];
    final i = (streakDay - 1) % 7;
    return table[i];
  }

  static bool isSpecialDay(int streakDay) => streakDay > 0 && streakDay % 7 == 0;

  static const int dailyCompletionBonus = 50;
  static const int dailyXp = 60;
  static const int rewardedAdCoins = 30;
  static const int rewardedAdHints = 2;
  static const int bonusRoomEntryCost = 40;
}
