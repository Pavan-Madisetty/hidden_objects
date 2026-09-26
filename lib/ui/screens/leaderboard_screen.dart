import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../services/audio_service.dart';
import '../../services/leaderboard_service.dart';
import '../../state/app_scope.dart';
import '../widgets/bouncy.dart';
import '../widgets/sky_background.dart';

/// Global / Weekly / Friends boards behind the LeaderboardService seam.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  BoardScope _scope = BoardScope.global;
  Future<List<BoardEntry>>? _future;
  bool _started = false;

  static const _labels = {
    BoardScope.global: 'Global',
    BoardScope.weekly: 'This week',
    BoardScope.friends: 'Friends',
  };

  void _load() {
    final c = AppScope.read(context);
    final me = c.snapshot();
    final svc = c.services.leaderboard;
    _future = () async {
      await svc.submit(me);
      return svc.fetch(_scope, me);
    }();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Scaffold(
      body: SkyBackground(
        palette: c.palette,
        emojis: const ['🏆', '⭐', '🥇', '🌟'],
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    RoundButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Top Explorers', style: kid(26, color: Colors.white, weight: FontWeight.w900))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    for (final s in BoardScope.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Bouncy(
                            onTap: () {
                              c.audio.sfx(Sfx.tap);
                              setState(() {
                                _scope = s;
                                _load();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _scope == s ? Colors.white : alpha(Colors.white, 0.35),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(_labels[s]!, style: kid(14, color: _scope == s ? const Color(0xFF3A2E5C) : Colors.white)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!c.services.leaderboard.isOnline)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                  child: Text('Offline mode: playing against friendly explorers.', style: kid(12, color: alpha(Colors.white, 0.9))),
                ),
              Expanded(
                child: FutureBuilder<List<BoardEntry>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    final list = snap.data ?? const <BoardEntry>[];
                    if (list.isEmpty) {
                      return Center(child: Text('No explorers yet!', style: kid(18, color: Colors.white)));
                    }
                    BoardEntry? me;
                    for (final e in list) {
                      if (e.isYou) me = e;
                    }
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                            itemCount: list.length,
                            itemBuilder: (context, i) => _row(list[i]),
                          ),
                        ),
                        if (me != null)
                          Container(
                            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            child: _row(me, footer: true),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BoardEntry e, {bool footer = false}) {
    final medal = e.rank == 1 ? '🥇' : e.rank == 2 ? '🥈' : e.rank == 3 ? '🥉' : null;
    final value = _scope == BoardScope.weekly ? e.weekly : e.stars;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: e.isYou ? const Color(0xFFFFF3C4) : alpha(Colors.white, 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: e.isYou ? const Color(0xFFFFB700) : Colors.transparent, width: 3),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(medal ?? '#${e.rank}', textAlign: TextAlign.center, style: kid(medal != null ? 26 : 15)),
          ),
          Text(e.avatar, style: const TextStyle(fontSize: 30, decoration: TextDecoration.none)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.isYou ? '${e.name} (you)' : e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: kid(16)),
                Text('${e.levels} levels  •  🔥 ${e.streak}', style: kid(11, color: const Color(0xFF6E6690))),
              ],
            ),
          ),
          Text(_scope == BoardScope.weekly ? '🏅 $value' : '⭐ $value', style: kid(16, weight: FontWeight.w900)),
        ],
      ),
    );
  }
}
