import '../models/bid_state.dart';
import '../models/suit.dart';
import '../models/team.dart';

class BidEngine {
  /// Returns the updated BidState after a player bids.
  /// [order] is the biddingOrder list for this round.
  BidState applyBid(
    BidState state,
    List<int> order,
    int playerIndex,
    int bidValue,
    Suit? trumpSuit,
  ) {
    assert(bidValue >= 7 && bidValue <= 13);
    assert(order[state.turnIndex] == playerIndex,
        'Not this player\'s turn to bid');

    return state.copyWith(
      bidValue: bidValue,
      trumpSuit: () => trumpSuit,
      biddingPlayerIndex: playerIndex,
      biddingTeam: teamOf(playerIndex),
      leadPlayerIndex: playerIndex,
      isComplete: true,
    );
  }

  /// Returns the updated BidState after a player passes.
  /// [order] is the biddingOrder list for this round.
  BidState applyPass(BidState state, List<int> order, int playerIndex) {
    assert(order[state.turnIndex] == playerIndex,
        'Not this player\'s turn to pass');

    final newPassed = List<bool>.from(state.passed);
    newPassed[state.turnIndex] = true;
    final nextTurn = state.turnIndex + 1;

    if (nextTurn >= 4) {
      // All 4 players passed → redeal
      return state.copyWith(
        passed: newPassed,
        turnIndex: nextTurn,
        needsRedeal: true,
        isComplete: true,
      );
    }

    return state.copyWith(
      passed: newPassed,
      turnIndex: nextTurn,
    );
  }

  /// Which player's turn it is to bid.
  int currentBidder(BidState state, List<int> order) => order[state.turnIndex];

  bool isBiddingComplete(BidState state) => state.isComplete;
}
