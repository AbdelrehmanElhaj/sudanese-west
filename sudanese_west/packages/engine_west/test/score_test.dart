import 'package:engine_west/engine_west.dart';
import 'package:test/test.dart';

void main() {
  group('ScoreEngine', () {
    late ScoreEngine engine;

    setUp(() => engine = ScoreEngine());

    // ── Success cases ──────────────────────────────────────────────────────

    test('bid 7, win 7 → +7 for bidding team, 0 for opponents', () {
      final result = engine.calculateResult(
        biddingTeam: Team.northSouth,
        bidValue: 7,
        tricksWon: {Team.northSouth: 7, Team.eastWest: 6},
      );
      expect(result.scoreChange[Team.northSouth], 7);
      expect(result.scoreChange[Team.eastWest], 0);
    });

    test('bid 8, win 10 → +10 for bidding team, 0 for opponents', () {
      final result = engine.calculateResult(
        biddingTeam: Team.northSouth,
        bidValue: 8,
        tricksWon: {Team.northSouth: 10, Team.eastWest: 3},
      );
      expect(result.scoreChange[Team.northSouth], 10);
      expect(result.scoreChange[Team.eastWest], 0);
    });

    // ── Failure cases ──────────────────────────────────────────────────────

    test('bid 9, win 8 (fail) → -9 for bidding team, +5 for opponents', () {
      final result = engine.calculateResult(
        biddingTeam: Team.northSouth,
        bidValue: 9,
        tricksWon: {Team.northSouth: 8, Team.eastWest: 5},
      );
      expect(result.scoreChange[Team.northSouth], -9);
      expect(result.scoreChange[Team.eastWest], 5);
    });

    test('bid 11, win 10 (fail) → -11 for bidding team, +3 for opponents', () {
      final result = engine.calculateResult(
        biddingTeam: Team.northSouth,
        bidValue: 11,
        tricksWon: {Team.northSouth: 10, Team.eastWest: 3},
      );
      expect(result.scoreChange[Team.northSouth], -11);
      expect(result.scoreChange[Team.eastWest], 3);
    });

    // ── Kabout (all 13 tricks) ─────────────────────────────────────────────

    test('kabout: bidding team wins all 13 tricks', () {
      final result = engine.calculateResult(
        biddingTeam: Team.northSouth,
        bidValue: 7,
        tricksWon: {Team.northSouth: 13, Team.eastWest: 0},
      );
      expect(result.wasKabout, isTrue);
      expect(result.scoreChange[Team.northSouth], 13);
    });

    // ── Redeal ─────────────────────────────────────────────────────────────

    test('redeal gives zero score change', () {
      final result = engine.redealResult();
      expect(result.wasRedeal, isTrue);
      expect(result.scoreChange[Team.northSouth], 0);
      expect(result.scoreChange[Team.eastWest], 0);
    });

    // ── MatchState integration ─────────────────────────────────────────────

    test('match accumulates scores across rounds', () {
      var match = MatchState.initial(targetScore: 25);

      final r1 = engine.calculateResult(
        biddingTeam: Team.northSouth,
        bidValue: 9,
        tricksWon: {Team.northSouth: 9, Team.eastWest: 4},
      );
      match = match.applyRoundResult(r1);
      expect(match.scores[Team.northSouth], 9);
      expect(match.scores[Team.eastWest], 0);

      final r2 = engine.calculateResult(
        biddingTeam: Team.eastWest,
        bidValue: 8,
        tricksWon: {Team.northSouth: 5, Team.eastWest: 8},
      );
      match = match.applyRoundResult(r2);
      expect(match.scores[Team.northSouth], 9);
      expect(match.scores[Team.eastWest], 8);
    });

    test('match is over when target reached', () {
      var match = MatchState.initial(targetScore: 25);
      for (int i = 0; i < 3; i++) {
        final r = engine.calculateResult(
          biddingTeam: Team.northSouth,
          bidValue: 9,
          tricksWon: {Team.northSouth: 9, Team.eastWest: 4},
        );
        match = match.applyRoundResult(r);
      }
      expect(match.scores[Team.northSouth], 27);
      expect(match.isMatchOver, isTrue);
      expect(match.winner, Team.northSouth);
    });
  });
}
