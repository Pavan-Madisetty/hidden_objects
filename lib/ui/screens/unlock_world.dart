import 'package:flutter/material.dart';

import '../../models/world_def.dart';
import '../../services/audio_service.dart';
import '../../state/app_scope.dart';
import '../widgets/bouncy.dart';
import '../widgets/dialogs.dart';

/// Opens a locked world by watching short videos: one video for every world
/// that is skipped on the way. Each video is a separate, optional tap.
Future<void> offerWorldUnlock(BuildContext context, WorldDef target) async {
  final c = AppScope.read(context);
  final total = c.adsNeededFor(target);
  if (total == 0) return;
  final reqs = c.progression.missingRequirements(target, c.data);

  while (context.mounted) {
    final left = c.worldsToUnlockFor(target);
    if (left.isEmpty) return;
    final done = total - left.length;
    final go = await showKidDialog<bool>(
      context,
      emoji: '🔓',
      title: 'Unlock ${target.name}?',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            left.length == 1
                ? 'Watch 1 short video to open ${left.first.name}.'
                : 'Skipping ahead needs 1 video for each world you skip: '
                    '${left.length} videos to reach ${target.name}.',
          ),
          if (left.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              [for (final w in left) '${w.emoji} ${w.name}'].join('  →  '),
              style: kid(14, color: const Color(0xFF6E6690)),
              textAlign: TextAlign.center,
            ),
          ],
          if (reqs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Or play for free: ${reqs.join(' • ')}',
              style: kid(12, color: const Color(0xFF8A82A6), weight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        Builder(
          builder: (ctx) => PillButton(
            label: 'Watch video ${done + 1} of $total',
            emoji: '🎬',
            width: double.infinity,
            color: const Color(0xFF33C481),
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ),
        Builder(
          builder: (ctx) => PillButton(
            label: 'Not now',
            compact: true,
            width: double.infinity,
            color: const Color(0xFFB0A8C9),
            onTap: () => Navigator.of(ctx).pop(false),
          ),
        ),
      ],
    );
    if (go != true || !context.mounted) return;
    final opened = await c.watchAdToUnlockWorld(target);
    if (!context.mounted) return;
    if (opened == null) {
      showSnack(context, 'The video did not finish, so nothing was unlocked.');
      return;
    }
    c.audio.sfx(Sfx.complete);
    showSnack(context, '${opened.emoji} ${opened.name} unlocked!');
  }
}
