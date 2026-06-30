import 'suit.dart';
import 'team.dart';

// Bidding order from a given starter: starter → partner → left opp → right opp.
// e.g. starter=0: [0, 2, 1, 3]
List<int> biddingOrder(int starterIndex) => [
      starterIndex,
      partnerOf(starterIndex),
      (starterIndex + 1) % 4,
      (starterIndex + 3) % 4,
    ];

class BidState {
  /// Which player in [biddingOrder] is next to act (0–3 index into biddingOrder).
  final int turnIndex;

  /// Index into [biddingOrder] of which players have already passed.
  final List<bool> passed;

  /// Set once a bid is placed.
  final int? bidValue;
  final Suit? trumpSuit; // null = no-trump
  final int? biddingPlayerIndex;
  final Team? biddingTeam;

  /// The player who leads the first trick (= biddingPlayerIndex).
  final int? leadPlayerIndex;

  final bool isComplete;
  final bool needsRedeal; // all 4 passed

  const BidState({
    required this.turnIndex,
    required this.passed,
    this.bidValue,
    this.trumpSuit,
    this.biddingPlayerIndex,
    this.biddingTeam,
    this.leadPlayerIndex,
    this.isComplete = false,
    this.needsRedeal = false,
  });

  factory BidState.initial() => const BidState(
        turnIndex: 0,
        passed: [false, false, false, false],
      );

  BidState copyWith({
    int? turnIndex,
    List<bool>? passed,
    int? bidValue,
    Suit? Function()? trumpSuit,
    int? biddingPlayerIndex,
    Team? biddingTeam,
    int? leadPlayerIndex,
    bool? isComplete,
    bool? needsRedeal,
  }) {
    return BidState(
      turnIndex: turnIndex ?? this.turnIndex,
      passed: passed ?? this.passed,
      bidValue: bidValue ?? this.bidValue,
      trumpSuit: trumpSuit != null ? trumpSuit() : this.trumpSuit,
      biddingPlayerIndex: biddingPlayerIndex ?? this.biddingPlayerIndex,
      biddingTeam: biddingTeam ?? this.biddingTeam,
      leadPlayerIndex: leadPlayerIndex ?? this.leadPlayerIndex,
      isComplete: isComplete ?? this.isComplete,
      needsRedeal: needsRedeal ?? this.needsRedeal,
    );
  }
}
