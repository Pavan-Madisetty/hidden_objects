import '../core/utils.dart';

enum BoardScope { global, weekly, friends }

class PlayerSnapshot {
  const PlayerSnapshot({
    required this.nickname,
    required this.avatar,
    required this.stars,
    required this.levels,
    required this.streak,
    required this.weeklyScore,
    required this.weekId,
  });

  final String nickname;
  final String avatar;
  final int stars;
  final int levels;
  final int streak;
  final int weeklyScore;
  final String weekId;
}

class BoardEntry {
  const BoardEntry({
    required this.rank,
    required this.name,
    required this.avatar,
    required this.stars,
    required this.levels,
    required this.streak,
    required this.weekly,
    required this.isYou,
  });

  final int rank;
  final String name;
  final String avatar;
  final int stars;
  final int levels;
  final int streak;
  final int weekly;
  final bool isYou;
}

/// Backend-ready leaderboard abstraction. Ranking is driven by stars and
/// skill (weekly score); coins and purchases never influence it.
abstract class LeaderboardService {
  /// False when the data is simulated locally.
  bool get isOnline;
  Future<void> submit(PlayerSnapshot me);
  Future<List<BoardEntry>> fetch(BoardScope scope, PlayerSnapshot me);
}

/// Offline implementation with a friendly set of simulated explorers, so the
/// feature is fully playable without a server.
class LocalLeaderboardService implements LeaderboardService {
  static const _adjectives = [
    'Sunny', 'Happy', 'Brave', 'Lucky', 'Clever', 'Tiny', 'Cosmic', 'Jolly',
    'Sparkly', 'Speedy', 'Gentle', 'Curious', 'Mighty', 'Cheery', 'Bouncy', 'Dreamy',
  ];
  static const _animals = [
    ['Fox', '🦊'], ['Panda', '🐼'], ['Owl', '🦉'], ['Bunny', '🐰'], ['Turtle', '🐢'],
    ['Dragon', '🐲'], ['Kitten', '🐱'], ['Penguin', '🐧'], ['Koala', '🐨'], ['Lion', '🦁'],
    ['Otter', '🦦'], ['Unicorn', '🦄'],
  ];

  PlayerSnapshot? _last;

  @override
  bool get isOnline => false;

  @override
  Future<void> submit(PlayerSnapshot me) async {
    _last = me;
  }

  List<BoardEntry> _bots(String weekId) {
    final out = <BoardEntry>[];
    for (var i = 0; i < 40; i++) {
      final adj = _adjectives[(i * 7 + 3) % _adjectives.length];
      final animal = _animals[(i * 5 + 1) % _animals.length];
      final h = stableHash('bot$i');
      final wh = stableHash('bot$i-$weekId');
      final stars = 6 + (h % 285);
      out.add(BoardEntry(
        rank: 0,
        name: '$adj ${animal[0]}',
        avatar: animal[1],
        stars: stars,
        levels: clampI((stars / 2.9).round(), 1, 100),
        streak: h % 15,
        weekly: 40 + (wh % 1100),
        isYou: false,
      ));
    }
    return out;
  }

  @override
  Future<List<BoardEntry>> fetch(BoardScope scope, PlayerSnapshot me) async {
    _last = me;
    var bots = _bots(me.weekId);
    if (scope == BoardScope.friends) {
      bots = [for (var i = 0; i < bots.length; i += 7) bots[i]];
    }
    final all = <BoardEntry>[
      ...bots,
      BoardEntry(
        rank: 0,
        name: me.nickname,
        avatar: me.avatar,
        stars: me.stars,
        levels: me.levels,
        streak: me.streak,
        weekly: me.weeklyScore,
        isYou: true,
      ),
    ];
    int cmp(BoardEntry a, BoardEntry b) {
      if (scope == BoardScope.weekly) {
        final c = b.weekly.compareTo(a.weekly);
        return c != 0 ? c : b.stars.compareTo(a.stars);
      }
      final c = b.stars.compareTo(a.stars);
      return c != 0 ? c : b.levels.compareTo(a.levels);
    }

    all.sort(cmp);
    return [
      for (var i = 0; i < all.length; i++)
        BoardEntry(
          rank: i + 1,
          name: all[i].name,
          avatar: all[i].avatar,
          stars: all[i].stars,
          levels: all[i].levels,
          streak: all[i].streak,
          weekly: all[i].weekly,
          isYou: all[i].isYou,
        ),
    ];
  }

  PlayerSnapshot? get lastSubmitted => _last;
}
