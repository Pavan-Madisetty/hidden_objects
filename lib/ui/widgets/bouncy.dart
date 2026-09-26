import 'package:flutter/material.dart';

import '../../core/utils.dart';

TextStyle kid(double size, {Color color = const Color(0xFF3A2E5C), FontWeight weight = FontWeight.w800, double? height}) =>
    TextStyle(fontSize: size, color: color, fontWeight: weight, height: height, decoration: TextDecoration.none);

/// Wraps any child with a friendly "squish" on press.
class Bouncy extends StatefulWidget {
  const Bouncy({super.key, required this.child, this.onTap, this.scaleDown = 0.93});
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  @override
  State<Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<Bouncy> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 100));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _c.forward() : null,
      onTapUp: enabled ? (_) => _c.reverse() : null,
      onTapCancel: enabled ? () => _c.reverse() : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) =>
            Transform.scale(scale: 1 - (1 - widget.scaleDown) * _c.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// Big chunky 3D-style button.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.emoji,
    this.color = const Color(0xFFFF8A3D),
    this.textColor = Colors.white,
    this.big = false,
    this.width,
    this.compact = false,
  });

  final String label;
  final String? emoji;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  final bool big;
  final double? width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final base = disabled ? const Color(0xFFB8B3C6) : color;
    final h = big ? 68.0 : (compact ? 44.0 : 56.0);
    final fs = big ? 26.0 : (compact ? 16.0 : 20.0);
    return Bouncy(
      onTap: onTap,
      child: Container(
        width: width,
        height: h,
        padding: EdgeInsets.symmetric(horizontal: big ? 30 : 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lighten(base, 0.22), base],
          ),
          borderRadius: BorderRadius.circular(h / 2),
          boxShadow: [
            BoxShadow(color: darken(base, 0.28), offset: const Offset(0, 5)),
            BoxShadow(color: alpha(Colors.black, 0.18), blurRadius: 12, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: TextStyle(fontSize: fs + 2, decoration: TextDecoration.none)),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kid(fs, color: textColor, weight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round button with an emoji or icon.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.onTap,
    this.emoji,
    this.icon,
    this.size = 46,
    this.color = Colors.white,
    this.iconColor = const Color(0xFF3A2E5C),
    this.badge,
  });

  final VoidCallback? onTap;
  final String? emoji;
  final IconData? icon;
  final double size;
  final Color color;
  final Color iconColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Bouncy(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: alpha(Colors.black, 0.22), offset: const Offset(0, 3), blurRadius: 6),
                ],
              ),
              alignment: Alignment.center,
              child: emoji != null
                  ? Text(emoji!, style: TextStyle(fontSize: size * 0.5, decoration: TextDecoration.none))
                  : Icon(icon, size: size * 0.55, color: iconColor),
            ),
            if (badge != null)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A5F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(badge!, style: kid(12, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small stat pill (coins, stars, xp, streak).
class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.emoji, required this.value, this.onTap, this.color = Colors.white});
  final String emoji;
  final String value;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Bouncy(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: alpha(color, 0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: alpha(Colors.black, 0.15), offset: const Offset(0, 2), blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16, decoration: TextDecoration.none)),
            const SizedBox(width: 5),
            Text(value, style: kid(15)),
          ],
        ),
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 22, this.of = 3, this.gap = 1.0});
  final int stars;
  final double size;
  final int of;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < of; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gap),
            child: Icon(
              Icons.star_rounded,
              size: size,
              color: i < stars ? const Color(0xFFFFC42E) : const Color(0x33000000),
            ),
          ),
      ],
    );
  }
}
