import '../models/card.dart';
import '../models/match_state.dart';
import '../models/round_result.dart';
import '../models/round_state.dart';
import '../models/team.dart';
import 'engine_phase.dart';

/// Read-only interface that both WestEngine (local) and RemoteGameFacade
/// (network guest) implement. UI widgets depend on this, never on a concrete
/// engine type.
abstract class GameFacade {
  EnginePhase get phase;
  int get humanIndex; // local player's seat index (0–3)
  MatchState get matchState;
  RoundState? get roundState;
  List<Card> get humanHand;
  List<Card> legalCardsForHuman();
  Team? get winner;
  RoundResult? get lastRoundResult;
}
