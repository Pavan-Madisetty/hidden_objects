import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../engine/progression.dart';
import '../../services/audio_service.dart';
import '../../state/game_controller.dart';
import '../widgets/bouncy.dart';

/// "LEVEL COMPLETE" celebration: quick, cheerful, never flashing.
class LevelCompleteOverlay extends StatefulWidget {
  const LevelCompleteOverlay({
    super.key,
    required this.outcome,
    required this.controller,
    required this.onNext,
    required this.onReplay,
    required this.onMap,
    required this.hasNext,
  });

  final LevelOutcome outcome;
  final GameController controller;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onMap;
  final bool hasNext;

  @override
  State<LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends State<LevelCompleteOverlay> {
  int _stars = 0;
  bool _coins = false;
  bool _xp = false;
  bool _banners = false;
  bool _buttons = false;
  bool _dead = false;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    _dead = true;
    super.dispose();
  }

  Future<bool> _wait(int ms) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    return !_dead && mounted;
  }

  Future<void> _run() async {
    final audio = widget.controller.audio;
    final o = widget.outcome;
    if (!await _wait(450)) return;
    for (var i = 1; i <= o.stars; i++) {
      setState(() => _stars = i);
      audio.sfx(Sfx.star);
      if (!await _wait(380)) return;
    }
    if (!await _wait(150)) return;
    setState(() => _coins = true);
    audio.sfx(Sfx.coin);
    if (!await _wait(900)) return;
    setState(() {
      _xp = true;
      _buttons = true;
    });
    if (o.leveledUp || o.unlockedWorld != null || o.streak != null) {
      if (!await _wait(500)) return;
      setState(() => _banners = true);
      audio.sfx(o.unlockedWorld != null ? Sfx.unlock : Sfx.daily);
    } else {
      setState(() => _banners = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.outcome;
    final title = o.config.isDaily ? 'MYSTERY SOLVED!' : (o.config.isBonus ? 'BONUS CLEARED!' : 'LEVEL COMPLETE!');
    return Container(
      color: alpha(const Color(0xFF1B1140), 0.55),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(18),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: alpha(Colors.black, 0.3), blurRadius: 28, offset: const Offset(0, 12))],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 46, decoration: TextDecoration.none)),
                Text(title, style: kid(26, weight: FontWeight.w900, color: const Color(0xFFFF7A29))),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 3; i++) _StarPop(on: i <= _stars, size: i == 2 ? 68 : 56),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _coins ? 1 : 0,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 28, decoration: TextDecoration.none)),
                          const SizedBox(width: 6),
                          if (_coins)
                            TweenAnimationBuilder<int>(
                              tween: IntTween(begin: 0, end: o.totalCoins),
                              duration: const Duration(milliseconds: 800),
                              builder: (context, v, _) => Text('+$v Coins', style: kid(28, color: const Color(0xFFE59A00))),
                            )
                          else
                            Text('+0 Coins', style: kid(28)),
                        ],
                      ),
                      if (o.reward.newStars > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('+${o.reward.newStars} Star${o.reward.newStars == 1 ? '' : 's'} ⭐', style: kid(18, color: const Color(0xFF6C5CE7))),
                        ),
                      const SizedBox(height: 4),
                      for (final l in o.reward.lines.take(4))
                        Text('${l.label}  +${l.coins * o.config.rewardMultiplier}', style: kid(13, color: const Color(0xFF8A82A6), weight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _xp ? 1 : 0,
                  child: _XpBar(controller: widget.controller, gained: o.reward.xp, animate: _xp),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: !_banners
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          children: [
                            if (o.leveledUp) _banner('🔎', 'Explorer Level ${o.levelAfter}!', const Color(0xFF6C5CE7)),
                            if (o.unlockedWorld != null)
                              _banner(o.unlockedWorld!.emoji, 'New world: ${o.unlockedWorld!.name}!', const Color(0xFF33C481)),
                            if (o.streak != null)
                              _banner('🔥', 'Day ${o.streak} streak!  +${o.streakCoins} coins${o.streakSpecial ? '  + Golden Star hat' : ''}', const Color(0xFFFF7A29)),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _buttons ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_buttons,
                    child: Column(
                      children: [
                        if (widget.hasNext)
                          PillButton(label: 'Next level', emoji: '▶️', big: true, width: double.infinity, color: const Color(0xFF33C481), onTap: widget.onNext),
                        if (!widget.hasNext)
                          PillButton(label: 'Back to map', emoji: '🗺️', big: true, width: double.infinity, color: const Color(0xFF33C481), onTap: widget.onMap),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (!o.config.isDaily) ...[
                              Expanded(
                                child: PillButton(label: o.stars < 3 ? 'Get 3 stars' : 'Replay', emoji: '🔁', compact: true, color: const Color(0xFF6C8CFF), onTap: widget.onReplay),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (widget.hasNext)
                              Expanded(
                                child: PillButton(label: 'Map', emoji: '🗺️', compact: true, color: const Color(0xFFB0A8C9), onTap: widget.onMap),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _banner(String emoji, String text, Color c) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: alpha(c, 0.14), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22, decoration: TextDecoration.none)),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: kid(15, color: c))),
        ],
      ),
    );
  }
}

class _StarPop extends StatelessWidget {
  const _StarPop({required this.on, required this.size});
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: on ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 550),
      curve: Curves.elasticOut,
      builder: (context, v, _) => Transform.scale(
        scale: 0.75 + 0.35 * v,
        child: Icon(
          Icons.star_rounded,
          size: size,
          color: mix(const Color(0x2A000000), const Color(0xFFFFC42E), clampD(v, 0.0, 1.0)),
        ),
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.controller, required this.gained, required this.animate});
  final GameController controller;
  final int gained;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final xp = controller.data.xp;
    final before = clampI(xp - gained, 0, xp);
    final lvl = Progression.explorerLevel(xp);
    final startProg = Progression.explorerLevel(before) == lvl ? Progression.levelProgress(before) : 0.0;
    final endProg = Progression.levelProgress(xp);
    return Column(
      children: [
        Text('🔎 Explorer Level $lvl   +$gained XP', style: kid(15, color: const Color(0xFF6C5CE7))),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: startProg, end: animate ? endProg : startProg),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 12,
              backgroundColor: const Color(0x1A000000),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
            ),
          ),
        ),
      ],
    );
  }
}
