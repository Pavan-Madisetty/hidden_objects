import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../services/iap_service.dart';
import 'bouncy.dart';

Future<T?> showKidDialog<T>(
  BuildContext context, {
  String? emoji,
  String? title,
  required Widget body,
  List<Widget> actions = const [],
  bool dismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: alpha(const Color(0xFF1B1140), 0.55),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: alpha(Colors.black, 0.3), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) Text(emoji, style: const TextStyle(fontSize: 52, decoration: TextDecoration.none)),
              if (title != null) ...[
                const SizedBox(height: 6),
                Text(title, textAlign: TextAlign.center, style: kid(24, weight: FontWeight.w900)),
              ],
              const SizedBox(height: 10),
              DefaultTextStyle(
                style: kid(16, weight: FontWeight.w600),
                textAlign: TextAlign.center,
                child: body,
              ),
              if (actions.isNotEmpty) const SizedBox(height: 18),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                actions[i],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String yes = 'Yes',
  String no = 'No',
  String emoji = '🤔',
}) async {
  final r = await showKidDialog<bool>(
    context,
    emoji: emoji,
    title: title,
    body: Text(message),
    actions: [
      Builder(
        builder: (ctx) => PillButton(
          label: yes,
          color: const Color(0xFF33C481),
          width: double.infinity,
          onTap: () => Navigator.of(ctx).pop(true),
        ),
      ),
      Builder(
        builder: (ctx) => PillButton(
          label: no,
          color: const Color(0xFFB0A8C9),
          compact: true,
          width: double.infinity,
          onTap: () => Navigator.of(ctx).pop(false),
        ),
      ),
    ],
  );
  return r ?? false;
}

Future<void> infoDialog(BuildContext context, {required String title, required String message, String emoji = '✨', String ok = 'OK'}) {
  return showKidDialog<void>(
    context,
    emoji: emoji,
    title: title,
    body: Text(message),
    actions: [
      Builder(
        builder: (ctx) => PillButton(
          label: ok,
          width: double.infinity,
          onTap: () => Navigator.of(ctx).pop(),
        ),
      ),
    ],
  );
}

void showSnack(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: kid(16, color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF3A2E5C),
      duration: const Duration(milliseconds: 1800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    ),
  );
}

/// "Ask a grown-up" gate shown before real-money purchases.
Future<bool> showParentalGate(BuildContext context) async {
  final r = Random();
  final a = 6 + r.nextInt(4);
  final b = 5 + r.nextInt(5);
  final answer = a + b;
  final options = <int>{answer};
  while (options.length < 3) {
    final o = answer + r.nextInt(7) - 3;
    if (o > 0) options.add(o);
  }
  final shuffled = options.toList()..shuffle(r);
  final ok = await showKidDialog<bool>(
    context,
    emoji: '👨‍👩‍👧',
    title: 'Ask a grown-up',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('This needs a grown-up. Please solve:'),
        const SizedBox(height: 8),
        Text('$a + $b = ?', style: kid(32)),
      ],
    ),
    actions: [
      for (final o in shuffled)
        Builder(
          builder: (ctx) => PillButton(
            label: '$o',
            width: double.infinity,
            color: const Color(0xFF6C8CFF),
            onTap: () => Navigator.of(ctx).pop(o == answer),
          ),
        ),
      Builder(
        builder: (ctx) => PillButton(
          label: 'Cancel',
          compact: true,
          width: double.infinity,
          color: const Color(0xFFB0A8C9),
          onTap: () => Navigator.of(ctx).pop(false),
        ),
      ),
    ],
  );
  return ok ?? false;
}

/// Friendly stand-in for a real ad SDK (see MockAdsService).
Future<bool> showMockAd(BuildContext context, String kind, String placement) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: alpha(const Color(0xFF1B1140), 0.7),
    builder: (ctx) => _MockAd(kind: kind, placement: placement),
  );
  return r ?? false;
}

class _MockAd extends StatefulWidget {
  const _MockAd({required this.kind, required this.placement});
  final String kind;
  final String placement;

  @override
  State<_MockAd> createState() => _MockAdState();
}

class _MockAdState extends State<_MockAd> {
  int _left = 3;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left = max(0, _left - 1));
      if (_left == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rewarded = widget.kind == 'rewarded';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ad (demo)', style: kid(13, color: const Color(0xFF8A82A6))),
            const SizedBox(height: 8),
            const Text('🎬', style: TextStyle(fontSize: 60, decoration: TextDecoration.none)),
            const SizedBox(height: 6),
            Text(
              rewarded ? 'A short video plays here' : 'A short break',
              style: kid(20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'A real ad provider replaces this screen.\nNo purchase needed to keep playing!',
              style: kid(14, weight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            PillButton(
              label: _left > 0 ? 'Please wait $_left...' : (rewarded ? 'Claim reward' : 'Continue'),
              width: double.infinity,
              color: const Color(0xFF33C481),
              onTap: _left > 0 ? null : () => Navigator.of(context).pop(true),
            ),
            if (rewarded) ...[
              const SizedBox(height: 10),
              PillButton(
                label: 'No thanks',
                compact: true,
                width: double.infinity,
                color: const Color(0xFFB0A8C9),
                onTap: () => Navigator.of(context).pop(false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stand-in for the store's purchase sheet.
Future<bool> showMockPurchase(BuildContext context, StoreProduct p) async {
  final gate = await showParentalGate(context);
  if (!gate || !context.mounted) return false;
  final ok = await showKidDialog<bool>(
    context,
    emoji: p.emoji,
    title: p.title,
    body: Text('${p.description}\n\n${p.priceLabel}  (demo - nothing is charged)'),
    actions: [
      Builder(
        builder: (ctx) => PillButton(
          label: 'Buy',
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
  return ok ?? false;
}
