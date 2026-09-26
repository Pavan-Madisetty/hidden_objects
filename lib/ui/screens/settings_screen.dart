import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/utils.dart';
import '../../services/analytics_service.dart';
import '../../services/audio_service.dart';
import '../../state/app_scope.dart';
import '../widgets/bouncy.dart';
import '../widgets/dialogs.dart';
import '../widgets/sky_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: AppScope.read(context).data.nickname);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final d = c.data;
    return Scaffold(
      body: SkyBackground(
        palette: c.palette,
        emojis: const ['⚙️', '🎵', '✨'],
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    RoundButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () {
                        c.setNickname(_name.text);
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Settings', style: kid(26, color: Colors.white, weight: FontWeight.w900))),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  children: [
                    _panel(
                      title: '🎵 Sound',
                      child: Column(
                        children: [
                          _slider('Music', d.musicVol, c.setMusicVolume),
                          _slider('Sound effects', d.sfxVol, (v) => c.setSfxVolume(v), onEnd: () => c.audio.sfx(Sfx.found)),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Mute everything', style: kid(15)),
                            value: d.muted,
                            onChanged: (v) => c.setMuted(v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _panel(
                      title: '🙂 Explorer name',
                      child: TextField(
                        controller: _name,
                        maxLength: 16,
                        style: kid(16),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFFF3F0FA),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          hintText: 'Pick a fun name',
                        ),
                        onSubmitted: c.setNickname,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _panel(
                      title: '🔒 Privacy',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Share anonymous play stats', style: kid(15)),
                            subtitle: Text(
                              'Helps us make levels better. No names, no personal data.',
                              style: kid(11, color: const Color(0xFF6E6690), weight: FontWeight.w600),
                            ),
                            value: d.analyticsOn,
                            onChanged: (v) => c.setAnalytics(v),
                          ),
                          if (!d.adsRemoved)
                            Text('Ads are only shown between levels, never during play, and never before level 8.',
                                style: kid(11, color: const Color(0xFF6E6690), weight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _panel(
                      title: '🧰 More',
                      child: Column(
                        children: [
                          _tile('📊', 'Level insights', 'For grown-ups and creators', () {
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const InsightsScreen()));
                          }),
                          _tile('♻️', 'Restart adventure', 'Erase progress and start over', () async {
                            final ok = await confirmDialog(
                              context,
                              title: 'Start over?',
                              message: 'This erases all stars, coins and levels. It cannot be undone.',
                              yes: 'Erase',
                              no: 'Keep playing',
                            );
                            if (!ok || !mounted) return;
                            await c.resetProgress();
                            if (!mounted) return;
                            _name.text = c.data.nickname;
                            showSnack(context, 'A fresh adventure begins!');
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(child: Text('${Strings.appName} • v1.0', style: kid(12, color: alpha(Colors.white, 0.85)))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged, {VoidCallback? onEnd}) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: kid(14))),
        Expanded(
          child: Slider(
            value: clampD(value, 0.0, 1.0),
            onChanged: onChanged,
            onChangeEnd: onEnd == null ? null : (_) => onEnd(),
          ),
        ),
      ],
    );
  }

  Widget _tile(String emoji, String title, String sub, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Text(emoji, style: const TextStyle(fontSize: 28, decoration: TextDecoration.none)),
      title: Text(title, style: kid(15)),
      subtitle: Text(sub, style: kid(11, color: const Color(0xFF6E6690), weight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  Widget _panel({required String title, required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: alpha(Colors.white, 0.94),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: kid(18, weight: FontWeight.w900)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

/// Local funnel: shows where players start, finish, fail or quit each level.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Level insights')),
      body: FutureBuilder<Map<String, LevelStat>>(
        future: c.services.analytics.funnel(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final m = snap.data ?? const <String, LevelStat>{};
          if (m.isEmpty) return const Center(child: Text('Play a few levels to see insights.'));
          final keys = m.keys.toList()..sort((a, b) => a.compareTo(b));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final k in keys)
                ListTile(
                  dense: true,
                  title: Text('Level $k'),
                  subtitle: Text(
                    'starts ${m[k]!.starts} • done ${m[k]!.completes} • failed ${m[k]!.fails} • quit ${m[k]!.quits} • hints ${m[k]!.hints}',
                  ),
                  trailing: Text('${(m[k]!.completionRate * 100).round()}%'),
                ),
            ],
          );
        },
      ),
    );
  }
}
