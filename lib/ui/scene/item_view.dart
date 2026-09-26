import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../engine/scene_layout.dart';
import 'prop_view.dart';

/// One findable object (or decoy).
class ItemView extends StatelessWidget {
  const ItemView({
    super.key,
    required this.item,
    required this.found,
    required this.wobble,
    this.popIn = false,
  });

  final PlacedItem item;
  final bool found;
  final int wobble;

  /// Items revealed from inside something pop in with a bounce.
  final bool popIn;

  @override
  Widget build(BuildContext context) {
    final s = item.size;
    Widget glyph = Text(
      item.def.emoji,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: s * 0.82,
        height: 1.0,
        decoration: TextDecoration.none,
        shadows: [Shadow(color: alpha(Colors.black, 0.28), blurRadius: 5, offset: const Offset(0, 3))],
      ),
    );
    if (item.isBonus && !item.isTarget) {
      glyph = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: s * 1.15,
            height: s * 1.15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [alpha(const Color(0xFFFFE066), 0.75), alpha(const Color(0xFFFFE066), 0)]),
            ),
          ),
          glyph,
        ],
      );
    }
    glyph = Wiggle(tick: wobble, amplitude: 0.3, child: glyph);

    if (popIn) {
      glyph = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 550),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: glyph,
      );
    }

    return SizedBox(
      width: s,
      height: s,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: found ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOut,
        builder: (context, v, child) {
          if (v >= 0.999) return const SizedBox.shrink();
          return Opacity(
            opacity: 1 - v,
            child: Transform.scale(scale: 1 + 0.9 * v, child: child),
          );
        },
        child: Center(child: glyph),
      ),
    );
  }
}

/// Pulsing ring that marks the approximate area of a hint.
class HintRing extends StatefulWidget {
  const HintRing({super.key, required this.radius});
  final double radius;

  @override
  State<HintRing> createState() => _HintRingState();
}

class _HintRingState extends State<HintRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = Curves.easeInOut.transform(_c.value);
        final r = widget.radius * (0.9 + 0.12 * v);
        return Container(
          width: r * 2,
          height: r * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: alpha(const Color(0xFFFFF3B0), 0.18 + 0.12 * v),
            border: Border.all(color: alpha(const Color(0xFFFFD84D), 0.9), width: 5),
            boxShadow: [BoxShadow(color: alpha(const Color(0xFFFFE066), 0.7), blurRadius: 18 + 10 * v, spreadRadius: 2)],
          ),
        );
      },
    );
  }
}

/// Tutorial finger that "taps" where the player should look first.
class TutorialHand extends StatefulWidget {
  const TutorialHand({super.key});

  @override
  State<TutorialHand> createState() => _TutorialHandState();
}

class _TutorialHandState extends State<TutorialHand> with SingleTickerProviderStateMixin {
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
      builder: (context, _) {
        final v = Curves.easeInOut.transform(_c.value);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 46 + 34 * v,
              height: 46 + 34 * v,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: alpha(Colors.white, 0.9 - 0.6 * v), width: 4),
              ),
            ),
            Transform.translate(
              offset: Offset(14, 26 - 12 * v),
              child: const Text('👆', style: TextStyle(fontSize: 54, decoration: TextDecoration.none)),
            ),
          ],
        );
      },
    );
  }
}
