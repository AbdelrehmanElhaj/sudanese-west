import 'dart:math';
import '../models/card.dart';

class DealEngine {
  final Random _rng;

  DealEngine([Random? rng]) : _rng = rng ?? Random();

  /// Returns 4 hands of 13 cards each, shuffled.
  List<List<Card>> deal() {
    final deck = buildFullDeck()..shuffle(_rng);
    return List.generate(4, (i) => deck.sublist(i * 13, (i + 1) * 13));
  }
}
