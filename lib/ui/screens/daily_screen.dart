import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../engine/rewards.dart';
import '../../services/audio_service.dart';
import '../../state/app_scope.dart';
import '../widgets/bouncy.dart';
import '../widgets/mascot.dart';
import '../widgets/sky_background.dart';
import 'flow.dart';

/// Daily Mystery: streak calendar, today's rewards and a big start button.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final done = c.dailyDone;
    final streak = c.streak;
    final nextStreak = done ? streak : streak + 1;
    final today = c.now;
    final days = <DateTime>[
      for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day).subtract(Duration(days: i)),
    ];
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      body: SkyBackground(
        palette: c.palette,
        emojis: const ['🔍', '✨', '🌟', '🎁'],
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    RoundButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Daily Mystery', style: kid(26, color: Colors.white, weight: FontWeight.w900))),
                    StatChip(emoji: '🪙', value: '${c.data.coins}'),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                  child: Column(
                    children: [
                      Mascot(emoji: c.characterEmoji, hat: c.hatEmoji, size: 84),
                      const SizedBox(height: 6),
                      SpeechBubble(
                        text: done
                            ? 'Mystery solved! Come back tomorrow for a new one!'
                            : 'A brand new mystery is waiting for you today!',
                        maxWidth: 300,
                      ),
                      const SizedBox(height: 18),
                      _card(
                        child: Column(
                          children: [
                            Text('🔥 $streak day streak', style: kid(24, weight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              'Best: ${c.data.bestStreak}  •  Missing a day is OK — your streak is forgiving!',
                              textAlign: TextAlign.center,
                              style: kid(12, color: const Color(0xFF6E6690), weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final d in days)
                                  _dayDot(
                                    label: names[d.weekday - 1],
                                    done: c.data.dailyDays.contains(dayKey(d)),
                                    isToday: d.day == today.day && d.month == today.month,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _card(
                        child: Column(
                          children: [
                            Text("Today's rewards", style: kid(18, weight: FontWeight.w900)),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _reward('🪙', '+${RewardCalculator.dailyCompletionBonus}', 'bonus coins'),
                                _reward('⭐', '+${RewardCalculator.dailyXp}', 'XP'),
                                _reward('🔥', '+${RewardCalculator.streakCoins(nextStreak <= 0 ? 1 : nextStreak)}', 'streak coins'),
                              ],
                            ),
                            if (RewardCalculator.isSpecialDay(nextStreak) && !done)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text('🎁 Special streak day — extra treats!', style: kid(14, color: const Color(0xFFE8590C))),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      PillButton(
                        label: done ? 'Solved today!' : 'Start mystery',
                        emoji: done ? '✅' : '🔍',
                        big: true,
                        color: done ? const Color(0xFFB9B3CC) : const Color(0xFFFF7A59),
                        onTap: done
                            ? null
                            : () {
                                c.audio.sfx(Sfx.tap);
                                openDaily(context);
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: alpha(Colors.white, 0.94),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: alpha(Colors.black, 0.15), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: child,
      );

  Widget _dayDot({required String label, required bool done, required bool isToday}) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? const Color(0xFFFFC53D) : const Color(0xFFEDE9F7),
            border: Border.all(color: isToday ? const Color(0xFFFF7A59) : Colors.transparent, width: 3),
          ),
          alignment: Alignment.center,
          child: Text(done ? '⭐' : '', style: const TextStyle(fontSize: 18, decoration: TextDecoration.none)),
        ),
        const SizedBox(height: 4),
        Text(label, style: kid(11, color: const Color(0xFF6E6690))),
      ],
    );
  }

  Widget _reward(String emoji, String value, String label) => Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30, decoration: TextDecoration.none)),
          Text(value, style: kid(18, weight: FontWeight.w900)),
          Text(label, style: kid(11, color: const Color(0xFF6E6690))),
        ],
      );
}
