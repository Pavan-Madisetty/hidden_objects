import 'dart:ui';

enum ShopCategory { character, hat, theme }

class ShopItem {
  const ShopItem({
    required this.id,
    required this.category,
    required this.name,
    required this.emoji,
    required this.price,
    this.unlockLevel = 1,
    this.special = false,
  });

  final String id;
  final ShopCategory category;
  final String name;

  /// Character face / hat emoji (empty for "no hat" and themes use palette).
  final String emoji;
  final int price;

  /// Explorer level needed before it can be bought.
  final int unlockLevel;

  /// Earned through special rewards only (not buyable).
  final bool special;
}

class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.bgTop,
    required this.bgBottom,
    required this.primary,
    required this.secondary,
    required this.ink,
  });

  final String id;
  final String name;
  final Color bgTop;
  final Color bgBottom;
  final Color primary;
  final Color secondary;
  final Color ink;
}

class ShopCatalog {
  static const List<ShopItem> items = [
    // Characters
    ShopItem(id: 'char_kit', category: ShopCategory.character, name: 'Kit', emoji: '🐱', price: 0),
    ShopItem(id: 'char_fox', category: ShopCategory.character, name: 'Foxy', emoji: '🦊', price: 200, unlockLevel: 2),
    ShopItem(id: 'char_bunny', category: ShopCategory.character, name: 'Hoppy', emoji: '🐰', price: 250, unlockLevel: 3),
    ShopItem(id: 'char_panda', category: ShopCategory.character, name: 'Bamboo', emoji: '🐼', price: 300, unlockLevel: 4),
    ShopItem(id: 'char_owl', category: ShopCategory.character, name: 'Hoot', emoji: '🦉', price: 350, unlockLevel: 5),
    ShopItem(id: 'char_robot', category: ShopCategory.character, name: 'Beep', emoji: '🤖', price: 450, unlockLevel: 6),
    ShopItem(id: 'char_unicorn', category: ShopCategory.character, name: 'Sparkle', emoji: '🦄', price: 600, unlockLevel: 8),
    // Hats
    ShopItem(id: 'hat_none', category: ShopCategory.hat, name: 'No hat', emoji: '', price: 0),
    ShopItem(id: 'hat_cap', category: ShopCategory.hat, name: 'Cap', emoji: '🧢', price: 100),
    ShopItem(id: 'hat_bow', category: ShopCategory.hat, name: 'Bow', emoji: '🎀', price: 100, unlockLevel: 2),
    ShopItem(id: 'hat_sun', category: ShopCategory.hat, name: 'Sun hat', emoji: '👒', price: 150, unlockLevel: 2),
    ShopItem(id: 'hat_top', category: ShopCategory.hat, name: 'Top hat', emoji: '🎩', price: 200, unlockLevel: 3),
    ShopItem(id: 'hat_grad', category: ShopCategory.hat, name: 'Scholar', emoji: '🎓', price: 250, unlockLevel: 4),
    ShopItem(id: 'hat_crown', category: ShopCategory.hat, name: 'Crown', emoji: '👑', price: 500, unlockLevel: 6),
    ShopItem(id: 'hat_golden', category: ShopCategory.hat, name: 'Golden Star', emoji: '🌟', price: 0, special: true),
    // Themes
    ShopItem(id: 'theme_sunny', category: ShopCategory.theme, name: 'Sunny Day', emoji: '☀️', price: 0),
    ShopItem(id: 'theme_ocean', category: ShopCategory.theme, name: 'Ocean', emoji: '🌊', price: 200, unlockLevel: 2),
    ShopItem(id: 'theme_candy', category: ShopCategory.theme, name: 'Candy', emoji: '🍭', price: 250, unlockLevel: 3),
    ShopItem(id: 'theme_forest', category: ShopCategory.theme, name: 'Forest', emoji: '🌲', price: 250, unlockLevel: 4),
    ShopItem(id: 'theme_galaxy', category: ShopCategory.theme, name: 'Galaxy', emoji: '🪐', price: 400, unlockLevel: 6),
  ];

  static const List<AppPalette> palettes = [
    AppPalette(
      id: 'theme_sunny',
      name: 'Sunny Day',
      bgTop: Color(0xFF7FD6FF),
      bgBottom: Color(0xFFFFF1B8),
      primary: Color(0xFFFF8A3D),
      secondary: Color(0xFF33C481),
      ink: Color(0xFF3A2E5C),
    ),
    AppPalette(
      id: 'theme_ocean',
      name: 'Ocean',
      bgTop: Color(0xFF4FC3F7),
      bgBottom: Color(0xFFB2F0E8),
      primary: Color(0xFF1E88E5),
      secondary: Color(0xFF26C6A6),
      ink: Color(0xFF12396B),
    ),
    AppPalette(
      id: 'theme_candy',
      name: 'Candy',
      bgTop: Color(0xFFFFB3D9),
      bgBottom: Color(0xFFFFE9A8),
      primary: Color(0xFFFF5FA2),
      secondary: Color(0xFFA36BFF),
      ink: Color(0xFF5B2A66),
    ),
    AppPalette(
      id: 'theme_forest',
      name: 'Forest',
      bgTop: Color(0xFF9BE39B),
      bgBottom: Color(0xFFE8F7B8),
      primary: Color(0xFF2FA85A),
      secondary: Color(0xFFF2A93B),
      ink: Color(0xFF1F4D2E),
    ),
    AppPalette(
      id: 'theme_galaxy',
      name: 'Galaxy',
      bgTop: Color(0xFF7F5AF0),
      bgBottom: Color(0xFFE39BFF),
      primary: Color(0xFFFF6FB5),
      secondary: Color(0xFF5DE0E6),
      ink: Color(0xFF2B1B5C),
    ),
  ];

  static ShopItem? byId(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  static List<ShopItem> inCategory(ShopCategory c) => [for (final i in items) if (i.category == c) i];

  static AppPalette palette(String id) =>
      palettes.firstWhere((p) => p.id == id, orElse: () => palettes.first);

  static String characterEmoji(String id) => byId(id)?.emoji ?? '🐱';
  static String hatEmoji(String id) => byId(id)?.emoji ?? '';
}

/// Optional bonus rooms unlocked by Explorer level.
class BonusRoomDef {
  const BonusRoomDef(this.levelId, this.name, this.emoji, this.worldId, this.unlockLevel);
  final int levelId;
  final String name;
  final String emoji;
  final String worldId;
  final int unlockLevel;

  static const List<BonusRoomDef> all = [
    BonusRoomDef(9001, 'Secret Attic', '🕸️', 'bedroom', 2),
    BonusRoomDef(9002, 'Treasure Cave', '💎', 'pirate', 4),
    BonusRoomDef(9003, 'Star Garden', '🌸', 'forest', 6),
  ];
}
