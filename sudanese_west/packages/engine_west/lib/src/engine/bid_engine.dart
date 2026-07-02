import '../models/bid_state.dart';
import '../models/card.dart';
import '../models/suit.dart';
import '../models/team.dart';

class BidEngine {
  /// Koz rule: to name [trumpSuit] with [bidValue], the player must hold
  /// at most (bidValue − 3) cards of that suit. NT bids are always valid.
  static bool isKozRuleValid(
      List<Card> hand, int bidValue, Suit? trumpSuit) {
    if (trumpSuit == null) return true;
    final kozCount = hand.where((c) => c.suit == trumpSuit).length;
    return kozCount <= bidValue - 3;
  }

  /// Returns the updated BidState after a player bids.
  /// [order] is the biddingOrder list for this round. Each of the 4 players
  /// gets one turn; a bid must exceed the current standing bid (if any).
  /// Bidding only completes once the last player in [order] has acted —
  /// earlier bids just raise the standing bid and move to the next player.
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
    assert(state.bidValue == null || bidValue > state.bidValue!,
        'Bid must be higher than the current standing bid');

    final isLastTurn = state.turnIndex == order.length - 1;
    return state.copyWith(
      bidValue: bidValue,
      trumpSuit: () => trumpSuit,
      biddingPlayerIndex: playerIndex,
      biddingTeam: teamOf(playerIndex),
      leadPlayerIndex: playerIndex,
      turnIndex: isLastTurn ? state.turnIndex : state.turnIndex + 1,
      isComplete: isLastTurn,
    );
  }

  /// Returns the updated BidState after a player passes.
  /// [order] is the biddingOrder list for this round. If the last player
  /// passes while a standing bid exists, they've accepted it as-is and
  /// bidding completes with that bid. If nobody ever bid, it's a redeal.
  BidState applyPass(BidState state, List<int> order, int playerIndex) {
    assert(order[state.turnIndex] == playerIndex,
        'Not this player\'s turn to pass');

    final newPassed = List<bool>.from(state.passed);
    newPassed[state.turnIndex] = true;
    final isLastTurn = state.turnIndex == order.length - 1;

    if (isLastTurn) {
      if (state.bidValue != null) {
        // Last player accepts the standing bid as-is.
        return state.copyWith(passed: newPassed, isComplete: true);
      }
      // Nobody ever bid → redeal.
      return state.copyWith(
        passed: newPassed,
        needsRedeal: true,
        isComplete: true,
      );
    }

    return state.copyWith(
      passed: newPassed,
      turnIndex: state.turnIndex + 1,
    );
  }

  /// Which player's turn it is to bid.
  int currentBidder(BidState state, List<int> order) => order[state.turnIndex];

  bool isBiddingComplete(BidState state) => state.isComplete;
}
