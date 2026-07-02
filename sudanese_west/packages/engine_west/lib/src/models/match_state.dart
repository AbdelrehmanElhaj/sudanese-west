import 'dart:math';

import 'game_mode.dart';
import 'round_result.dart';
import 'team.dart';

class MatchState {
  final Map<Team, int> scores;
  final List<RoundResult> roundHistory;
  final int targetScore;
  final GameMode gameMode;
  final int currentRoundNumber;
  final int starterIndex; // rotates each round

  const MatchState({
    required this.scores,
    required this.roundHistory,
    required this.targetScore,
    required this.gameMode,
    required this.currentRoundNumber,
    required this.starterIndex,
  });

  /// [starterIndex] picks who bids first in the match's opening round;
  /// left unset, it is chosen at random (0–3). It then rotates by one seat
  /// after every completed round via [applyRoundResult].
  factory MatchState.initial({
    int targetScore = 25,
    GameMode gameMode = GameMode.singlePlayerVsBots,
    int? starterIndex,
  }) =>
      MatchState(
        scores: {Team.northSouth: 0, Team.eastWest: 0},
        roundHistory: const [],
        targetScore: targetScore,
        gameMode: gameMode,
        currentRoundNumber: 1,
        starterIndex: starterIndex ?? Random().nextInt(4),
      );

  bool get isMatchOver {
    for (final score in scores.values) {
      if (score >= targetScore) return true;
    }
    return false;
  }

  Team? get winner {
    Team? w;
    int highScore = -9999;
    scores.forEach((team, score) {
      if (score >= targetScore && score > highScore) {
        highScore = score;
        w = team;
      }
    });
    return w;
  }

  MatchState applyRoundResult(RoundResult result) {
    final newScores = Map<Team, int>.from(scores);
    result.scoreChange.forEach((team, delta) {
      newScores[team] = (newScores[team] ?? 0) + delta;
    });
    return MatchState(
      scores: newScores,
      roundHistory: [...roundHistory, result],
      targetScore: targetScore,
      gameMode: gameMode,
      currentRoundNumber: currentRoundNumber + (result.wasRedeal ? 0 : 1),
      starterIndex: result.wasRedeal ? starterIndex : (starterIndex + 1) % 4,
    );
  }
}
