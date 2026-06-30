import 'card.dart';
import 'suit.dart';

class PlayedCard {
  final int playerIndex;
  final Card card;
  const PlayedCard(this.playerIndex, this.card);
}

class TrickState {
  final int leadPlayerIndex;
  final Suit? leadSuit;
  final Suit? trumpSuit; // null = no-trump game
  final List<PlayedCard> playedCards;
  final int? winnerIndex;
  final bool isComplete;

  const TrickState({
    required this.leadPlayerIndex,
    this.leadSuit,
    this.trumpSuit,
    this.playedCards = const [],
    this.winnerIndex,
    this.isComplete = false,
  });

  int get nextPlayerIndex {
    if (playedCards.isEmpty) return leadPlayerIndex;
    return (playedCards.last.playerIndex + 1) % 4;
  }

  bool hasPlayed(int playerIndex) =>
      playedCards.any((p) => p.playerIndex == playerIndex);

  TrickState copyWith({
    Suit? leadSuit,
    List<PlayedCard>? playedCards,
    int? winnerIndex,
    bool? isComplete,
  }) {
    return TrickState(
      leadPlayerIndex: leadPlayerIndex,
      leadSuit: leadSuit ?? this.leadSuit,
      trumpSuit: trumpSuit,
      playedCards: playedCards ?? this.playedCards,
      winnerIndex: winnerIndex ?? this.winnerIndex,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}
