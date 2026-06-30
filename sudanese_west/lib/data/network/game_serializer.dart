import 'package:engine_west/engine_west.dart';
import 'package:flutter/material.dart' hide Card;

/// Converts engine state ↔ JSON maps for the multiplayer WebSocket protocol.
///
/// Card encoding: 2–3 char string → rank + suit.
///   Ranks: A K Q J T 9 8 7 6 5 4 3 2
///   Suits: S H D C
///   e.g. "AS" = Ace of Spades, "TH" = Ten of Hearts, "9D" = Nine of Diamonds
class GameSerializer {
  // ── Card primitives ────────────────────────────────────────────────────────

  static String encodeCard(Card card) =>
      '${_rankCode(card.rank)}${encodeSuitChar(card.suit)}';

  static Card decodeCard(String code) {
    final suitChar = code[code.length - 1];
    final rankStr = code.substring(0, code.length - 1);
    return Card(_decodeRank(rankStr), _decodeSuitChar(suitChar));
  }

  static String encodeSuitChar(Suit s) {
    if (s == Suit.spades) return 'S';
    if (s == Suit.hearts) return 'H';
    if (s == Suit.diamonds) return 'D';
    return 'C';
  }

  static String? encodeSuit(Suit? s) => s == null ? null : encodeSuitChar(s);

  static Suit? decodeSuit(String? s) =>
      s == null ? null : _decodeSuitChar(s);

  static String _rankCode(Rank r) {
    if (r == Rank.ace) return 'A';
    if (r == Rank.king) return 'K';
    if (r == Rank.queen) return 'Q';
    if (r == Rank.jack) return 'J';
    if (r == Rank.ten) return 'T';
    return r.value.toString();
  }

  static Rank _decodeRank(String s) {
    if (s == 'A') return Rank.ace;
    if (s == 'K') return Rank.king;
    if (s == 'Q') return Rank.queen;
    if (s == 'J') return Rank.jack;
    if (s == 'T') return Rank.ten;
    final v = int.parse(s);
    return Rank.values.firstWhere((r) => r.value == v);
  }

  static Suit _decodeSuitChar(String s) {
    if (s == 'S') return Suit.spades;
    if (s == 'H') return Suit.hearts;
    if (s == 'D') return Suit.diamonds;
    return Suit.clubs;
  }

  static String _encodeTeam(Team t) =>
      t == Team.northSouth ? 'ns' : 'ew';

  static Team _decodeTeam(String s) =>
      s == 'ns' ? Team.northSouth : Team.eastWest;

  // ── Full state serialization (host → server broadcast) ────────────────────

