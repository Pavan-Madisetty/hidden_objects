import 'package:flutter/widgets.dart';

import 'game_controller.dart';

/// Gives every widget access to the [GameController].
class AppScope extends InheritedNotifier<GameController> {
  const AppScope({super.key, required GameController controller, required super.child})
      : super(notifier: controller);

  /// Listens for changes (rebuilds when the controller notifies).
  static GameController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }

  /// Reads without subscribing.
  static GameController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }
}
