import 'dart:math';

import '../models/card.dart';
import '../models/rank.dart';
import '../models/suit.dart';
import '../models/trick_state.dart';

class BotBidAction {
  final int? bidValue; // null = pass
  final Suit? trumpSuit;

  const BotBidAction.bid(int value, Suit? trump)
      : bidValue = value,
        trumpSuit = trump;

  const BotBidAction.pass()
      : bidValue = null,
        trumpSuit = null;

  bool get isPass => bidValue == null;
}

/// Simple heuristic bot — good enough for single-player MVP.
class BotPlayer {
  final Random _rng;

  BotPlayer({Random? rng}) : _rng = rng ?? Random();

  // ─── Bidding ────────────────────────────────────────────────────────────────

  /// Decide bid or pass based on hand strength. [currentBid] is the current
  /// standing bid (if any) — a bid must exceed it to be valid.
  BotBidAction decideBid(int playerIndex, List<Card> hand,
      {int? currentBid}) {
    final floor = (currentBid ?? 6) + 1;
    if (floor > 13) return const BotBidAction.pass();

    final strength = _handStrength(hand);

    // Below the required floor → pass
    if (strength < floor.clamp(7, 13)) return const BotBidAction.pass();

    int bid = strength.clamp(floor.clamp(7, 13), 13);
    final trump = _bestTrumpSuit(hand);

    // Koz rule: if naming a suit, bid must be >= kozCount + 3.
    if (trump != null) {
      final kozCount = hand.where((c) => c.suit == trump).length;
      final minBid = kozCount + 3;
      if (bid < minBid) bid = minBid.clamp(7, 13);
    }

    if (bid < floor || bid > 13) return const BotBidAction.pass();

    return BotBidAction.bid(bid, trump);
  }

  /// Count trick-taking potential: high cards (A=4,K=3,Q=2,J=1) + long suits.
  int _handStrength(List<Card> hand) {
    int points = 0;
    for (final card in hand) {
      if (card.rank == Rank.ace) {
        points += 4;
      } else if (card.rank == Rank.king) {
        points += 3;
      } else if (card.rank == Rank.queen) {
        points += 2;
      } else if (card.rank == Rank.jack) {
        points += 1;
      }
    }
    // Each suit with 5+ cards adds 1 bonus per extra card.
    for (final suit in Suit.values) {
      final count = hand.where((c) => c.suit == suit).length;
      if (count > 4) points += count - 4;
    }
    // Scale to trick expectations (13 tricks max, 40 HCP in deck → ~1 trick per 3 HCP).
    return (points / 3).round();
  }

  /// Pick the suit with the most cards as trump, null if no-trump is preferred.
  Suit? _bestTrumpSuit(List<Card> hand) {
    Suit? best;
    int bestCount = 0;
    for (final suit in Suit.values) {
      final count = hand.where((c) => c.suit == suit).length;
      if (count > bestCount) {
        bestCount = count;
        best = suit;
      }
    }
    return bestCount >= 4 ? best : null;
  }

  // ─── Card play ──────────────────────────────────────────────────────────────

  Card decideCard({
    required int playerIndex,
    required List<Card> hand,
    required TrickState trick,
    required int trickNumber,
  }) {
    final legal = _legalCards(hand, trick, trickNumber);

    // If leading, play highest trump or highest card in longest suit.
    if (trick.playedCards.isEmpty) {
      return _chooseLead(legal, trick.trumpSuit);
    }

    // Try to win the trick.
    final winning = _winningCards(legal, trick);
    if (winning.isNotEmpty) {
      // Win with the lowest winning card.
      winning.sort((a, b) => a.rank.value.compareTo(b.rank.value));
      return winning.first;
    }

    // Can't win — play the lowest card.
    legal.sort((a, b) => a.rank.value.compareTo(b.rank.value));
    return legal.first;
  }

  Card _chooseLead(List<Card> legal, Suit? trumpSuit) {
    // Prefer leading high trump.
    if (trumpSuit != null) {
      final trumps =
          legal.where((c) => c.suit == trumpSuit).toList();
      if (trumps.isNotEmpty) {
        trumps.sort((a, b) => b.rank.value.compareTo(a.rank.value));
        return trumps.first;
      }
    }
    // Otherwise lead highest card.
    final sorted = [...legal]..sort((a, b) => b.rank.value.compareTo(a.rank.value));
    return sorted.first;
  }

  List<Card> _winningCards(List<Card> legal, TrickState trick) {
    return legal.where((c) => _wouldWin(c, trick)).toList();
  }

  bool _wouldWin(Card candidate, TrickState trick) {
    // Simulate adding this card to the trick and check if it wins.
    final allPlayed = [
      ...trick.playedCards.map((p) => p.card),
      candidate,
    ];
    final leadSuit = trick.leadSuit ?? candidate.suit;
    final trumpSuit = trick.trumpSuit;

    Card current = allPlayed.first;
    for (final card in allPlayed.skip(1)) {
      if (_beats(card, current, leadSuit, trumpSuit)) current = card;
    }
    return current == candidate;
  }

  bool _beats(Card challenger, Card current, Suit leadSuit, Suit? trumpSuit) {
    if (trumpSuit != null) {
      final ct = challenger.suit == trumpSuit;
      final cur = current.suit == trumpSuit;
      if (ct && !cur) return true;
      if (!ct && cur) return false;
      if (ct && cur) return challenger.rank.value > current.rank.value;
    }
    final cl = challenger.suit == leadSuit;
    final curl = current.suit == leadSuit;
    if (cl && !curl) return true;
    if (!cl && curl) return false;
    if (cl && curl) return challenger.rank.value > current.rank.value;
    return false;
  }

  List<Card> _legalCards(List<Card> hand, TrickState trick, int trickNumber) {
    // First play of trick 1 → must play trump if possible.
    if (trick.playedCards.isEmpty && trickNumber == 1 && trick.trumpSuit != null) {
      final trumps = hand.where((c) => c.suit == trick.trumpSuit).toList();
      if (trumps.isNotEmpty) return trumps;
    }

    // Must follow lead suit.
    if (trick.leadSuit != null) {
      final follow = hand.where((c) => c.suit == trick.leadSuit).toList();
      if (follow.isNotEmpty) return follow;
    }

    return hand;
  }
}
