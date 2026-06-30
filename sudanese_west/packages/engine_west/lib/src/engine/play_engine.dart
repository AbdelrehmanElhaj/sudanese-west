import '../models/card.dart';
import '../models/suit.dart';
import '../models/team.dart';
import '../models/trick_state.dart';

class PlayEngine {
  /// Returns the legal cards a player may play given the current trick state.
  ///
  /// Rules:
  /// - First card of a trick: if it's trick #1 and trump exists, must play trump.
  /// - Otherwise: must follow lead suit if possible; any card otherwise.
  List<Card> legalCards({
    required List<Card> hand,
    required TrickState trick,
    required int trickNumber,
    required bool isLeader,
  }) {
    if (isLeader) {
      // First trick: leader must play a trump card (if trump game).
      if (trickNumber == 1 && trick.trumpSuit != null) {
        final trumpCards =
            hand.where((c) => c.suit == trick.trumpSuit).toList();
        // If hand has no trump (shouldn't happen in normal play, but guard anyway)
        return trumpCards.isNotEmpty ? trumpCards : hand;
      }
      return hand;
    }

    // Must follow lead suit if possible.
    if (trick.leadSuit != null) {
      final followSuit =
          hand.where((c) => c.suit == trick.leadSuit).toList();
      if (followSuit.isNotEmpty) return followSuit;
    }

    return hand;
  }

  /// Applies a card play to the trick. Returns updated TrickState.
  TrickState applyPlay(TrickState trick, int playerIndex, Card card) {
    assert(!trick.isComplete, 'Trick is already complete');
    assert(!trick.hasPlayed(playerIndex), 'Player already played this trick');

    final newPlayed = [...trick.playedCards, PlayedCard(playerIndex, card)];
    final newLeadSuit = trick.leadSuit ?? card.suit;

    if (newPlayed.length < 4) {
      return trick.copyWith(
        leadSuit: newLeadSuit,
        playedCards: newPlayed,
      );
    }

    // All 4 cards played — determine winner.
    final winner = _determineTrickWinner(newPlayed, newLeadSuit, trick.trumpSuit);
    return trick.copyWith(
      leadSuit: newLeadSuit,
      playedCards: newPlayed,
      winnerIndex: winner,
      isComplete: true,
    );
  }

  int _determineTrickWinner(
    List<PlayedCard> played,
    Suit leadSuit,
    Suit? trumpSuit,
  ) {
    PlayedCard? winner;

    for (final pc in played) {
      if (winner == null) {
        winner = pc;
        continue;
      }

      final beats = _beats(pc.card, winner.card, leadSuit, trumpSuit);
      if (beats) winner = pc;
    }

    return winner!.playerIndex;
  }

  bool _beats(Card challenger, Card current, Suit leadSuit, Suit? trumpSuit) {
    // Trump always beats non-trump.
    if (trumpSuit != null) {
      final challengerTrump = challenger.suit == trumpSuit;
      final currentTrump = current.suit == trumpSuit;

      if (challengerTrump && !currentTrump) return true;
      if (!challengerTrump && currentTrump) return false;
      if (challengerTrump && currentTrump) {
        return challenger.rank.value > current.rank.value;
      }
    }

    // Neither is trump (or no-trump game).
    // Only lead-suit cards can win.
    final challengerLead = challenger.suit == leadSuit;
    final currentLead = current.suit == leadSuit;

    if (challengerLead && !currentLead) return true;
    if (!challengerLead && currentLead) return false;
    if (challengerLead && currentLead) {
      return challenger.rank.value > current.rank.value;
    }

    // Neither follows lead suit — no change.
    return false;
  }

  /// Creates the next trick state after a trick completes.
  TrickState nextTrick(int winnerIndex, Suit? trumpSuit) {
    return TrickState(
      leadPlayerIndex: winnerIndex,
      trumpSuit: trumpSuit,
    );
  }

  /// Returns tricks won by each team from the played tricks list.
  Map<Team, int> countTricks(List<int> trickWinners) {
    final counts = {Team.northSouth: 0, Team.eastWest: 0};
    for (final winner in trickWinners) {
      counts[teamOf(winner)] = counts[teamOf(winner)]! + 1;
    }
    return counts;
  }
}
