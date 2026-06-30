import 'package:engine_west/engine_west.dart';
import 'package:test/test.dart';

void main() {
  group('BidEngine', () {
    late BidEngine engine;

    setUp(() => engine = BidEngine());

    test('first bidder is the starter', () {
      final order = biddingOrder(0);
      expect(order, [0, 2, 1, 3]);
    });

    test('biddingOrder rotates with starter', () {
      expect(biddingOrder(1), [1, 3, 2, 0]);
      expect(biddingOrder(2), [2, 0, 3, 1]);
      expect(biddingOrder(3), [3, 1, 0, 2]);
    });

    test('bid completes immediately when first player bids', () {
      final order = biddingOrder(0);
      var state = BidState.initial();
      state = engine.applyBid(state, order, 0, 9, Suit.hearts);

      expect(state.isComplete, isTrue);
      expect(state.needsRedeal, isFalse);
      expect(state.bidValue, 9);
      expect(state.trumpSuit, Suit.hearts);
      expect(state.biddingTeam, Team.northSouth);
      expect(state.biddingPlayerIndex, 0);
      expect(state.leadPlayerIndex, 0);
    });

    test('partner bids after starter passes', () {
      final order = biddingOrder(0); // [0,2,1,3]
      var state = BidState.initial();
      state = engine.applyPass(state, order, 0); // player 0 passes
      expect(state.isComplete, isFalse);
      expect(engine.currentBidder(state, order), 2); // partner

      state = engine.applyBid(state, order, 2, 8, null); // no-trump
      expect(state.isComplete, isTrue);
      expect(state.biddingTeam, Team.northSouth);
      expect(state.biddingPlayerIndex, 2);
      expect(state.trumpSuit, isNull);
    });

    test('opponent bids after both team-A members pass', () {
      final order = biddingOrder(0); // [0,2,1,3]
      var state = BidState.initial();
      state = engine.applyPass(state, order, 0);
      state = engine.applyPass(state, order, 2);
      expect(engine.currentBidder(state, order), 1);

      state = engine.applyBid(state, order, 1, 7, Suit.spades);
      expect(state.biddingTeam, Team.eastWest);
      expect(state.bidValue, 7);
    });

    test('redeal when all 4 pass', () {
      final order = biddingOrder(0);
      var state = BidState.initial();
      state = engine.applyPass(state, order, 0);
      state = engine.applyPass(state, order, 2);
      state = engine.applyPass(state, order, 1);
      state = engine.applyPass(state, order, 3);

      expect(state.needsRedeal, isTrue);
      expect(state.isComplete, isTrue);
    });
  });
}
