import 'rank.dart';
import 'suit.dart';

class Card {
  final Rank rank;
  final Suit suit;

  const Card(this.rank, this.suit);

  @override
  bool operator ==(Object other) =>
      other is Card && rank == other.rank && suit == other.suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => '${rank.name}_of_${suit.name}';
}

List<Card> buildFullDeck() {
  return [
    for (final suit in Suit.values)
      for (final rank in Rank.values) Card(rank, suit),
  ];
}
