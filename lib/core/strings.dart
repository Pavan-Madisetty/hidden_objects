/// Short, friendly texts. Kept in one place so they are easy to translate.
class Strings {
  static const String appName = 'Seek & Sparkle';

  /// One-time banners shown the first time a new mechanic appears.
  static const Map<String, String> intros = {
    'tap': 'Some things move when you tap them. Try the clock!',
    'behind': 'Look closely - some things are half hidden behind others!',
    'hidden': 'Tap curtains, plants, lamps and books. They can hide secrets!',
    'zoom': 'Pinch to zoom in and drag to look around. 🔍',
    'open': 'Open drawers, cupboards and boxes - things hide inside!',
    'move': 'Tap heavy things to push them aside and see underneath.',
    'rooms': 'There are two rooms now! Use the room buttons to switch.',
    'secrets': 'Lots of secrets in this world. Open everything!',
    'chain': 'Locked? Find the key first. One clue leads to the next!',
    'timed': 'Beat the clock for bonus coins! Find the golden ✨ object too.',
    'mystery': 'Mystery levels mix everything you learned. You are ready!',
    'daily': 'A special scene, just for today. Find everything before time runs out!',
    'bonusRoom': 'A secret bonus room! Find the golden objects for extra coins.',
  };

  static const List<String> foundCheers = [
    'Great find!',
    'Nice eyes!',
    'You got it!',
    'Sparkly!',
    'Wow!',
    'Awesome!',
  ];

  static const List<String> wrongTips = [
    'Not that one - keep looking!',
    'Almost! Look closer.',
    'Take your time. 🔍',
  ];
}
