import 'package:flutter/material.dart';

/// Global navigator so services (ads, purchases) can present UI.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (context, anim, secondary) => page,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, anim, secondary, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    );
