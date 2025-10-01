import 'dart:math';

enum BotType { pawn, bishop, rook, knight }

class BotService {
  final Random _random = Random();

  /// Selects a random bot from the available types.
  BotType selectRandomBot() {
    final types = BotType.values;
    return types[_random.nextInt(types.length)];
  }

  /// Generates steps for a single tick (1 second) based on the bot's unique probability distribution.
  int generateStepsForOneSecond(BotType botType) {
    final double rand = _random.nextDouble(); // A value between 0.0 and 1.0

    switch (botType) {
      case BotType.pawn:
        // Avg Pace ~0.9/sec -> 70%: 1 step, 20%: 0 steps, 10%: 2 steps
        if (rand < 0.7) {
          return 1;
        } else if (rand < 0.9) { // 0.7 + 0.2
          return 0;
        } else {
          return 2;
        }
      case BotType.bishop:
        // Avg Pace ~1.2/sec -> 60%: 1 step, 30%: 2 steps, 10%: 0 steps
        if (rand < 0.6) {
          return 1;
        } else if (rand < 0.9) { // 0.6 + 0.3
          return 2;
        } else {
          return 0;
        }
      case BotType.rook:
        // Avg Pace ~1.5/sec -> 30%: 1 step, 60%: 2 steps, 10%: 0 steps
        if (rand < 0.3) {
          return 1;
        } else if (rand < 0.9) { // 0.3 + 0.6
          return 2;
        } else {
          return 0;
        }
      case BotType.knight:
        // Avg Pace ~1.8/sec -> 40%: 1 step, 40%: 2 steps, 20%: 3 steps
        if (rand < 0.4) {
          return 1;
        } else if (rand < 0.8) { // 0.4 + 0.4
          return 2;
        } else {
          return 3;
        }
    }
  }

  /// Gets the string identifier for a given bot type.
  String getBotId(BotType botType) {
    switch (botType) {
      case BotType.pawn:
        return 'bot_pawn';
      case BotType.bishop:
        return 'bot_bishop';
      case BotType.rook:
        return 'bot_rook';
      case BotType.knight:
        return 'bot_knight';
    }
  }
  
  /// Gets the image asset path for a given bot type.
  String getBotImagePath(BotType botType) {
    switch (botType) {
      case BotType.pawn:
        return 'assets/images/pawn.png';
      case BotType.bishop:
        return 'assets/images/bishop.png';
      case BotType.rook:
        return 'assets/images/rook.png';
      case BotType.knight:
        return 'assets/images/knight.png';
    }
  }


  /// Gets the bot type from a string identifier.
  BotType? getBotTypeFromId(String botId) {
    switch (botId) {
      case 'bot_pawn':
        return BotType.pawn;
      case 'bot_bishop':
        return BotType.bishop;
      case 'bot_rook':
        return BotType.rook;
      case 'bot_knight':
        return BotType.knight;
      default:
        return null;
    }
  }

  /// Gets the display name for a given bot ID.
  String getBotNameFromId(String botId) {
    switch (botId) {
      case 'bot_pawn':
        return 'Pawn Bot';
      case 'bot_bishop':
        return 'Bishop Bot';
      case 'bot_rook':
        return 'Rook Bot';
      case 'bot_knight':
        return 'Knight Bot';
      default:
        return 'Unknown Bot';
    }
  }
}