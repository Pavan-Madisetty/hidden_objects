import 'package:flutter/material.dart';

import '../../models/level_config.dart';
import '../../services/audio_service.dart';
import '../../state/app_scope.dart';
import '../widgets/bouncy.dart';
import '../widgets/difficulty_picker.dart';
import 'flow.dart';

/// Level preview: pick a difficulty, see stars / best time, then play.
Future<void> showLevelSheet(BuildContext context, LevelConfig cfg) {
  final c = AppScope.read(context);
  c.audio.sfx(Sfx.tap);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _LevelSheet(cfg: cfg, hostContext: context),
  );
}

class _LevelSheet extends StatelessWidget {
  const _LevelSheet({required this.cfg, required this.hostContext});
  final LevelConfig cfg;
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final world = c.registry.byId(cfg.worldId);
    final stars = c.data.stars[cfg.id] ?? 0;
    final best = c.data.bestTime[cfg.id];
    final playCfg = c.applyDifficulty(cfg);
    final tierColor = difficultyColor(playCfg.difficulty);
    final canChange = !cfg.tutorial;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(world.emoji, style: const TextStyle(fontSize: 40, decoration: TextDecoration.none)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Level ${cfg.id}', style: kid(22, weight: FontWeight.w900)),
                      Text(world.name, style: kid(13, color: const Color(0xFF6E6690))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: tierColor, borderRadius: BorderRadius.circular(14)),
                  child: Text(difficultyLabel(playCfg.difficulty), style: kid(13, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StarRow(stars: stars, size: 30),
            const SizedBox(height: 6),
            Text(
              'Find ${playCfg.targets.length} objects'
              '${playCfg.isTimed ? '  •  ⏱ timed' : ''}'
              '${best != null ? '  •  best ${best}s' : ''}',
              style: kid(14, color: const Color(0xFF6E6690)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (canChange) ...[
              Align(alignment: Alignment.centerLeft, child: Text('Difficulty', style: kid(15))),
              const SizedBox(height: 6),
              DifficultyPicker(controller: c),
              const SizedBox(height: 16),
            ],
            PillButton(
              label: stars > 0 ? 'Play again' : 'Play',
              emoji: '▶️',
              big: true,
              width: double.infinity,
              color: const Color(0xFF33C481),
              onTap: () {
                Navigator.of(context).pop();
                openLevel(hostContext, cfg);
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Not now', style: kid(14, color: const Color(0xFF8A82A6))),
            ),
          ],
        ),
      ),
    );
  }
}
