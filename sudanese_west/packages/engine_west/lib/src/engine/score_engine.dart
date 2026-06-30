import '../models/round_result.dart';
import '../models/suit.dart';
import '../models/team.dart';

class ScoreEngine {
  /// Calculates the score delta for both teams after a completed round.
  ///
  /// Scoring rules:
  /// - Bidding team succeeds (tricksWon >= bid): +tricksWon
  /// - Bidding team fails  (tricksWon < bid):   -bidValue
  /// - Opposing team when bid succeeds:          0
  /// - Opposing team when bid fails:             +their tricks won
  /// - Kabout (one team wins all 13):            special win condition
  RoundResult calculateResult({
    required Team biddingTeam,
    required int bidValue,
    required Map<Team, int> tricksWon,
    Suit? trumpSuit,
  }) {
    final biddingTricks = tricksWon[biddingTeam]!;
    final opposingTeam_ = opposingTeam(biddingTeam);
    final opposingTricks = tricksWon[opposingTeam_]!;

    final kabout =
        biddingTricks == 13 || opposingTricks == 13;

    final succeeded = biddingTricks >= bidValue;

    final Map<Team, int> scoreChange;
    if (succeeded) {
      scoreChange = {
        biddingTeam: biddingTricks,
        opposingTeam_: 0,
      };
    } else {
      scoreChange = {
        biddingTeam: -bidValue,
        opposingTeam_: opposingTricks,
      };
    }

    return RoundResult(
      biddingTeam: biddingTeam,
      bidValue: bidValue,
      tricksWon: tricksWon,
      scoreChange: scoreChange,
      wasKabout: kabout,
    );
  }

  /// Produces a redeal result with zero score change.
  RoundResult redealResult() => RoundResult(
        biddingTeam: null,
        bidValue: null,
        tricksWon: {Team.northSouth: 0, Team.eastWest: 0},
        scoreChange: {Team.northSouth: 0, Team.eastWest: 0},
        wasRedeal: true,
      );
}
