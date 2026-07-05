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

  // Seats currently driven by bot logic in multiplayer (disconnected, timed
  // out repeatedly, or left). Irrelevant in single-player, where every
  // non-human seat is implicitly bot-controlled.
  final Set<int> _botSeats = {};

  // Consecutive turn-timeout count per seat, used to escalate a merely-slow
  // (but still connected) player to full bot control after repeated misses.
  final Map<int, int> _timeoutStrikes = {};
  final Duration _turnTimeout;
  static const _timeoutStrikesLimit = 3;

  // Bumped on every setSeatBotControlled call so a timeout timer armed
  // before a control-status flip can detect it's stale and bail, even if
  // _round hasn't changed in between (e.g. bot-on then bot-off in the same
  // turn, before either arm actually got to act).
  int _controlEpoch = 0;

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
    Duration turnTimeout = const Duration(seconds: 20),
  })  : humanIndex = humanIndex ?? 0,
        onStateChanged = onStateChanged,
        _deal = DealEngine(rng),
        _bid = BidEngine(),
        _play = PlayEngine(),
        _score = ScoreEngine(),
        _bot = BotPlayer(rng: rng),
        _turnTimeout = turnTimeout,
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

  @override
  Set<int> get botControlledSeats => Set.unmodifiable(_botSeats);

  bool get isMatchOver => _phase == EnginePhase.matchEnd;

  bool _isBotSeat(int seatIndex) =>
      multiplayerMode ? _botSeats.contains(seatIndex) : seatIndex != humanIndex;

  /// Marks [seatIndex] as bot-controlled (disconnected, repeatedly slow, or
  /// left), or hands control back to its human occupant. No-op outside
  /// multiplayer. Immediately drives the seat's pending turn if it's
  /// currently their move.
  void setSeatBotControlled(int seatIndex, bool isBotControlled) {
    if (!multiplayerMode) return;
    _controlEpoch++;
    if (isBotControlled) {
      _botSeats.add(seatIndex);
    } else {
      _botSeats.remove(seatIndex);
      _timeoutStrikes.remove(seatIndex);
    }
    if (_round == null) return;
    if (_phase == EnginePhase.bidding) _advanceBotBids();
    if (_phase == EnginePhase.playing) _scheduleBotPlay();
  }

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
    // A completed trick is shown briefly (see the 700ms delay in
    // _applyCardPlay) before the next trick actually starts. Nobody may act
    // during that window — otherwise the trick winner appears able to play
    // a 5th card into the already-complete trick.
    if (trick.isComplete) return [];
    if (trick.nextPlayerIndex != seatIndex) return [];
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
    _timeoutStrikes.remove(seatIndex);
    final order = biddingOrder(_match.starterIndex);
    _applyBid(seatIndex, bidValue, trumpSuit, order);
  }

  void applyPassForSeat(int seatIndex) {
    _assertPhase(EnginePhase.bidding);
    _timeoutStrikes.remove(seatIndex);
    final order = biddingOrder(_match.starterIndex);
    _applyPass(seatIndex, order);
  }

  void applyAcceptForSeat(int seatIndex, Suit? trumpSuit) {
    _assertPhase(EnginePhase.bidding);
    _timeoutStrikes.remove(seatIndex);
    final order = biddingOrder(_match.starterIndex);
    _applyAccept(seatIndex, trumpSuit, order);
  }

  void applyPlayForSeat(int seatIndex, Card card) {
    _assertPhase(EnginePhase.playing);
    _timeoutStrikes.remove(seatIndex);
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

  /// Accept the standing bid as the last bidder, naming [trumpSuit] (null =
  /// no-trump) as the new bidder before play starts.
  void humanAccept(Suit? trumpSuit) {
    _assertPhase(EnginePhase.bidding);
    final order = biddingOrder(_match.starterIndex);
    _applyAccept(humanIndex, trumpSuit, order);
  }

  void _applyBid(
      int playerIndex, int bidValue, Suit? trumpSuit, List<int> order) {
    final newBid = _bid.applyBid(_round!.bidState, order, playerIndex,
        bidValue, trumpSuit, _round!.hands[playerIndex]);
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

    _notify();
    _advanceBotBids();
  }

  void _applyAccept(int playerIndex, Suit? trumpSuit, List<int> order) {
    final newBid = _bid.applyAccept(
        _round!.bidState, order, playerIndex, trumpSuit, _round!.hands[playerIndex]);
    _round = _round!.copyWith(
      bidState: newBid,
      currentTrick: TrickState(
        leadPlayerIndex: newBid.leadPlayerIndex!,
        trumpSuit: newBid.trumpSuit,
      ),
    );
    _phase = EnginePhase.playing;
    _notify();
    _scheduleBotPlay();
  }

  void _autoDecideBid(int seatIndex, List<int> order, RoundState round) {
    final action = _bot.decideBid(seatIndex, round.hands[seatIndex],
        currentBid: round.bidState.bidValue);
    if (action.bidValue != null) {
      _applyBid(seatIndex, action.bidValue!, action.trumpSuit, order);
    } else if (round.bidState.turnIndex == order.length - 1 &&
        round.bidState.bidValue != null) {
      // Last bidder declining to raise must accept with their own trump.
      final trump = _bot.decideAcceptTrump(
          round.hands[seatIndex], round.bidState.bidValue!);
      _applyAccept(seatIndex, trump, order);
    } else {
      _applyPass(seatIndex, order);
    }
  }

  void _advanceBotBids() {
    if (_phase != EnginePhase.bidding) return;
    final order = biddingOrder(_match.starterIndex);
    final round = _round!;
    if (round.bidState.isComplete) return;

    final current = order[round.bidState.turnIndex];

    if (_isBotSeat(current)) {
      // Small delay so the bidding overlay updates visually between bids.
      Future.delayed(const Duration(milliseconds: 350), () {
        if (_phase != EnginePhase.bidding) return;
        final o = biddingOrder(_match.starterIndex);
        final r = _round!;
        if (r.bidState.isComplete) return;
        final c = o[r.bidState.turnIndex];
        if (!_isBotSeat(c)) return;
        _autoDecideBid(c, o, r);
      });
      return;
    }

    // A genuinely human (connected, not-yet-escalated) seat in multiplayer:
    // arm a turn timeout so a slow player doesn't stall everyone forever.
    if (!multiplayerMode) return;
    final capturedRound = round;
    final capturedEpoch = _controlEpoch;
    Future.delayed(_turnTimeout, () {
      if (_phase != EnginePhase.bidding) return;
      if (!identical(_round, capturedRound)) return; // they already acted
      if (_controlEpoch != capturedEpoch) return; // bot status flipped since
      final o = biddingOrder(_match.starterIndex);
      final c = o[capturedRound.bidState.turnIndex];

      final strikes = (_timeoutStrikes[c] ?? 0) + 1;
      _timeoutStrikes[c] = strikes;
      if (strikes >= _timeoutStrikesLimit) {
        setSeatBotControlled(c, true);
        return;
      }
      _autoDecideBid(c, o, capturedRound);
    });
  }

  // ─── Play ─────────────────────────────────────────────────────────────────

  void humanPlay(Card card) {
    _assertPhase(EnginePhase.playing);
    _applyCardPlay(humanIndex, card);
  }

  void _applyCardPlay(int playerIndex, Card card) {
    final round = _round!;
    final newTrick = _play.applyPlay(
      round.currentTrick,
      playerIndex,
      card,
      hand: round.hands[playerIndex],
      trickNumber: round.trickNumber,
    );
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

  void _autoDecideCard(int seatIndex, RoundState round, TrickState trick) {
    final card = _bot.decideCard(
      playerIndex: seatIndex,
      hand: round.hands[seatIndex],
      trick: trick,
      trickNumber: round.trickNumber,
    );
    _applyCardPlay(seatIndex, card);
  }

  void _advanceBotPlays() {
    if (_phase != EnginePhase.playing) return;
    final round = _round!;
    if (round.isRoundComplete) return;

    final trick = round.currentTrick;
    final current =
        trick.isComplete ? trick.winnerIndex! : trick.nextPlayerIndex;

    if (_isBotSeat(current)) {
      _autoDecideCard(current, round, trick);
      return;
    }

    // A genuinely human (connected, not-yet-escalated) seat in multiplayer:
    // arm a turn timeout so a slow player doesn't stall everyone forever.
    if (!multiplayerMode) return;
    final capturedRound = round;
    final capturedEpoch = _controlEpoch;
    Future.delayed(_turnTimeout, () {
      if (_phase != EnginePhase.playing) return;
      if (!identical(_round, capturedRound)) return; // they already acted
      if (_controlEpoch != capturedEpoch) return; // bot status flipped since
      final t = capturedRound.currentTrick;
      final c = t.isComplete ? t.winnerIndex! : t.nextPlayerIndex;

      final strikes = (_timeoutStrikes[c] ?? 0) + 1;
      _timeoutStrikes[c] = strikes;
      if (strikes >= _timeoutStrikesLimit) {
        setSeatBotControlled(c, true);
        return;
      }
      _autoDecideCard(c, capturedRound, t);
    });
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