  /// Serializes the full engine state to a JSON-safe map.
  /// All 4 hands are included — guests extract only their own hand by seat
  /// index. (Per-seat filtering is a Phase 5 security improvement.)
  static Map<String, dynamic> serialize(WestEngine engine) {
    final round = engine.roundState;

    final currentTurnSeat = engine.phase == EnginePhase.playing
        ? engine.currentPlayTurnIndex
        : (engine.phase == EnginePhase.bidding
            ? engine.currentBidderIndex
            : -1);

    return {
      'phase': engine.phase.name,
      'matchState': {
        'scores': {
          'ns': engine.matchState.scores[Team.northSouth] ?? 0,
          'ew': engine.matchState.scores[Team.eastWest] ?? 0,
        },
        'targetScore': engine.matchState.targetScore,
        'roundNumber': engine.matchState.currentRoundNumber,
        'starterIndex': engine.matchState.starterIndex,
      },
      'roundState': round == null
          ? null
          : {
              'hands': [
                for (final hand in round.hands) hand.map(encodeCard).toList(),
              ],
              'trickNumber': round.trickNumber,
              'bidState': {
                'turnIndex': round.bidState.turnIndex,
                'passed': round.bidState.passed,
                'bidValue': round.bidState.bidValue,
                'trumpSuit': encodeSuit(round.bidState.trumpSuit),
                'biddingPlayerIndex': round.bidState.biddingPlayerIndex,
                'biddingTeam': round.bidState.biddingTeam == null
                    ? null
                    : _encodeTeam(round.bidState.biddingTeam!),
                'leadPlayerIndex': round.bidState.leadPlayerIndex,
                'isComplete': round.bidState.isComplete,
                'needsRedeal': round.bidState.needsRedeal,
              },
              'currentTrick': {
                'leadPlayerIndex': round.currentTrick.leadPlayerIndex,
                'leadSuit': encodeSuit(round.currentTrick.leadSuit),
                'trumpSuit': encodeSuit(round.currentTrick.trumpSuit),
                'playedCards': round.currentTrick.playedCards
                    .map((pc) => {
                          'playerIndex': pc.playerIndex,
                          'card': encodeCard(pc.card),
                        })
                    .toList(),
                'winnerIndex': round.currentTrick.winnerIndex,
                'isComplete': round.currentTrick.isComplete,
              },
              'tricksWon': {
                'ns': round.tricksWon[Team.northSouth] ?? 0,
                'ew': round.tricksWon[Team.eastWest] ?? 0,
              },
            },
      'currentTurnSeat': currentTurnSeat,
      'legalCards': currentTurnSeat >= 0
          ? engine.legalCardsForSeat(currentTurnSeat).map(encodeCard).toList()
          : <String>[],
      'lastResult': engine.lastRoundResult == null
          ? null
          : {
              'biddingTeam': engine.lastRoundResult!.biddingTeam == null
                  ? null
                  : _encodeTeam(engine.lastRoundResult!.biddingTeam!),
              'bidValue': engine.lastRoundResult!.bidValue,
              'tricksWon': {
                'ns': engine.lastRoundResult!.tricksWon[Team.northSouth] ?? 0,
                'ew': engine.lastRoundResult!.tricksWon[Team.eastWest] ?? 0,
              },
              'scoreChange': {
                'ns':
                    engine.lastRoundResult!.scoreChange[Team.northSouth] ?? 0,
                'ew': engine.lastRoundResult!.scoreChange[Team.eastWest] ?? 0,
              },
              'wasRedeal': engine.lastRoundResult!.wasRedeal,
              'wasKabout': engine.lastRoundResult!.wasKabout,
            },
    };
  }

  // ── Deserialization (guest receives state from server) ────────────────────

