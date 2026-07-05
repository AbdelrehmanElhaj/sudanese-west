import 'package:engine_west/engine_west.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameNotifier extends Notifier<int> {
  late WestEngine engine;

  @override
  int build() {
    engine = WestEngine(humanIndex: 0);
    engine.onStateChanged = () => state = state + 1;
    return 0;
  }

  // ── Single-player mode ────────────────────────────────────────────────────

  void startSinglePlayer({int targetScore = 25}) {
    engine.startMatch(targetScore: targetScore);
  }

  // ── Multiplayer host mode ─────────────────────────────────────────────────

  /// Starts a multiplayer match where no bots auto-advance.
  /// The host sits at seat 0. Other seats are driven by relayed network actions.
  void startMultiplayerHost({int targetScore = 25}) {
    engine = WestEngine(humanIndex: 0, multiplayerMode: true);
    engine.onStateChanged = () => state = state + 1;
    engine.startMatch(
      targetScore: targetScore,
      gameMode: GameMode.onlineMultiplayer,
    );
  }

  // ── Actions (used by both SP and MP host) ─────────────────────────────────

  void bid(int bidValue, Suit? trumpSuit) => engine.humanBid(bidValue, trumpSuit);
  void pass() => engine.humanPass();
  void accept(Suit? trumpSuit) => engine.humanAccept(trumpSuit);
  void playCard(Card card) => engine.humanPlay(card);
  void nextRound() => engine.proceedToNextRound();
}

final gameNotifierProvider =
    NotifierProvider<GameNotifier, int>(GameNotifier.new);
