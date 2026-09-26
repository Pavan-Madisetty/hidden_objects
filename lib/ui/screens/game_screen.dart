import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/navigation.dart';
import '../../core/strings.dart';
import '../../core/utils.dart';
import '../../engine/level_session.dart';
import '../../engine/rewards.dart';
import '../../models/level_config.dart';
import '../../models/world_def.dart';
import '../../services/audio_service.dart';
import '../../state/app_scope.dart';
import '../../state/game_controller.dart';
import '../scene/scene_view.dart';
import '../widgets/bouncy.dart';
import '../widgets/dialogs.dart';
import '../widgets/mascot.dart';
import '../widgets/particles.dart';
import 'level_complete.dart';

/// The core play screen: scene + HUD + object list + rewards.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.config});
  final LevelConfig config;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameController _c;
  late LevelSession _s;
  late WorldDef _world;
  bool _ready = false;

  final GlobalKey<SceneViewState> _sceneKey = GlobalKey<SceneViewState>();
  final ParticleSystem _confetti = ParticleSystem();

  Timer? _clock;
  Timer? _hintTimer;
  Timer? _bubbleTimer;
  Timer? _toastTimer;
  Timer? _introTimer;
  Timer? _handTimer;

  HintResult? _hint;
  DateTime _hintReadyAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _bubble;
  int _pulse = 0;
  String? _toast;
  String? _intro;
  Offset? _handAt;

  bool _paused = false;
  bool _completing = false;
  bool _failedShown = false;
  bool _leaving = false;
  LevelOutcome? _outcome;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _c = AppScope.read(context);
    final cfg = widget.config;
    _world = _c.worldOf(cfg);
    _s = _c.createSession(cfg);
    _s.addListener(_onSession);
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) => _s.tick(250));
    _c.levelStarted(cfg);
    _c.audio.playMusic(_c.musicFor(cfg));

    if (cfg.tutorial) {
      _bubble = 'Find the teddy bear 🧸';
      _handTimer = Timer(const Duration(milliseconds: 3200), () {
        if (!mounted || _s.found.isNotEmpty) return;
        final it = _s.layout.item(cfg.targets.first);
        if (it != null) setState(() => _handAt = it.pos);
      });
    }
    final introKey = cfg.introKey;
    if (introKey != null && !_c.introSeen(introKey)) {
      _intro = Strings.intros[introKey];
      _c.markIntroSeen(introKey);
      _introTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _intro = null);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _hintTimer?.cancel();
    _bubbleTimer?.cancel();
    _toastTimer?.cancel();
    _introTimer?.cancel();
    _handTimer?.cancel();
    if (_ready) {
      _s.removeListener(_onSession);
      _s.dispose();
    }
    _confetti.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_s.running && !_paused) _pause();
    }
  }

  // ---- session reactions ---------------------------------------------------------

  void _onSession() {
    if (_s.completed && !_completing) {
      _completing = true;
      _finish();
    } else if (_s.failed && !_failedShown && !_completing) {
      _failedShown = true;
      _c.levelFailed(_s);
      _c.audio.sfx(Sfx.wrong);
      if (mounted) setState(() {});
    } else if (!_s.failed && _failedShown) {
      _failedShown = false; // time was added
      if (mounted) setState(() {});
    }
  }

  Future<void> _finish() async {
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    final out = await _c.completeLevel(_s);
    if (!mounted) return;
    setState(() {
      _outcome = out;
      _bubble = null;
    });
    _c.audio.sfx(Sfx.complete);
    _confetti.confetti(MediaQuery.of(context).size.width, count: 70);
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _confetti.confetti(MediaQuery.of(context).size.width, count: 40);
    });
  }

  void _say(String? text, {int ms = 2400}) {
    _bubbleTimer?.cancel();
    setState(() {
      _bubble = text;
      _pulse++;
    });
    if (text != null && ms > 0) {
      _bubbleTimer = Timer(Duration(milliseconds: ms), () {
        if (mounted) setState(() => _bubble = null);
      });
    }
  }

  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _onOutcome(TapOutcome o) {
    if (!mounted) return;
    final audio = _c.audio;
    final scene = _sceneKey.currentState;
    switch (o.kind) {
      case TapKind.found:
      case TapKind.bonusFound:
        audio.sfx(Sfx.found);
        if (o.kind == TapKind.bonusFound) Future<void>.delayed(const Duration(milliseconds: 180), () => audio.sfx(Sfx.coin));
        scene?.burst(o.pos, big: true);
        _c.objectFound(_s, o.item!.id);
        if (_hint != null) setState(() => _hint = null);
        if (widget.config.tutorial && _s.found.length == 1) {
          setState(() => _handAt = null);
          _say('Great! 🎉');
          Future<void>.delayed(const Duration(milliseconds: 1900), () {
            if (mounted && !_s.completed) _say('Now find the rest!', ms: 3000);
          });
        } else if (!_s.completed) {
          final left = _s.targetsTotal - _s.targetsFound;
          if (o.kind == TapKind.bonusFound) {
            _say('Golden bonus! +25 coins ✨');
          } else if (left == 1) {
            _say('Just one more!');
          } else if (_s.found.length % 2 == 0) {
            _say(Strings.foundCheers[_s.found.length % Strings.foundCheers.length]);
          } else {
            setState(() => _pulse++);
          }
        }
        if (o.unlocked.isNotEmpty) {
          Future<void>.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            audio.sfx(Sfx.door);
            final p = _world.propById(o.unlocked.first);
            _showToast('🔓 ${_cap(p?.name ?? 'Something')} can be opened now!');
          });
        }
        break;
      case TapKind.wrong:
        audio.sfx(Sfx.wrong);
        if (o.item != null && _s.wrongTaps % 3 == 0) {
          _say("That's a ${o.item!.def.name} - not what we need!");
        } else if (_s.wrongTaps % 5 == 0) {
          _say(Strings.wrongTips[(_s.wrongTaps ~/ 5) % Strings.wrongTips.length]);
        }
        break;
      case TapKind.propOpened:
        final k = o.prop!.kind;
        audio.sfx(k == PropKind.cupboard || k == PropKind.curtain ? Sfx.door : Sfx.drawer);
        scene?.burst(o.pos);
        if (o.emptyOpen) {
          _showToast('Nothing here this time!');
        } else if (_s.layout.items.any((i) => i.hiddenIn == o.prop!.id && i.isTarget)) {
          Future<void>.delayed(const Duration(milliseconds: 250), () => audio.sfx(Sfx.pop));
        }
        break;
      case TapKind.propWiggle:
        audio.sfx(Sfx.tap);
        break;
      case TapKind.propLocked:
      case TapKind.propDark:
        audio.sfx(Sfx.wrong);
        _showToast(o.message);
        break;
    }
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ---- hints ----------------------------------------------------------------------

  Future<void> _useHint() async {
    if (!_s.running || _outcome != null) return;
    final now = DateTime.now();
    if (now.isBefore(_hintReadyAt)) {
      _say('Hints are recharging...', ms: 1500);
      return;
    }
    final pay = _c.payForHint();
    if (pay == HintPayment.none) {
      await _offerHintAd();
      return;
    }
    final h = _s.requestHint();
    if (h == null) {
      _c.refundHint(pay);
      return;
    }
    _c.hintUsed(_s, pay);
    _c.audio.sfx(Sfx.hint);
    if (h.room != _s.room) _s.setRoom(h.room);
    setState(() {
      _hint = h;
      _hintReadyAt = now.add(const Duration(seconds: RewardCalculator.hintCooldownSec));
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 4200), () {
      if (mounted) setState(() => _hint = null);
    });
    // Nudge the camera so the highlighted area is on screen.
    Future<void>.delayed(const Duration(milliseconds: 60), () => _sceneKey.currentState?.focusOn(h.center));
    _say(h.propId != null ? 'Try opening something here! 💡' : 'Look around here! 💡', ms: 2600);
  }

  Future<void> _offerHintAd() async {
    _pause(silent: true);
    final ok = await showKidDialog<bool>(
      context,
      emoji: '💡',
      title: 'Out of hints',
      body: Text(_c.canAffordPaidHint
          ? 'Use ${RewardCalculator.hintCost} coins for a hint?'
          : 'Watch a short video for ${RewardCalculator.rewardedAdHints} free hints?'),
      actions: [
        Builder(
          builder: (ctx) => PillButton(
            label: _c.canAffordPaidHint ? 'Use ${RewardCalculator.hintCost} coins' : 'Watch video',
            emoji: _c.canAffordPaidHint ? '🪙' : '🎬',
            width: double.infinity,
            color: const Color(0xFF33C481),
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ),
        Builder(
          builder: (ctx) => PillButton(
            label: 'No thanks',
            compact: true,
            width: double.infinity,
            color: const Color(0xFFB0A8C9),
            onTap: () => Navigator.of(ctx).pop(false),
          ),
        ),
      ],
    );
    if (!mounted) return;
    if (ok == true) {
      if (_c.canAffordPaidHint) {
        // paid hint handled by the next tap on the hint button
      } else {
        await _c.watchAdForHints();
      }
    }
    if (mounted) _resume();
    if (ok == true && mounted) _useHint();
  }

  // ---- pause / exit ---------------------------------------------------------------------

  void _pause({bool silent = false}) {
    if (_paused) return;
    _s.setPaused(true);
    if (!silent) {
      setState(() => _paused = true);
    }
  }

  void _resume() {
    _s.setPaused(false);
    if (_paused) setState(() => _paused = false);
  }

  Future<void> _exit() async {
    if (_leaving) return;
    _leaving = true;
    _c.levelQuit(_s);
    if (mounted) Navigator.of(context).pop();
  }

  void _restart() {
    _c.levelQuit(_s);
    Navigator.of(context).pushReplacement(fadeRoute(GameScreen(config: widget.config)));
  }

  Future<void> _next() async {
    final out = _outcome;
    if (out == null) return;
    await _c.maybeInterstitial(out.config.id);
    if (!mounted) return;
    final next = _c.nextLevelAfter(out.config);
    if (next == null) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(fadeRoute(GameScreen(config: next)));
    }
  }

  Future<void> _addTime() async {
    final ok = await _c.watchAdForTime();
    if (ok && mounted) _s.addTime(30);
  }

  // ---- build ----------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    final theme = _world.theme;
    final frame = mix(theme.accent, const Color(0xFF2B1B5C), 0.62);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_outcome != null) {
          Navigator.of(context).pop();
        } else if (_paused) {
          _resume();
        } else {
          _pause();
        }
      },
      child: Scaffold(
        backgroundColor: frame,
        body: ParticleLayer(
          system: _confetti,
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _hud(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _sceneArea(theme),
                      ),
                    ),
                    _tray(),
                  ],
                ),
              ),
              if (_paused && _outcome == null) _pauseOverlay(),
              if (_s.failed && _outcome == null) _failOverlay(),
              if (_outcome != null)
                LevelCompleteOverlay(
                  outcome: _outcome!,
                  controller: _c,
                  hasNext: _c.nextLevelAfter(_outcome!.config) != null,
                  onNext: _next,
                  onReplay: () {
                    Navigator.of(context).pushReplacement(fadeRoute(GameScreen(config: widget.config)));
                  },
                  onMap: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud() {
    final cfg = widget.config;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          children: [
            RoundButton(icon: Icons.pause_rounded, onTap: _pause),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedBuilder(
                animation: _s,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cfg.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: kid(15, color: Colors.white)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: _s.targetsFound / _s.targetsTotal),
                              duration: const Duration(milliseconds: 400),
                              builder: (context, v, _) => LinearProgressIndicator(
                                value: v,
                                minHeight: 10,
                                backgroundColor: alpha(Colors.white, 0.25),
                                valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD84D)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${_s.targetsFound}/${_s.targetsTotal}', style: kid(14, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _timerChip(),
            const SizedBox(width: 6),
            StatChip(emoji: '🪙', value: '${_c.data.coins}'),
            const SizedBox(width: 8),
            _hintButton(),
          ],
        ),
      ),
    );
  }

  Widget _timerChip() {
    return ValueListenableBuilder<int>(
      valueListenable: _s.seconds,
      builder: (context, secs, _) {
        final left = _s.timeLeftSec;
        final low = left != null && left <= 15;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: low ? const Color(0xFFFF6B6B) : alpha(Colors.white, 0.92),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            left != null ? '⏳ ${formatSeconds(left)}' : '⏱ ${formatSeconds(secs)}',
            style: kid(14, color: low ? Colors.white : const Color(0xFF3A2E5C)),
          ),
        );
      },
    );
  }

  Widget _hintButton() {
    final free = _c.data.freeHints;
    return TweenAnimationBuilder<double>(
      key: ValueKey(_hintReadyAt.millisecondsSinceEpoch),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(seconds: _hintReadyAt.millisecondsSinceEpoch == 0 ? 0 : RewardCalculator.hintCooldownSec),
      builder: (context, v, _) {
        final cooling = _hintReadyAt.millisecondsSinceEpoch != 0 && v < 1.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            RoundButton(
              emoji: '💡',
              size: 50,
              color: cooling ? const Color(0xFFE6E1F2) : const Color(0xFFFFF0A8),
              badge: free > 0 ? '$free' : '${RewardCalculator.hintCost}🪙',
              onTap: _useHint,
            ),
            if (cooling)
              IgnorePointer(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: v,
                    strokeWidth: 4,
                    color: const Color(0xFFFFB100),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _sceneArea(WorldTheme theme) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: alpha(Colors.white, 0.9),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: alpha(Colors.black, 0.35), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: SceneView(
              key: _sceneKey,
              session: _s,
              theme: theme,
              hint: _hint,
              handAt: _handAt,
              onOutcome: _onOutcome,
            ),
          ),
        ),
        // room switcher
        if (widget.config.roomCount > 1)
          Positioned(
            left: 10,
            top: 10,
            child: AnimatedBuilder(
              animation: _s,
              builder: (context, _) => Row(
                children: [
                  for (var r = 0; r < widget.config.roomCount; r++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _roomChip(r),
                    ),
                ],
              ),
            ),
          ),
        // zoom controls
        Positioned(
          right: 10,
          bottom: 10,
          child: Column(
            children: [
              RoundButton(icon: Icons.add_rounded, size: 40, onTap: () => _sceneKey.currentState?.zoomBy(1.5)),
              const SizedBox(height: 8),
              RoundButton(icon: Icons.remove_rounded, size: 40, onTap: () => _sceneKey.currentState?.zoomBy(1 / 1.5)),
            ],
          ),
        ),
        // toast
        Positioned(
          top: 10,
          left: 60,
          right: 60,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _toast == null
                  ? const SizedBox.shrink(key: ValueKey('t0'))
                  : Container(
                      key: ValueKey(_toast),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: alpha(const Color(0xFF3A2E5C), 0.93),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(_toast!, textAlign: TextAlign.center, style: kid(14, color: Colors.white)),
                    ),
            ),
          ),
        ),
        // new-mechanic banner
        if (_intro != null)
          Positioned(
            left: 14,
            right: 14,
            top: 56,
            child: Bouncy(
              onTap: () => setState(() => _intro = null),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: alpha(Colors.black, 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 24, decoration: TextDecoration.none)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_intro!, style: kid(14, weight: FontWeight.w700))),
                  ],
                ),
              ),
            ),
          ),
        // mascot
        Positioned(
          left: 8,
          bottom: 6,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _bubble == null ? 0 : 1,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Mascot(emoji: _c.characterEmoji, hat: _c.hatEmoji, size: 50, pulse: _pulse),
                  const SizedBox(width: 6),
                  Flexible(child: SpeechBubble(text: _bubble, maxWidth: 220)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roomChip(int r) {
    final selected = _s.room == r;
    final left = _s.remainingIn(r);
    return Bouncy(
      onTap: () {
        _c.audio.sfx(Sfx.door);
        _s.setRoom(r);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFD84D) : alpha(Colors.white, 0.92),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: alpha(Colors.black, 0.2), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚪', style: TextStyle(fontSize: 15, decoration: TextDecoration.none)),
            const SizedBox(width: 4),
            Text('Room ${r + 1}', style: kid(13)),
            if (left > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFFF6B6B), borderRadius: BorderRadius.circular(10)),
                child: Text('$left', style: kid(11, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tray() {
    final cfg = widget.config;
    final many = cfg.targets.length + cfg.bonus.length > 9;
    return AnimatedBuilder(
      animation: _s,
      builder: (context, _) {
        final firstUnfound = cfg.targets.firstWhere((t) => !_s.found.contains(t), orElse: () => '');
        final chips = <Widget>[];
        for (final id in cfg.targets) {
          final def = _world.itemById(id);
          if (def == null) continue;
          chips.add(_ObjectChip(
            emoji: def.emoji,
            name: def.name,
            found: _s.found.contains(id),
            compact: many,
            highlight: cfg.tutorial && id == firstUnfound,
          ));
        }
        for (final id in cfg.bonus) {
          final def = _world.itemById(id);
          if (def == null) continue;
          chips.add(_ObjectChip(
            emoji: def.emoji,
            name: 'Bonus!',
            found: _s.found.contains(id),
            compact: many,
            bonus: true,
          ));
        }
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          decoration: BoxDecoration(
            color: alpha(Colors.white, 0.94),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: alpha(Colors.black, 0.25), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: chips,
          ),
        );
      },
    );
  }

  Widget _pauseOverlay() {
    return Container(
      color: alpha(const Color(0xFF1B1140), 0.7),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⏸️', style: TextStyle(fontSize: 46, decoration: TextDecoration.none)),
            Text('Paused', style: kid(28, weight: FontWeight.w900)),
            const SizedBox(height: 16),
            PillButton(label: 'Keep playing', emoji: '▶️', big: true, width: double.infinity, color: const Color(0xFF33C481), onTap: _resume),
            const SizedBox(height: 10),
            PillButton(label: 'Start again', emoji: '🔁', compact: true, width: double.infinity, color: const Color(0xFF6C8CFF), onTap: _restart),
            const SizedBox(height: 10),
            PillButton(label: 'Back to map', emoji: '🗺️', compact: true, width: double.infinity, color: const Color(0xFFB0A8C9), onTap: _exit),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_c.data.muted ? '🔇' : '🔊', style: const TextStyle(fontSize: 22, decoration: TextDecoration.none)),
                  Switch(
                    value: !_c.data.muted,
                    onChanged: (v) => _c.setMuted(!v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failOverlay() {
    return Container(
      color: alpha(const Color(0xFF1B1140), 0.7),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⏰', style: TextStyle(fontSize: 46, decoration: TextDecoration.none)),
            Text("Time's up!", style: kid(28, weight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('You found ${_s.targetsFound} of ${_s.targetsTotal}. So close!', style: kid(16, weight: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            PillButton(label: 'Try again', emoji: '🔁', big: true, width: double.infinity, color: const Color(0xFF33C481), onTap: _restart),
            const SizedBox(height: 10),
            PillButton(label: '+30 seconds (video)', emoji: '🎬', compact: true, width: double.infinity, color: const Color(0xFF6C8CFF), onTap: _addTime),
            const SizedBox(height: 10),
            PillButton(label: 'Back to map', emoji: '🗺️', compact: true, width: double.infinity, color: const Color(0xFFB0A8C9), onTap: _exit),
          ],
        ),
      ),
    );
  }
}

class _ObjectChip extends StatelessWidget {
  const _ObjectChip({
    required this.emoji,
    required this.name,
    required this.found,
    this.compact = false,
    this.highlight = false,
    this.bonus = false,
  });

  final String emoji;
  final String name;
  final bool found;
  final bool compact;
  final bool highlight;
  final bool bonus;

  @override
  Widget build(BuildContext context) {
    final w = compact ? 56.0 : 70.0;
    final base = bonus ? const Color(0xFFFFF3B0) : const Color(0xFFF3F0FF);
    Widget chip = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: w,
      padding: EdgeInsets.symmetric(vertical: compact ? 3 : 5, horizontal: 2),
      decoration: BoxDecoration(
        color: found ? const Color(0xFFD9F7E5) : base,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: found
              ? const Color(0xFF33C481)
              : (highlight ? const Color(0xFFFF7A29) : (bonus ? const Color(0xFFFFC42E) : const Color(0x00000000))),
          width: 2.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: found ? 0.4 : 1,
                child: Text(emoji, style: TextStyle(fontSize: compact ? 22 : 28, height: 1.15, decoration: TextDecoration.none)),
              ),
              if (found) Icon(Icons.check_circle_rounded, color: const Color(0xFF1FA463), size: compact ? 20 : 26),
            ],
          ),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 9 : 10.5,
              fontWeight: FontWeight.w800,
              color: found ? const Color(0xFF7A8F84) : const Color(0xFF3A2E5C),
              decoration: found ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
        ],
      ),
    );
    if (highlight && !found) {
      chip = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (context, v, child) => Transform.scale(scale: 1 + 0.06 * v, child: child),
        child: chip,
      );
    }
    return chip;
  }
}
