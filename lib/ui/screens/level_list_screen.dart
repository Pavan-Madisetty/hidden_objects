import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../models/world_def.dart';
import '../../services/audio_service.dart';
import '../../state/app_scope.dart';
import '../../state/game_controller.dart';
import '../widgets/bouncy.dart';
import '../widgets/difficulty_picker.dart';
import '../widgets/dialogs.dart';
import '../widgets/sky_background.dart';
import 'level_sheet.dart';

const double _sectionH = 330;

/// Every world with all of its levels in a simple grid: stars, difficulty
/// colour and locks are visible at a glance.
class LevelListScreen extends StatefulWidget {
  const LevelListScreen({super.key});

  @override
  State<LevelListScreen> createState() => _LevelListScreenState();
}

class _LevelListScreenState extends State<LevelListScreen> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final worlds = c.registry.worlds;
    final cur = c.registry.worldOfLevel(c.continueLevelId);
    _scroll ??= ScrollController(initialScrollOffset: (cur?.index ?? 0) * _sectionH);

    return Scaffold(
      body: SkyBackground(
        palette: c.palette,
        emojis: const ['📋', '⭐', '🔍', '🎈'],
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    RoundButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                    const SizedBox(width: 12),
                    Expanded(child: Text('All Levels', style: kid(26, color: Colors.white, weight: FontWeight.w900))),
                    StatChip(emoji: '⭐', value: '${c.data.totalStars}'),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                decoration: BoxDecoration(color: alpha(Colors.white, 0.94), borderRadius: BorderRadius.circular(22)),
                child: Column(
                  children: [
                    Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text('Difficulty', style: kid(14)))),
                    DifficultyPicker(controller: c),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: worlds.length,
                  itemBuilder: (context, i) => SizedBox(height: _sectionH, child: _WorldBlock(world: worlds[i], controller: c)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldBlock extends StatelessWidget {
  const _WorldBlock({required this.world, required this.controller});
  final WorldDef world;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final unlocked = c.progression.isWorldUnlocked(world, c.data);
    final done = c.progression.completedIn(world, c.data);
    final stars = c.progression.starsIn(world, c.data);
    final first = c.registry.firstLevelId(world);
    final accent = unlocked ? world.theme.accent : const Color(0xFF9E98B5);

    return Column(
      children: [
        Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [lighten(accent, 0.1), darken(accent, 0.12)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Text(unlocked ? world.emoji : '🔒', style: const TextStyle(fontSize: 34, decoration: TextDecoration.none)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${world.index + 1}. ${world.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: kid(19, color: Colors.white, weight: FontWeight.w900)),
                    Text(
                      unlocked
                          ? '$done / ${world.levelCount} done   ⭐ $stars / ${world.levelCount * 3}'
                          : c.progression.missingRequirements(world, c.data).join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: kid(11, color: Colors.white, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 8,
            childAspectRatio: 0.72,
            children: [for (var i = 0; i < world.levelCount; i++) _tile(context, c, first + i)],
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, GameController c, int levelId) {
    final cfg = c.levelById(levelId);
    if (cfg == null) return const SizedBox.shrink();
    final unlocked = c.progression.isLevelUnlocked(levelId, c.data);
    final stars = c.data.stars[levelId] ?? 0;
    final diff = cfg.tutorial ? cfg.difficulty : (c.difficultyPref ?? cfg.difficulty);
    final tier = difficultyColor(diff);
    final base = unlocked ? tier : const Color(0xFFB9B3CC);
    final isCurrent = levelId == c.continueLevelId;

    return Bouncy(
      onTap: () {
        if (!unlocked) {
          c.audio.sfx(Sfx.wrong);
          final inWorld = c.progression.isWorldUnlocked(world, c.data);
          showSnack(context, inWorld ? 'Finish level ${levelId - 1} first!' : 'Unlock this world first!');
          return;
        }
        showLevelSheet(context, cfg);
      },
      child: Container(
        decoration: BoxDecoration(
          color: alpha(Colors.white, 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isCurrent ? const Color(0xFFFFB700) : Colors.transparent, width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: base),
              alignment: Alignment.center,
              child: unlocked
                  ? Text('$levelId', style: kid(levelId > 99 ? 12 : 16, color: Colors.white, weight: FontWeight.w900))
                  : const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 4),
            if (unlocked) StarRow(stars: stars, size: 12, gap: 0) else const SizedBox(height: 12),
            const SizedBox(height: 2),
            Text(
              unlocked ? difficultyLabel(diff) : '',
              style: kid(9, color: base, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