  static RemoteSnapshot deserialize(
      Map<String, dynamic> json, int mySeatIndex) {
    final phaseStr = json['phase'] as String;
    final phase =
        EnginePhase.values.firstWhere((e) => e.name == phaseStr);

    // Match state
    final ms = json['matchState'] as Map<String, dynamic>;
    final scoresMap = ms['scores'] as Map<String, dynamic>;
    final scores = {
      Team.northSouth: scoresMap['ns'] as int,
      Team.eastWest: scoresMap['ew'] as int,
    };
    final matchState = MatchState(
      scores: scores,
      roundHistory: const [],
      targetScore: ms['targetScore'] as int,
      gameMode: GameMode.onlineMultiplayer,
      currentRoundNumber: ms['roundNumber'] as int,
      starterIndex: ms['starterIndex'] as int,
    );

    // Round state
    RoundState? roundState;
    List<Card> myHand = const [];
    if (json['roundState'] != null) {
      final rs = json['roundState'] as Map<String, dynamic>;
      final handsJson = rs['hands'] as List<dynamic>;

      final hands = <List<Card>>[];
      for (int i = 0; i < handsJson.length; i++) {
        final codes = handsJson[i] as List<dynamic>;
        if (i == mySeatIndex) {
          final h = codes.map((c) => decodeCard(c as String)).toList();
          hands.add(h);
          myHand = h;
        } else {
          // Opponents: dummy cards of the correct count (only .length is used).
          hands.add(
              List.filled(codes.length, Card(Rank.two, Suit.clubs)));
        }
      }

      final bs = rs['bidState'] as Map<String, dynamic>;
      final bidState = BidState(
        turnIndex: bs['turnIndex'] as int,
        passed: (bs['passed'] as List<dynamic>).cast<bool>(),
        bidValue: bs['bidValue'] as int?,
        trumpSuit: decodeSuit(bs['trumpSuit'] as String?),
        biddingPlayerIndex: bs['biddingPlayerIndex'] as int?,
        biddingTeam: bs['biddingTeam'] == null
            ? null
            : _decodeTeam(bs['biddingTeam'] as String),
        leadPlayerIndex: bs['leadPlayerIndex'] as int?,
        isComplete: bs['isComplete'] as bool,
        needsRedeal: bs['needsRedeal'] as bool,
      );

      final tc = rs['currentTrick'] as Map<String, dynamic>;
      final playedCards = (tc['playedCards'] as List<dynamic>).map((p) {
        final pm = p as Map<String, dynamic>;
        return PlayedCard(
          pm['playerIndex'] as int,
          decodeCard(pm['card'] as String),
        );
      }).toList();
      final trickState = TrickState(
        leadPlayerIndex: tc['leadPlayerIndex'] as int,
        leadSuit: decodeSuit(tc['leadSuit'] as String?),
        trumpSuit: decodeSuit(tc['trumpSuit'] as String?),
        playedCards: playedCards,
        winnerIndex: tc['winnerIndex'] as int?,
        isComplete: tc['isComplete'] as bool,
      );

      final tw = rs['tricksWon'] as Map<String, dynamic>;
      roundState = RoundState(
        hands: hands,
        bidState: bidState,
        trickNumber: rs['trickNumber'] as int,
        currentTrick: trickState,
        tricksWon: {
          Team.northSouth: tw['ns'] as int,
          Team.eastWest: tw['ew'] as int,
        },
      );
    }

    // Legal cards (only populated when it's our turn)
    final currentTurnSeat = json['currentTurnSeat'] as int? ?? -1;
    var legalCards = <Card>[];
    if (currentTurnSeat == mySeatIndex) {
      final lc = json['legalCards'] as List<dynamic>?;
      if (lc != null) {
        legalCards = lc.map((c) => decodeCard(c as String)).toList();
      }
    }

    // Last result
    RoundResult? lastResult;
    if (json['lastResult'] != null) {
      final lr = json['lastResult'] as Map<String, dynamic>;
      final tw = lr['tricksWon'] as Map<String, dynamic>;
      final sc = lr['scoreChange'] as Map<String, dynamic>;
      lastResult = RoundResult(
        biddingTeam: lr['biddingTeam'] == null
            ? null
            : _decodeTeam(lr['biddingTeam'] as String),
        bidValue: lr['bidValue'] as int?,
        tricksWon: {
          Team.northSouth: tw['ns'] as int,
          Team.eastWest: tw['ew'] as int,
        },
        scoreChange: {
          Team.northSouth: sc['ns'] as int,
          Team.eastWest: sc['ew'] as int,
        },
        wasRedeal: lr['wasRedeal'] as bool,
        wasKabout: lr['wasKabout'] as bool,
      );
    }

    return RemoteSnapshot(
      phase: phase,
      matchState: matchState,
      roundState: roundState,
      myHand: myHand,
      legalCards: legalCards,
      lastResult: lastResult,
      currentTurnSeat: currentTurnSeat,
    );
  }
}

/// Deserialized game state snapshot for a guest player.
@immutable
class RemoteSnapshot {
  final EnginePhase phase;
  final MatchState matchState;
  final RoundState? roundState;
  final List<Card> myHand;
  final List<Card> legalCards;
  final RoundResult? lastResult;
  final int currentTurnSeat; // -1 if nobody's turn (roundEnd / matchEnd)

  Team? get winner => matchState.winner;

  const RemoteSnapshot({
    required this.phase,
    required this.matchState,
    required this.roundState,
    required this.myHand,
    required this.legalCards,
    required this.lastResult,
    required this.currentTurnSeat,
  });
}
