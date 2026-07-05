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
  ///
  /// [hand] is validated against the Koz rule. These checks are real
  /// exceptions (not `assert`) because this is also the entry point for
  /// bids relayed from remote clients over the multiplayer connection,
  /// where `assert` would be silently stripped in release builds.
  BidState applyBid(
    BidState state,
    List<int> order,
    int playerIndex,
    int bidValue,
    Suit? trumpSuit,
    List<Card> hand,
  ) {
    if (bidValue < 7 || bidValue > 13) {
      throw ArgumentError('Bid value must be between 7 and 13, got $bidValue');
    }
    if (order[state.turnIndex] != playerIndex) {
      throw StateError('Not player $playerIndex\'s turn to bid');
    }
    if (state.bidValue != null && bidValue <= state.bidValue!) {
      throw ArgumentError(
          'Bid must be higher than the current standing bid (${state.bidValue})');
    }
    if (!isKozRuleValid(hand, bidValue, trumpSuit)) {
      throw ArgumentError(
          'Koz rule violated: too many trump cards for bid $bidValue');
    }

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
  /// [order] is the biddingOrder list for this round. If nobody ever bid,
  /// the last player passing triggers a redeal. If a standing bid exists,
  /// the last player may not simply pass on it — they must call
  /// [applyAccept] instead, since accepting requires naming their own trump.
  BidState applyPass(BidState state, List<int> order, int playerIndex) {
    if (order[state.turnIndex] != playerIndex) {
      throw StateError('Not player $playerIndex\'s turn to pass');
    }

    final isLastTurn = state.turnIndex == order.length - 1;
    if (isLastTurn && state.bidValue != null) {
      throw StateError(
          'Last player must call applyAccept (with a trump choice) instead of passing on a standing bid');
    }

    final newPassed = List<bool>.from(state.passed);
    newPassed[state.turnIndex] = true;

    if (isLastTurn) {
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

  /// Returns the updated BidState after the last player in [order] accepts
  /// the standing bid at its current value, becoming the new bidder and
  /// naming their own [trumpSuit] (null = no-trump) before play starts.
  /// Only valid on the last player's turn when a standing bid exists.
  BidState applyAccept(
    BidState state,
    List<int> order,
    int playerIndex,
    Suit? trumpSuit,
    List<Card> hand,
  ) {
    if (order[state.turnIndex] != playerIndex) {
      throw StateError('Not player $playerIndex\'s turn to bid');
    }
    if (state.turnIndex != order.length - 1) {
      throw StateError('Only the last player in the bidding order may accept');
    }
    if (state.bidValue == null) {
      throw StateError('There is no standing bid to accept');
    }
    if (!isKozRuleValid(hand, state.bidValue!, trumpSuit)) {
      throw ArgumentError(
          'Koz rule violated: too many trump cards for bid ${state.bidValue}');
    }

    final newPassed = List<bool>.from(state.passed);
    newPassed[state.turnIndex] = true;
    return state.copyWith(
      passed: newPassed,
      trumpSuit: () => trumpSuit,
      biddingPlayerIndex: playerIndex,
      biddingTeam: teamOf(playerIndex),
      leadPlayerIndex: playerIndex,
      isComplete: true,
    );
  }

  /// Which player's turn it is to bid.
  int currentBidder(BidState state, List<int> order) => order[state.turnIndex];

  bool isBiddingComplete(BidState state) => state.isComplete;
}
