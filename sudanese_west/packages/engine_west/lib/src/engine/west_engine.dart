import 'dart:math';

import '../bot/bot_player.dart';
import '../models/bid_state.dart';
import '../models/card.dart';
import '../models/game_mode.dart';
import '../models/match_state.dart';
import '../models/round_result.dart';
import '../models/round_state.dart';
import '../models/suit.dart';
import '../models/team.dart';
import '../models/trick_state.dart';
import 'bid_engine.dart';
import 'deal_engine.dart';
import 'engine_phase.dart';
import 'game_facade.dart';
import 'play_engine.dart';
import 'score_engine.dart';

class WestEngine implements GameFacade {
  final DealEngine _deal;
  final BidEngine _bid;
  final PlayEngine _play;
  final ScoreEngine _score;
  final BotPlayer _bot;

  MatchState _match;
  RoundState? _round;
  EnginePhase _phase = EnginePhase.idle;

  /// Human player index (always 0 in single-player mode).
  @override
  final int humanIndex;

  /// When true, bots never auto-advance — all seats wait for external input.
  final bool multiplayerMode;

  /// Called after each engine state change so the UI can react.
  void Function()? onStateChanged;

  WestEngine({
    int? humanIndex,
    Random? rng,
    void Function()? onStateChanged,
    this.multiplayerMode = false,
  })  : humanIndex = humanIndex ?? 0,
        onStateChanged = onStateChanged,
        _deal = DealEngine(rng),
        _bid = BidEngine(),
        _play = PlayEngine(),
        _score = ScoreEngine(),
        _bot = BotPlayer(rng: rng),
        _match = MatchState.initial();

  // ─── GameFacade / Getters ─────────────────────────────────────────────────

  @override
  MatchState get matchState => _match;

  @override
  RoundState? get roundState => _round;

  @override
  EnginePhase get phase => _phase;

  @override
  Team? get winner => _match.winner;

  @override
  List<Card> get humanHand => _round?.hands[humanIndex] ?? [];

  @override
  List<Card> legalCardsForHuman() => legalCardsForSeat(humanIndex);

  @override
  RoundResult? get lastRoundResult =>
      _match.roundHistory.isEmpty ? null : _match.roundHistory.last;

  bool get isMatchOver => _phase == EnginePhase.matchEnd;

  // ─── Multiplayer helpers ──────────────────────────────────────────────────

  /// Index of the player who should act next during bidding, or -1.
  int get currentBidderIndex {
    if (_phase != EnginePhase.bidding || _round == null) return -1;
    final order = biddingOrder(_match.starterIndex);
    return order[_round!.bidState.turnIndex];
  }

  /// Index of the player whose turn it is during play, or -1.
  int get currentPlayTurnIndex {
    if (_phase != EnginePhase.playing || _round == null) return -1;
    final trick = _round!.currentTrick;
    if (trick.isComplete) return trick.winnerIndex!;
    return trick.nextPlayerIndex;
  }

  /// Legal cards for [seatIndex] if it is currently their turn, else [].
  List<Card> legalCardsForSeat(int seatIndex) {
    if (_phase != EnginePhase.playing || _round == null) return [];
    final round = _round!;
    final trick = round.currentTrick;
    final current = trick.isComplete ? trick.winnerIndex! : trick.nextPlayerIndex;
    if (current != seatIndex) return [];
    final isLeader =
        trick.leadPlayerIndex == seatIndex && trick.playedCards.isEmpty;
    return _play.legalCards(
      hand: round.hands[seatIndex],
      trick: trick,
      trickNumber: round.trickNumber,
      isLeader: isLeader,
    );
  }

  // ─── Multiplayer public seat actions ─────────────────────────────────────

  void applyBidForSeat(int seatIndex, int bidValue, Suit? trumpSuit) {
    _assertPhase(EnginePhase.bidding);
    final order = biddingOrder(_match.starterIndex);
    _applyBid(seatIndex, bidValue, trumpSuit, order);
  }

  void applyPassForSeat(int seatIndex) {
    _assertPhase(EnginePhase.bidding);
    final order = biddingOrder(_match.starterIndex);
    _applyPass(seatIndex, order);
  }

