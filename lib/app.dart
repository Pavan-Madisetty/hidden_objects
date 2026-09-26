import 'package:flutter/material.dart';

import 'core/navigation.dart';
import 'core/strings.dart';
import 'services/ads_service.dart';
import 'services/iap_service.dart';
import 'state/app_scope.dart';
import 'state/game_controller.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/widgets/dialogs.dart';

class HiddenObjectsApp extends StatelessWidget {
  const HiddenObjectsApp({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    // Wire mock ad / purchase UI. Real SDK adapters replace these services.
    final ads = controller.services.ads;
    if (ads is MockAdsService) {
      ads.presenter = (kind, placement) async {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return true;
        return showMockAd(ctx, kind, placement);
      };
    }
    final iap = controller.services.iap;
    if (iap is MockPurchaseService) {
      iap.presenter = (product) async {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return true;
        return showMockPurchase(ctx, product);
      };
    }

    return AppScope(
      controller: controller,
      child: Builder(
        builder: (context) {
          final c = AppScope.of(context);
          return MaterialApp(
            title: Strings.appName,
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: c.palette.primary,
              fontFamily: null,
            ),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.noScaling),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
