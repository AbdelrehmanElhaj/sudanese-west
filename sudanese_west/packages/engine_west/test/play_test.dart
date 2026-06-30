import 'package:engine_west/engine_west.dart';
import 'package:test/test.dart';

void main() {
  group('PlayEngine', () {
    late PlayEngine engine;

    setUp(() => engine = PlayEngine());

    // ── Legal cards ────────────────────────────────────────────────────────

    test('trick 1 leader must play trump', () {
      final hand = [
        Card(Rank.ace, Suit.spades),
        Card(Rank.king, Suit.hearts),
        Card(Rank.two, Suit.clubs),
      ];
      final trick = TrickState(leadPlayerIndex: 0, trumpSuit: Suit.spades);
      final legal = engine.legalCards(
          hand: hand, trick: trick, trickNumber: 1, isLeader: true);
      expect(legal, [Card(Rank.ace, Suit.spades)]);
    });

    test('non-leader must follow suit', () {
      final hand = [
        Card(Rank.ace, Suit.hearts),
        Card(Rank.king, Suit.hearts),
        Card(Rank.two, Suit.clubs),
      ];
      final trick = TrickState(
        leadPlayerIndex: 1,
        leadSuit: Suit.hearts,
        trumpSuit: Suit.spades,
        playedCards: [PlayedCard(1, Card(Rank.three, Suit.hearts))],
      );
      final legal = engine.legalCards(
          hand: hand, trick: trick, trickNumber: 2, isLeader: false);
      expect(legal.length, 2);
      expect(legal.every((c) => c.suit == Suit.hearts), isTrue);
    });

    test('no lead suit in hand — any card allowed', () {
      final hand = [
        Card(Rank.ace, Suit.spades),
        Card(Rank.two, Suit.clubs),
      ];
      final trick = TrickState(
        leadPlayerIndex: 1,
        leadSuit: Suit.hearts,
        trumpSuit: null,
        playedCards: [PlayedCard(1, Card(Rank.three, Suit.hearts))],
      );
      final legal = engine.legalCards(
          hand: hand, trick: trick, trickNumber: 3, isLeader: false);
      expect(legal.length, 2);
    });

    // ── Trick winner ───────────────────────────────────────────────────────

    test('highest lead-suit card wins when no trump played', () {
      var trick = TrickState(
          leadPlayerIndex: 0, trumpSuit: Suit.spades);
      trick = engine.applyPlay(trick, 0, Card(Rank.three, Suit.hearts));
      trick = engine.applyPlay(trick, 1, Card(Rank.ace, Suit.hearts));
      trick = engine.applyPlay(trick, 2, Card(Rank.king, Suit.hearts));
      trick = engine.applyPlay(trick, 3, Card(Rank.two, Suit.clubs));

      expect(trick.isComplete, isTrue);
      expect(trick.winnerIndex, 1); // ace of hearts
    });

    test('trump beats lead suit', () {
      var trick = TrickState(
          leadPlayerIndex: 0, trumpSuit: Suit.spades);
      trick = engine.applyPlay(trick, 0, Card(Rank.ace, Suit.hearts));
      trick = engine.applyPlay(trick, 1, Card(Rank.two, Suit.spades)); // trump
      trick = engine.applyPlay(trick, 2, Card(Rank.king, Suit.hearts));
      trick = engine.applyPlay(trick, 3, Card(Rank.three, Suit.diamonds));

      expect(trick.winnerIndex, 1); // two of spades (trump)
    });

    test('highest trump wins when multiple trumps played', () {
      var trick = TrickState(
          leadPlayerIndex: 0, trumpSuit: Suit.spades);
      trick = engine.applyPlay(trick, 0, Card(Rank.ace, Suit.hearts));
      trick = engine.applyPlay(trick, 1, Card(Rank.jack, Suit.spades));
      trick = engine.applyPlay(trick, 2, Card(Rank.ace, Suit.spades));
      trick = engine.applyPlay(trick, 3, Card(Rank.two, Suit.spades));

      expect(trick.winnerIndex, 2); // ace of spades
    });

    test('no-trump: highest lead-suit card wins always', () {
      var trick = TrickState(
          leadPlayerIndex: 0, trumpSuit: null);
      trick = engine.applyPlay(trick, 0, Card(Rank.three, Suit.hearts));
      trick = engine.applyPlay(trick, 1, Card(Rank.ace, Suit.diamonds));
      trick = engine.applyPlay(trick, 2, Card(Rank.king, Suit.hearts));
      trick = engine.applyPlay(trick, 3, Card(Rank.queen, Suit.clubs));

      expect(trick.winnerIndex, 2); // king of hearts (lead suit)
    });

    // ── Trick counting ─────────────────────────────────────────────────────

    test('countTricks maps winners to teams correctly', () {
      // 0,2 = northSouth; 1,3 = eastWest
      final winners = [0, 1, 0, 2, 3, 0, 0, 1, 2, 3, 0, 0, 1];
      final counts = engine.countTricks(winners);
      expect(counts[Team.northSouth], 8);
      expect(counts[Team.eastWest], 5);
    });
  });
}
