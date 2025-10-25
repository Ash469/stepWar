// lib/widget/home/battle_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stepwars_app/models/user_model.dart';
import 'package:stepwars_app/screens/battle_screen.dart';
import 'package:stepwars_app/screens/matchmaking_screen.dart';
import 'package:stepwars_app/screens/waiting_for_friend_screen.dart';
import 'package:stepwars_app/services/active_battle_service.dart';
import 'package:stepwars_app/models/battle_RB.dart';
import 'section_title.dart';

class BattleSection extends StatelessWidget {
  final UserModel user;
  final UserModel? opponentProfile;
  final bool isCreatingGame;
  final bool isCreatingBotGame;
  final VoidCallback onShowFriendBattleDialog;
  final Function(ActiveBattleService) onFetchOpponentProfile;

  const BattleSection({
    super.key,
    required this.user,
    this.opponentProfile,
    required this.isCreatingGame,
    required this.isCreatingBotGame,
    required this.onShowFriendBattleDialog,
    required this.onFetchOpponentProfile,
  });

  @override
  Widget build(BuildContext context) {
    final battleService = context.watch<ActiveBattleService>();

    if (battleService.isBattleActive) {
      if (battleService.isWaitingForFriend) {
        return _buildWaitingForFriendCard(context, battleService);
      }
      if (battleService.currentGame != null && opponentProfile == null) {
        onFetchOpponentProfile(battleService);
      }
      if (battleService.currentGame == null || opponentProfile == null) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Center(child: CircularProgressIndicator(color: Colors.yellow)),
        );
      }
      return _buildOngoingBattleCard(context, battleService);
    } else {
      return Column(
        children: [
          const SizedBox(height: 24),
          const SectionTitle(title: "---------- Start A Battle ----------"),
          const SizedBox(height: 16),
          _buildBattleOptions(context),
        ],
      );
    }
  }

  Widget _buildBattleOptions(BuildContext context) {
    return Row(
      children: [
        _buildBattleOption(
          'Online Battle',
          'assets/images/battle_online.png',
          onTap: isCreatingGame
              ? null
              : () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MatchmakingScreen(user: user)));
                },
          isLoading: isCreatingBotGame,
        ),
        const SizedBox(width: 16),
        _buildBattleOption(
          'Battle a Friend',
          'assets/images/battle_friend.png',
          onTap: onShowFriendBattleDialog,
        ),
      ],
    );
  }

  Widget _buildBattleOption(String title, String imagePath,
      {VoidCallback? onTap, bool isLoading = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: Column(
            children: [
              Image.asset(imagePath, height: 80),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDD85D)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(title,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildWaitingForFriendCard(BuildContext context, ActiveBattleService battleService) {
    final gameId = battleService.currentGame?.gameId ?? '...';
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Card(
        color: const Color(0xFF2a2a2a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text("Waiting for Friend",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.yellow),
                  SizedBox(width: 16),
                  Text("Share the Game ID with your friend",
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                gameId,
                style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2),
              ),
              const Divider(color: Colors.white24, height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      battleService.cancelFriendBattle();
                    },
                    child: const Text("Cancel Battle",
                        style:
                            TextStyle(color: Colors.redAccent, fontSize: 16)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => WaitingForFriendScreen(
                              gameId: gameId, user: user)));
                    },
                    child: const Text("Return to Lobby"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOngoingBattleCard(BuildContext context, ActiveBattleService battleService) {
    final game = battleService.currentGame!;
    final timeLeft = battleService.timeLeft;
    final isUserPlayer1 = game.player1Id == user.userId;
    final player1 = isUserPlayer1 ? user : opponentProfile!;
    final player2 = isUserPlayer1 ? opponentProfile! : user;
    final p1Steps = game.step1Count;
    final p2Steps = game.step2Count;
    final p1Score = game.player1Score;
    final p2Score = game.player2Score;
    final scoreDiff = p1Score - p2Score;
    final userIsAhead = isUserPlayer1 ? scoreDiff > 0 : scoreDiff < 0;
    final aheadByText = userIsAhead
        ? "Ahead by ${scoreDiff.abs()}"
        : "Behind by ${scoreDiff.abs()}";

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Card(
        color: const Color(0xFF2a2a2a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text("Ongoing Battle",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${timeLeft.inMinutes.toString().padLeft(2, '0')}:${(timeLeft.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                      const Text("Time left",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  Text(
                    aheadByText,
                    style: TextStyle(
                        color:
                            userIsAhead ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPlayerAvatar(player1, p1Steps, game.multiplier1),
                  const Text("VS",
                      style: TextStyle(color: Colors.white54, fontSize: 20)),
                  _buildPlayerAvatar(player2, p2Steps, game.multiplier2),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BattleScreen()));
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("View full details",
                        style: TextStyle(color: Colors.yellow, fontSize: 16)),
                    Icon(Icons.chevron_right, color: Colors.yellow),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar(UserModel player, int steps, double multiplier) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey.shade800,
              child: player.profileImageUrl == null
                  ? const Icon(Icons.person, size: 25)
                  : ClipOval(
                      child: player.profileImageUrl!.startsWith('assets/')
                          ? Image.asset(
                              player.profileImageUrl!,
                              fit: BoxFit.contain,
                              width: 80,
                              height: 80,
                            )
                          : Image.network(
                              player.profileImageUrl!,
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person, size: 25),
                            ),
                    ),
            ),
            if (multiplier > 1.0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFC107),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black, width: 1)),
                  child: Text('${multiplier}x',
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(steps.toString(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const Text("Total steps",
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(player.username ?? 'Player',
            style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}