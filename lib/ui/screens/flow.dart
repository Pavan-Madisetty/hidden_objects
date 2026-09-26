import 'package:flutter/material.dart';

import '../../core/navigation.dart';
import '../../models/level_config.dart';
import '../../state/app_scope.dart';
import '../widgets/dialogs.dart';
import 'game_screen.dart';

/// Opens [cfg] and restores the menu music when the player comes back.
Future<void> openLevel(BuildContext context, LevelConfig cfg) async {
  final c = AppScope.read(context);
  final nav = Navigator.of(context);
  await nav.push(fadeRoute<void>(GameScreen(config: c.applyDifficulty(cfg))));
  c.audio.playMusic('menu');
}

Future<void> openDaily(BuildContext context) async {
  final c = AppScope.read(context);
  if (c.dailyDone) {
    await infoDialog(
      context,
      emoji: '🎉',
      title: 'Mystery solved!',
      message: 'You already solved today\'s Daily Mystery. A new one appears tomorrow!\n\n'
          '🔥 Streak: ${c.streak} day${c.streak == 1 ? '' : 's'}',
    );
    return;
  }
  await openLevel(context, c.dailyConfig());
}
