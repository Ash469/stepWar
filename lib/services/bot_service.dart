import 'dart:math';
enum BotType { pawn, bishop, rook, knight, queen }
class BotService {
  final Random _random = Random();
  final List<BotType> _botOrder = [
    BotType.pawn,
    BotType.bishop,
    BotType.rook,
    BotType.knight,
    BotType.queen,
  ];

  BotType getNextBot(int userWins) {
    return _botOrder[
    userWins.clamp(0, _botOrder.length - 1)
    ];
  }

  int generateStepsForOneSecond(BotType botType) {
    final double rand = _random.nextDouble();

    switch (botType) {
      case BotType.pawn:
        if (rand < 0.7) return 1;
        if (rand < 0.9) return 0;
        return 2;

      case BotType.bishop:
        if (rand < 0.6) return 1;
        if (rand < 0.9) return 2;
        return 0;

      case BotType.rook:
        if (rand < 0.3) return 1;
        if (rand < 0.9) return 2;
        return 0;

      case BotType.knight:
        if (rand < 0.4) return 1;
        if (rand < 0.8) return 2;
        return 3;

      case BotType.queen:
        if (rand < 0.25) return 2;
        if (rand < 0.7) return 3;
        return 4;
    }
  }

  // int generateStepsForOneSecond(BotType botType) {
  //   final double rand = _random.nextDouble();
  //   switch (botType) {
  //     case BotType.pawn:
  //       // Avg Pace ~0.9/sec -> 70%: 1 step, 20%: 0 steps, 10%: 2 steps
  //       if (rand < 0.7) {
  //         return 1;
  //       } else if (rand < 0.9) {
  //         return 0;
  //       } else {
  //         return 2;
  //       }
  //     case BotType.bishop:
  //       // Avg Pace ~1.2/sec -> 60%: 1 step, 30%: 2 steps, 10%: 0 steps
  //       if (rand < 0.6) {
  //         return 1;
  //       } else if (rand < 0.9) {
  //         return 2;
  //       } else {
  //         return 0;
  //       }
  //     case BotType.rook:
  //       // Avg Pace ~1.5/sec -> 30%: 1 step, 60%: 2 steps, 10%: 0 steps
  //       if (rand < 0.3) {
  //         return 1;
  //       } else if (rand < 0.9) {
  //         return 2;
  //       } else {
  //         return 0;
  //       }
  //     case BotType.knight:
  //       // Avg Pace ~1.8/sec -> 40%: 1 step, 40%: 2 steps, 20%: 3 steps
  //       if (rand < 0.4) {
  //         return 1;
  //       } else if (rand < 0.8) {
  //         return 2;
  //       } else {
  //         return 3;
  //       }
  //   }
  // }
  String getBotId(BotType botType) {
    return 'bot_${botType.name}';
  }

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
      case BotType.queen:
        return 'assets/images/queen.png';
    }
  }

  String getBotDisplayName(BotType botType) {
    switch (botType) {
      case BotType.pawn:
        return 'The Drifter';
      case BotType.bishop:
        return 'The Consistent Walker';
      case BotType.rook:
        return 'The Grinder';
      case BotType.knight:
        return 'The Sprinter';
      case BotType.queen:
        return 'The Phantom';
    }
  }

  int getBotLevel(BotType botType) {
    return botType.index + 1;
  }

  int getEntryFee(BotType botType) {
    return 500;
  }
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
      case 'bot_queen':
        return BotType.queen;
      default:
        return null;
    }
  }

  String getBotNameFromId(String botId) {
    switch (botId) {
      case 'bot_pawn':
        return 'Pawn';
      case 'bot_bishop':
        return 'Bishop';
      case 'bot_rook':
        return 'Rook';
      case 'bot_knight':
        return 'Knight';
      case 'bot_queen':
        return 'Queen';
      default:
        return 'Unknown';
    }
  }
  String getBotDescription(BotType botType) {
    switch (botType) {
      case BotType.pawn:
        return "Feels like someone casually strolling, distracted, never in a hurry.";
      case BotType.bishop:
        return "Feels like a disciplined daily walker who values consistency over speed.";
      case BotType.rook:
        return "Feels like someone power-walking with focus, step after step, no excuses.";
      case BotType.knight:
        return "Feels like someone alternating between walking and short jogs just to test their limits.";
      case BotType.queen:
        return "Feels like an elite walker who’s already in motion while others are still warming up.";
      default:
        return "A mysterious challenger awaits your next move.";
    }
  }
  int getBotReward(BotType botType) {
    switch (botType) {
      case BotType.pawn:
        return 1000;
      case BotType.bishop:
        return 1500;
      case BotType.rook:
        return 2000;
      case BotType.knight:
        return 2500;
      case BotType.queen:
        return 3000;
    }
  }

}