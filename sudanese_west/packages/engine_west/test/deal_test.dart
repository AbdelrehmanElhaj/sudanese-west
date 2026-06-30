import 'package:engine_west/engine_west.dart';
import 'package:test/test.dart';

void main() {
  group('DealEngine', () {
    late DealEngine engine;

    setUp(() => engine = DealEngine());

    test('deals exactly 52 unique cards', () {
      final hands = engine.deal();
      final all = hands.expand((h) => h).toList();
      expect(all.length, 52);
      expect(all.toSet().length, 52);
    });

    test('deals 4 hands of 13 cards each', () {
      final hands = engine.deal();
      expect(hands.length, 4);
      for (final hand in hands) {
        expect(hand.length, 13);
      }
    });

    test('covers all suits and ranks', () {
      final hands = engine.deal();
      final all = hands.expand((h) => h).toSet();
      for (final suit in Suit.values) {
        for (final rank in Rank.values) {
          expect(all.contains(Card(rank, suit)), isTrue,
              reason: '${rank.name}_of_${suit.name} not dealt');
        }
      }
    });
  });
}