  void applyPlayForSeat(int seatIndex, Card card) {
    _assertPhase(EnginePhase.playing);
    _applyCardPlay(seatIndex, card);
  }

  // ─── Match / Round lifecycle ───────────────────────────────────────────────

  void startMatch({
    int targetScore = 25,
    GameMode gameMode = GameMode.singlePlayerVsBots,
  }) {
    _match = MatchState.initial(
      targetScore: targetScore,
      gameMode: gameMode,
    );
    _phase = EnginePhase.idle;
    startNewRound();
  }

  void startNewRound() {
    final hands = _deal.deal();
    final order = biddingOrder(_match.starterIndex);
    final firstBidder = order[0];

    _round = RoundState(
      hands: hands,
      bidState: BidState.initial(),
      trickNumber: 1,
      currentTrick: TrickState(
        leadPlayerIndex: firstBidder,
        trumpSuit: null,
      ),
      tricksWon: {Team.northSouth: 0, Team.eastWest: 0},
    );
    _phase = EnginePhase.bidding;
    _notify();

    _advanceBotBids();
  }

  // ─── Bidding ──────────────────────────────────────────────────────────────

  void humanBid(int bidValue, Suit? trumpSuit) {
    _assertPhase(EnginePhase.bidding);
    if (!BidEngine.isKozRuleValid(
        _round!.hands[humanIndex], bidValue, trumpSuit)) {
      throw ArgumentError(
          'Koz rule violated: too many trump cards for bid $bidValue');
    }
    final currentBid = _round!.bidState.bidValue;
    if (currentBid != null && bidValue <= currentBid) {
      throw ArgumentError(
          'Bid must be higher than the current standing bid ($currentBid)');
    }
    final order = biddingOrder(_match.starterIndex);
    _applyBid(humanIndex, bidValue, trumpSuit, order);
  }

  void humanPass() {
    _assertPhase(EnginePhase.bidding);
    final order = biddingOrder(_match.starterIndex);
    _applyPass(humanIndex, order);
  }

  void _applyBid(
      int playerIndex, int bidValue, Suit? trumpSuit, List<int> order) {
    final newBid = _bid.applyBid(
        _round!.bidState, order, playerIndex, bidValue, trumpSuit);
    _round = _round!.copyWith(bidState: newBid);

    if (!newBid.isComplete) {
      // Not the last bidder yet — move on to the next player's turn.
      _notify();
      _advanceBotBids();
      return;
    }

    _round = _round!.copyWith(
      currentTrick: TrickState(
        leadPlayerIndex: newBid.leadPlayerIndex!,
        trumpSuit: newBid.trumpSuit,
      ),
    );
    _phase = EnginePhase.playing;
    _notify();
    _scheduleBotPlay();
  }

  void _applyPass(int playerIndex, List<int> order) {
    final newBid = _bid.applyPass(_round!.bidState, order, playerIndex);
    _round = _round!.copyWith(bidState: newBid);

    if (newBid.needsRedeal) {
      _finaliseRedeal();
      return;
    }

    if (newBid.isComplete) {
      // Last player accepted the standing bid as-is — start play.
      _round = _round!.copyWith(
        currentTrick: TrickState(
          leadPlayerIndex: newBid.leadPlayerIndex!,
          trumpSuit: newBid.trumpSuit,
        ),
      );
      _phase = EnginePhase.playing;
      _notify();
      _scheduleBotPlay();
      return;
    }

    _notify();
    _advanceBotBids();
  }

