import 'package:flutter/material.dart';

import '../../models/world_def.dart';
import '../../state/game_controller.dart';
import 'bouncy.dart';

const Color kEasyColor = Color(0xFF33C481);
const Color kMediumColor = Color(0xFFFF9F1C);
const Color kHardColor = Color(0xFFFF5A8A);

Color difficultyColor(Difficulty d) {
  switch (d) {
    case Difficulty.easy:
      return kEasyColor;
    case Difficulty.medium:
      return kMediumColor;
    case Difficulty.hard:
      return kHardColor;
  }
}

String difficultyLabel(Difficulty d) {
  switch (d) {
    case Difficulty.easy:
      return 'Easy';
    case Difficulty.medium:
      return 'Medium';
    case Difficulty.hard:
      return 'Hard';
  }
}

String difficultyHint(Difficulty? d) {
  switch (d) {
    case null:
      return 'Each level gets harder as you go.';
    case Difficulty.easy:
      return '5-7 objects, big and friendly.';
    case Difficulty.medium:
      return '7-10 objects, a little trickier.';
    case Difficulty.hard:
      return '10-15 objects, small and sneaky!';
  }
}

/// Auto / Easy / Medium / Hard selector shared by the menu and level sheet.
class DifficultyPicker extends StatelessWidget {
  const DifficultyPicker({super.key, required this.controller, this.onChanged, this.showHint = true});

  final GameController controller;
  final VoidCallback? onChanged;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cur = c.difficultyPref;
    Widget chip(String label, Difficulty? d, Color color) {
      final on = cur == d;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Bouncy(
            onTap: () {
              c.setDifficultyPref(d);
              onChanged?.call();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? color : const Color(0xFFF1EEF9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: on ? Colors.white : Colors.transparent, width: 2),
              ),
              child: Text(label, style: kid(13, color: on ? Colors.white : const Color(0xFF6E6690))),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            chip('Auto', null, const Color(0xFF6C5CE7)),
            chip('Easy', Difficulty.easy, kEasyColor),
            chip('Medium', Difficulty.medium, kMediumColor),
            chip('Hard', Difficulty.hard, kHardColor),
          ],
        ),
        if (showHint) ...[
          const SizedBox(height: 6),
          Text(difficultyHint(cur), style: kid(12, color: const Color(0xFF6E6690), weight: FontWeight.w700), textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
