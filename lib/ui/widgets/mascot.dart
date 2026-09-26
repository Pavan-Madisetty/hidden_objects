import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils.dart';
import 'bouncy.dart';

/// The cute optional helper. Bounces whenever [pulse] changes.
class Mascot extends StatelessWidget {
  const Mascot({super.key, required this.emoji, this.hat = '', this.size = 64, this.pulse = 0});

  final String emoji;
  final String hat;
  final double size;
  final int pulse;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(pulse),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, v, child) {
        final s = 1 + 0.2 * sin(pi * v);
        final lift = -10 * sin(pi * v);
        return Transform.translate(
          offset: Offset(0, lift),
          child: Transform.scale(scale: s, child: child),
        );
      },
      child: SizedBox(
        width: size,
        height: size * 1.15,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Colors.white, alpha(const Color(0xFFFFE9B8), 1)]),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: alpha(Colors.black, 0.2), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: TextStyle(fontSize: size * 0.58, decoration: TextDecoration.none)),
            ),
            if (hat.isNotEmpty)
              Positioned(
                top: -size * 0.08,
                child: Transform.rotate(
                  angle: -0.15,
                  child: Text(hat, style: TextStyle(fontSize: size * 0.42, decoration: TextDecoration.none)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Speech bubble that fades between messages.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text, this.maxWidth = 240});
  final String? text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(anim), alignment: Alignment.bottomLeft, child: child),
      ),
      child: (text == null || text!.isEmpty)
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Container(
              key: ValueKey(text),
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: alpha(Colors.black, 0.18), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Text(text!, style: kid(15)),
            ),
    );
  }
}
