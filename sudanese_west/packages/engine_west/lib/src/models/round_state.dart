import 'bid_state.dart';
import 'card.dart';
import 'team.dart';
import 'trick_state.dart';

class RoundState {
  final List<List<Card>> hands; // hands[playerIndex]
  final BidState bidState;
  final int trickNumber; // 1–13
  final TrickState currentTrick;
  final Map<Team, int> tricksWon;

  const RoundState({
    required this.hands,
    required this.bidState,
    required this.trickNumber,
    required this.currentTrick,
    required this.tricksWon,
  });

  bool get isRoundComplete => trickNumber > 13;

  bool get isBiddingPhase => !bidState.isComplete;

  RoundState copyWith({
    List<List<Card>>? hands,
    BidState? bidState,
    int? trickNumber,
    TrickState? currentTrick,
    Map<Team, int>? tricksWon,
  }) {
    return RoundState(
      hands: hands ?? this.hands,
      bidState: bidState ?? this.bidState,
      trickNumber: trickNumber ?? this.trickNumber,
      currentTrick: currentTrick ?? this.currentTrick,
      tricksWon: tricksWon ?? this.tricksWon,
    );
  }
}
