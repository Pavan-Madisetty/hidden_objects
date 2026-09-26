import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/shop_catalog.dart';

/// Colourful gradient with slowly drifting emoji "bubbles".
class SkyBackground extends StatefulWidget {
  const SkyBackground({
    super.key,
    required this.palette,
    required this.child,
    this.emojis = const ['⭐', '🎈', '🔍', '🧸', '🍎', '🔑', '🦋', '🌈', '🪁', '🍪'],
    this.count = 9,
  });

  final AppPalette palette;
  final Widget child;
  final List<String> emojis;
  final int count;

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bgTop, p.bgBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, box) {
                    final w = box.maxWidth;
                    final h = box.maxHeight;
                    final kids = <Widget>[];
                    for (var i = 0; i < widget.count; i++) {
                      final seed = (i * 37 + 11) % 100 / 100.0;
                      final speed = 0.6 + (i % 4) * 0.25;
                      final t = ((_c.value * speed) + seed) % 1.0;
                      final x = ((i * 0.618) % 1.0) * (w - 40) + sin((t + i) * 2 * pi) * 14;
                      final y = h * (1.05 - t * 1.2);
                      final size = 22.0 + (i % 3) * 8;
                      kids.add(Positioned(
                        left: x,
                        top: y,
                        child: Opacity(
                          opacity: 0.28,
                          child: Text(
                            widget.emojis[i % widget.emojis.length],
                            style: TextStyle(fontSize: size, decoration: TextDecoration.none),
                          ),
                        ),
                      ));
                    }
                    return Stack(children: kids);
                  },
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.6),
                    radius: 1.1,
                    colors: [alpha(Colors.white, 0.28), alpha(Colors.white, 0.0)],
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
