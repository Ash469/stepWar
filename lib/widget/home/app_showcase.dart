import 'package:flutter/material.dart';

class AppShowcase {
  static final GlobalKey stepCountKey = GlobalKey();
  static final GlobalKey onlineBattleKey = GlobalKey();
  static final GlobalKey friendBattleKey = GlobalKey();
  static final GlobalKey kingdomButtonKey = GlobalKey();
  static final GlobalKey profileButtonKey = GlobalKey();
  static final GlobalKey tutorialInfoKey = GlobalKey();

  // Method to start the showcase with a consistent order
  static List<GlobalKey> get tutorialOrder => [
        stepCountKey,
        onlineBattleKey,
        friendBattleKey,
        kingdomButtonKey,
        profileButtonKey,
        tutorialInfoKey,
      ];
}