  void _advanceBotBids() {
    if (multiplayerMode) return;
    if (_phase != EnginePhase.bidding) return;
    final order = biddingOrder(_match.starterIndex);
    final round = _round!;
    if (round.bidState.isComplete) return;

    final current = order[round.bidState.turnIndex];
    if (current == humanIndex) return;

    // Small delay so the bidding overlay updates visually between each bot bid.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (_phase != EnginePhase.bidding) return;
      final o = biddingOrder(_match.starterIndex);
      final r = _round!;
      if (r.bidState.isComplete) return;
      final c = o[r.bidState.turnIndex];
      if (c == humanIndex) return;
      final action =
          _bot.decideBid(c, r.hands[c], currentBid: r.bidState.bidValue);
      if (action.bidValue != null) {
        _applyBid(c, action.bidValue!, action.trumpSuit, o);
      } else {
        _applyPass(c, o);
      }
    });
  }

  // ─── Play ─────────────────────────────────────────────────────────────────

  void humanPlay(Card card) {
    _assertPhase(EnginePhase.playing);
    _applyCardPlay(humanIndex, card);
  }

  void _applyCardPlay(int playerIndex, Card card) {
    final round = _round!;
    final newTrick = _play.applyPlay(round.currentTrick, playerIndex, card);
    final newHands = List<List<Card>>.from(round.hands.map(List<Card>.from));
    newHands[playerIndex].remove(card);

    if (!newTrick.isComplete) {
      _round = round.copyWith(currentTrick: newTrick, hands: newHands);
      _notify();
      _scheduleBotPlay();
      return;
    }

    final winnerTeam = teamOf(newTrick.winnerIndex!);
    final newTricksWon = Map<Team, int>.from(round.tricksWon);
    newTricksWon[winnerTeam] = newTricksWon[winnerTeam]! + 1;

    final nextTrickNumber = round.trickNumber + 1;

    if (nextTrickNumber > 13) {
      _round = round.copyWith(
        currentTrick: newTrick,
        hands: newHands,
        tricksWon: newTricksWon,
        trickNumber: nextTrickNumber,
      );
      _finaliseRound();
      return;
    }

    // Show the completed trick briefly, then advance to the next one.
    _round = round.copyWith(
      currentTrick: newTrick,
      hands: newHands,
      tricksWon: newTricksWon,
      trickNumber: nextTrickNumber,
    );
    _notify();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (_phase != EnginePhase.playing) return;
      final nextTrick = _play.nextTrick(
        newTrick.winnerIndex!,
        _round!.bidState.trumpSuit,
      );
      _round = _round!.copyWith(currentTrick: nextTrick);
      _notify();
      _scheduleBotPlay();
    });
  }

  void _advanceBotPlays() {
    if (multiplayerMode) return;
    if (_phase != EnginePhase.playing) return;
    final round = _round!;
    if (round.isRoundComplete) return;

    final trick = round.currentTrick;
    final current =
        trick.isComplete ? trick.winnerIndex! : trick.nextPlayerIndex;

    if (current == humanIndex) return;

    final card = _bot.decideCard(
      playerIndex: current,
      hand: round.hands[current],
      trick: trick,
      trickNumber: round.trickNumber,
    );
    _applyCardPlay(current, card);
  }

  // ─── Round / Match finalisation ────────────────────────────────────────────

  void _finaliseRedeal() {
    final result = _score.redealResult();
    _match = _match.applyRoundResult(result);
    _phase = EnginePhase.roundEnd;
    _notify();
  }

  void _finaliseRound() {
    final round = _round!;
    final bid = round.bidState;

    final result = _score.calculateResult(
      biddingTeam: bid.biddingTeam!,
      bidValue: bid.bidValue!,
      tricksWon: round.tricksWon,
      trumpSuit: bid.trumpSuit,
    );

    _match = _match.applyRoundResult(result);

    _phase = _match.isMatchOver ? EnginePhase.matchEnd : EnginePhase.roundEnd;
    _notify();
  }

  void proceedToNextRound() {
    if (_phase == EnginePhase.roundEnd) {
      startNewRound();
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _assertPhase(EnginePhase expected) {
    if (_phase != expected) {
      throw StateError('Expected phase $expected but was $_phase');
    }
  }

  void _notify() => onStateChanged?.call();

  // Schedules a single bot-play step after a short delay.
  // Using Future.delayed breaks the synchronous recursion chain and lets the
  // UI render each played card before the next one arrives.
  void _scheduleBotPlay() {
    Future.delayed(const Duration(milliseconds: 400), _advanceBotPlays);
  }
}
