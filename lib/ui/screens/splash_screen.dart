import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/navigation.dart';
import '../../core/strings.dart';
import '../../state/app_scope.dart';
import '../widgets/bouncy.dart';
import '../widgets/mascot.dart';
import '../widgets/sky_background.dart';
import 'menu_screen.dart';

/// Short, friendly splash. Tap to skip.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  Timer? _timer;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1700), _go);
  }

  void _go() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(fadeRoute<void>(const MenuScreen()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: SkyBackground(
          palette: c.palette,
          emojis: const ['🔍', '⭐', '🎈', '🧸', '🍎', '🦆'],
          child: Center(
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Mascot(emoji: c.characterEmoji, hat: c.hatEmoji, size: 110),
                  const SizedBox(height: 12),
                  Text(Strings.appName, style: kid(38, color: Colors.white, weight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('A hidden object adventure', style: kid(15, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
