import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/shop_catalog.dart';
import '../../engine/rewards.dart';
import '../../services/audio_service.dart';
import '../../state/app_scope.dart';
import '../../state/game_controller.dart';
import '../widgets/bouncy.dart';
import '../widgets/dialogs.dart';
import '../widgets/mascot.dart';
import '../widgets/sky_background.dart';
import 'flow.dart';

/// Shop, bonus rooms, free coins and the (parent-gated) family store.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late int _tab = widget.initialTab;
  static const _tabs = ['Shop', 'Bonus', 'Free', 'Family'];
  static const _icons = ['🛍️', '🗝️', '🎁', '👨‍👩‍👧'];

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Scaffold(
      body: SkyBackground(
        palette: c.palette,
        emojis: const ['🪙', '🎁', '✨', '⭐'],
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    RoundButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Treasure Shop', style: kid(26, color: Colors.white, weight: FontWeight.w900))),
                    StatChip(emoji: '🪙', value: '${c.data.coins}'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Bouncy(
                            onTap: () {
                              c.audio.sfx(Sfx.tap);
                              setState(() => _tab = i);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _tab == i ? Colors.white : alpha(Colors.white, 0.35),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                children: [
                                  Text(_icons[i], style: const TextStyle(fontSize: 20, decoration: TextDecoration.none)),
                                  Text(_tabs[i], style: kid(12, color: _tab == i ? const Color(0xFF3A2E5C) : Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_tab),
                    child: _body(c),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(GameController c) {
    switch (_tab) {
      case 0:
        return _shop(c);
      case 1:
        return _bonus(c);
      case 2:
        return _free(c);
      default:
        return _family(c);
    }
  }

  // ---- shop -----------------------------------------------------------------------

  Widget _shop(GameController c) {
    Widget section(String title, ShopCategory cat) {
      final list = ShopCatalog.inCategory(cat);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(title, style: kid(20, color: Colors.white, weight: FontWeight.w900)),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final i in list) _shopTile(c, i)],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
      children: [
        Center(child: Mascot(emoji: c.characterEmoji, hat: c.hatEmoji, size: 80)),
        section('Friends', ShopCategory.character),
        section('Hats', ShopCategory.hat),
        section('Themes', ShopCategory.theme),
      ],
    );
  }

  Widget _shopTile(GameController c, ShopItem i) {
    final owned = c.owns(i.id);
    final equipped = owned && c.isEquipped(i);
    final reached = c.levelReached(i);
    final isTheme = i.category == ShopCategory.theme;
    final pal = isTheme ? ShopCatalog.palette(i.id) : null;

    String status;
    if (equipped) {
      status = 'Using ✓';
    } else if (owned) {
      status = 'Use';
    } else if (i.special) {
      status = 'Special';
    } else if (!reached) {
      status = '🔒 Lv ${i.unlockLevel}';
    } else {
      status = '🪙 ${i.price}';
    }

    return Bouncy(
      onTap: () {
        if (owned) {
          c.audio.sfx(Sfx.tap);
          c.equip(i);
          return;
        }
        final err = c.buy(i);
        if (err != null) {
          c.audio.sfx(Sfx.wrong);
          showSnack(context, err);
        } else {
          c.audio.sfx(Sfx.complete);
          showSnack(context, 'Yay! You got ${i.name}!');
        }
      },
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: equipped ? const Color(0xFFFFF3C4) : alpha(Colors.white, 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: equipped ? const Color(0xFFFFB700) : Colors.transparent, width: 3),
        ),
        child: Column(
          children: [
            if (pal != null)
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [pal.bgTop, pal.bgBottom], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(color: Colors.white, width: 3),
                ),
              )
            else
              Text(i.emoji.isEmpty ? '🚫' : i.emoji, style: const TextStyle(fontSize: 38, decoration: TextDecoration.none)),
            const SizedBox(height: 4),
            Text(i.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: kid(13)),
            Text(
              status,
              style: kid(12, color: owned || reached ? const Color(0xFF5B4B8A) : const Color(0xFF9A93B5)),
            ),
          ],
        ),
      ),
    );
  }

  // ---- bonus rooms ------------------------------------------------------------------

  Widget _bonus(GameController c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: [
        Text(
          'Secret rooms full of extra treasure! Each visit costs 🪙 ${RewardCalculator.bonusRoomEntryCost}.',
          style: kid(14, color: Colors.white),
        ),
        const SizedBox(height: 12),
        for (final d in BonusRoomDef.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _panel(
              child: Row(
                children: [
                  Text(c.bonusRoomOpen(d) ? d.emoji : '🔒', style: const TextStyle(fontSize: 40, decoration: TextDecoration.none)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, style: kid(18, weight: FontWeight.w900)),
                        Text(
                          c.bonusRoomOpen(d)
                              ? 'Best time: ${c.data.bonusBest['${d.levelId}'] == null ? '—' : formatSeconds(c.data.bonusBest['${d.levelId}']!)}'
                              : 'Reach Explorer Level ${d.unlockLevel}',
                          style: kid(12, color: const Color(0xFF6E6690)),
                        ),
                      ],
                    ),
                  ),
                  PillButton(
                    label: 'Enter',
                    compact: true,
                    color: c.bonusRoomOpen(d) ? const Color(0xFF33C481) : const Color(0xFFB9B3CC),
                    onTap: () {
                      if (!c.bonusRoomOpen(d)) {
                        c.audio.sfx(Sfx.wrong);
                        showSnack(context, 'Reach Explorer Level ${d.unlockLevel} to open this room!');
                        return;
                      }
                      final cfg = c.enterBonusRoom(d);
                      if (cfg == null) {
                        c.audio.sfx(Sfx.wrong);
                        showSnack(context, 'You need 🪙 ${RewardCalculator.bonusRoomEntryCost} to enter.');
                        return;
                      }
                      openLevel(context, cfg);
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---- free coins ---------------------------------------------------------------------

  Widget _free(GameController c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: [
        _panel(
          child: Row(
            children: [
              const Text('🎬', style: TextStyle(fontSize: 40, decoration: TextDecoration.none)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Watch a short video', style: kid(17, weight: FontWeight.w900)),
                    Text('Get 🪙 ${RewardCalculator.rewardedAdCoins}. Always your choice!', style: kid(12, color: const Color(0xFF6E6690))),
                  ],
                ),
              ),
              PillButton(
                label: 'Watch',
                compact: true,
                color: const Color(0xFFFF7A59),
                onTap: () async {
                  final ok = await c.watchAdForCoins();
                  if (!mounted) return;
                  if (ok) {
                    c.audio.sfx(Sfx.complete);
                    showSnack(context, '+${RewardCalculator.rewardedAdCoins} coins!');
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          child: Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 40, decoration: TextDecoration.none)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Free hints: ${c.data.freeHints}', style: kid(17, weight: FontWeight.w900)),
                    Text('You get 3 free hints again every day. Or watch a video for ${RewardCalculator.rewardedAdHints} more.',
                        style: kid(12, color: const Color(0xFF6E6690))),
                  ],
                ),
              ),
              PillButton(
                label: 'Watch',
                compact: true,
                color: const Color(0xFF5B8DEF),
                onTap: () async {
                  final ok = await c.watchAdForHints();
                  if (!mounted) return;
                  if (ok) {
                    c.audio.sfx(Sfx.complete);
                    showSnack(context, '+${RewardCalculator.rewardedAdHints} hints!');
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 40, decoration: TextDecoration.none)),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Solve the Daily Mystery for bonus coins and a growing streak!', style: kid(14)),
              ),
              PillButton(
                label: 'Go',
                compact: true,
                color: const Color(0xFF33C481),
                onTap: () => openDaily(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- family store ---------------------------------------------------------------------

  Widget _family(GameController c) {
    final products = c.services.iap.products;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: [
        Text(
          'For grown-ups: purchases are optional and never needed to play. A grown-up check appears before any purchase.',
          style: kid(13, color: Colors.white),
        ),
        const SizedBox(height: 12),
        for (final p in products)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _panel(
              child: Row(
                children: [
                  Text(p.emoji, style: const TextStyle(fontSize: 38, decoration: TextDecoration.none)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, style: kid(17, weight: FontWeight.w900)),
                        Text(p.description, style: kid(12, color: const Color(0xFF6E6690))),
                      ],
                    ),
                  ),
                  PillButton(
                    label: p.available ? p.priceLabel : 'Soon',
                    compact: true,
                    color: p.available ? const Color(0xFF5B8DEF) : const Color(0xFFB9B3CC),
                    onTap: !p.available || (p.id == 'remove_ads' && c.data.adsRemoved)
                        ? null
                        : () async {
                            final gate = await showParentalGate(context);
                            if (!gate || !mounted) return;
                            final msg = await c.buyProduct(p.id);
                            if (!mounted) return;
                            if (msg != null) showSnack(context, msg);
                          },
                  ),
                ],
              ),
            ),
          ),
        Center(
          child: TextButton(
            onPressed: () async {
              final gate = await showParentalGate(context);
              if (!gate || !mounted) return;
              await c.restorePurchases();
              if (!mounted) return;
              showSnack(context, 'Purchases restored.');
            },
            child: Text('Restore purchases', style: kid(14, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _panel({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: alpha(Colors.white, 0.94),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: alpha(Colors.black, 0.12), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: child,
      );
}
