import 'package:flutter/material.dart';

import '../../core/navigation.dart';
import '../../core/strings.dart';
import '../../core/utils.dart';
import '../../engine/progression.dart';
import '../../services/audio_service.dart';
import '../../state/app_scope.dart';
import '../../state/game_controller.dart';
import '../widgets/bouncy.dart';
import '../widgets/mascot.dart';
import '../widgets/sky_background.dart';
import 'daily_screen.dart';
import 'flow.dart';
import 'leaderboard_screen.dart';
import 'level_map_screen.dart';
import 'rewards_screen.dart';
import 'settings_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _pulse = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final c = AppScope.read(context);
      c.audio.playMusic('menu');
    }
  }

  Future<void> _go(Widget page) async {
    final c = AppScope.read(context);
    c.audio.sfx(Sfx.tap);
    await Navigator.of(context).push(fadeRoute<void>(page));
    c.audio.playMusic('menu');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = c.palette;
    final lvl = c.explorerLevel;
    final first = c.isFirstRun;
    final levelId = c.continueLevelId;
    final cont = c.levelById(levelId);
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) => c.audio.ensureMusic(),
        child: SkyBackground(
          palette: p,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StatChip(emoji: '🪙', value: '${c.data.coins}', onTap: () => _go(const RewardsScreen())),
                      const SizedBox(width: 6),
                      StatChip(emoji: '⭐', value: '${c.data.totalStars}'),
                      const SizedBox(width: 6),
                      StatChip(emoji: '🔥', value: '${c.streak}', onTap: () => openDaily(context)),
                      const Spacer(),
                      RoundButton(emoji: '⚙️', onTap: () => _go(const SettingsScreen())),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _xpBar(c, lvl, p.ink),
                  const Spacer(flex: 2),
                  Text(Strings.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                        shadows: [
                          Shadow(color: darken(p.primary, 0.35), offset: const Offset(0, 4)),
                          Shadow(color: alpha(Colors.black, 0.25), blurRadius: 12, offset: const Offset(0, 8)),
                        ],
                      )),
                  Text('Look carefully. Find things. Earn rewards!',
                      textAlign: TextAlign.center, style: kid(15, color: p.ink, weight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Bouncy(
                    onTap: () => setState(() => _pulse++),
                    child: Mascot(emoji: c.characterEmoji, hat: c.hatEmoji, size: 104, pulse: _pulse),
                  ),
                  const Spacer(flex: 2),
                  if (first)
                    _Pulse(
                      child: PillButton(
                        label: 'Play',
                        emoji: '▶️',
                        big: true,
                        width: double.infinity,
                        color: p.primary,
                        onTap: () {
                          if (cont != null) openLevel(context, cont);
                        },
                      ),
                    )
                  else
                    PillButton(
                      label: cont == null ? 'Continue' : 'Continue  •  Level $levelId',
                      emoji: '▶️',
                      big: true,
                      width: double.infinity,
                      color: p.primary,
                      onTap: () {
                        if (cont != null) openLevel(context, cont);
                      },
                    ),
                  const SizedBox(height: 14),
                  _dailyCard(c, p.secondary),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _tile('🗺️', 'Play Map', p.secondary, () => _go(const LevelMapScreen()))),
                      const SizedBox(width: 10),
                      Expanded(child: _tile('🎁', 'Rewards', const Color(0xFFFF6FB5), () => _go(const RewardsScreen()))),
                      const SizedBox(width: 10),
                      Expanded(child: _tile('🏆', 'Ranks', const Color(0xFF6C8CFF), () => _go(const LeaderboardScreen()))),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _xpBar(GameController c, int lvl, Color ink) {
    final xp = c.data.xp;
    return Column(
      children: [
        Row(
          children: [
            Text('🔎 Explorer Level $lvl', style: kid(15, color: ink)),
            const Spacer(),
            Text('${Progression.xpIntoLevel(xp)} / ${Progression.xpForNext(xp)} XP', style: kid(13, color: ink, weight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: Progression.levelProgress(xp),
            minHeight: 12,
            backgroundColor: alpha(Colors.white, 0.55),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
          ),
        ),
      ],
    );
  }

  Widget _dailyCard(GameController c, Color color) {
    final done = c.dailyDone;
    return Bouncy(
      onTap: () => _go(const DailyScreen()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFFFFE29A), const Color(0xFFFFB86B)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: alpha(Colors.black, 0.2), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            const Text('🔎', style: TextStyle(fontSize: 34, decoration: TextDecoration.none)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Mystery', style: kid(19, color: const Color(0xFF5A3A00))),
                  Text(done ? 'Solved today! ✓  Come back tomorrow' : 'New puzzle + streak reward!',
                      style: kid(13, color: const Color(0xFF7A5200), weight: FontWeight.w700)),
                ],
              ),
            ),
            if (!done)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFF5A5F), borderRadius: BorderRadius.circular(12)),
                child: Text('NEW', style: kid(12, color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String emoji, String label, Color color, VoidCallback onTap) {
    return Bouncy(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: darken(color, 0.2), offset: const Offset(0, 4)),
            BoxShadow(color: alpha(Colors.black, 0.15), blurRadius: 8, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30, decoration: TextDecoration.none)),
            const SizedBox(height: 2),
            Text(label, style: kid(14, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Gentle attention pulse for the very first "Play" button.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(scale: 1 + 0.035 * Curves.easeInOut.transform(_c.value), child: child),
      child: widget.child,
    );
  }
}
