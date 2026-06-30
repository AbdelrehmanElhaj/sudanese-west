import 'package:engine_west/engine_west.dart';

import 'game_serializer.dart';

/// GameFacade implementation backed by a [RemoteSnapshot] received from the
/// multiplayer server. Used by guest players.
class RemoteGameFacade implements GameFacade {
  final RemoteSnapshot _snapshot;
  final int _seatIndex;

  RemoteGameFacade(this._snapshot, this._seatIndex);

  @override
  EnginePhase get phase => _snapshot.phase;

  @override
  int get humanIndex => _seatIndex;

  @override
  MatchState get matchState => _snapshot.matchState;

  @override
  RoundState? get roundState => _snapshot.roundState;

  @override
  List<Card> get humanHand => _snapshot.myHand;

  @override
  List<Card> legalCardsForHuman() => _snapshot.legalCards;

  @override
  Team? get winner => _snapshot.winner;

  @override
  RoundResult? get lastRoundResult => _snapshot.lastResult;
}
