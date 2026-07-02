import 'package:engine_west/engine_west.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_provider.dart';
import '../../data/multiplayer_provider.dart';
import '../widgets/playing_card_widget.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Screen root
// ══════════════════════════════════════════════════════════════════════════════

class GameTableScreen extends ConsumerWidget {
  /// True when rendering a multiplayer guest view (reads from multiplayerProvider).
  /// False (default) for single-player or multiplayer host.
  final bool multiplayerMode;

  /// Optional real player names by seat index, shown in overlays and seat labels.
  /// Passed from the lobby for both host and guest so players see names, not
  /// compass directions, when waiting on others.
  final Map<int, String>? seatNames;

  const GameTableScreen({
    super.key,
    this.multiplayerMode = false,
    this.seatNames,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Choose the data source and action callbacks based on mode.
    final GameFacade facade;
    final void Function(int, Suit?) onBid;
    final VoidCallback onPass;
    final void Function(Card) onPlayCard;
    final VoidCallback onNextRound;
    final VoidCallback? onRestartMatch; // null = use built-in SP restart

    if (multiplayerMode) {
      ref.watch(multiplayerProvider);
      final mpNotifier = ref.read(multiplayerProvider.notifier);
      final f = mpNotifier.facade;
      if (f == null) {
        return const Scaffold(
          backgroundColor: Color(0xFF1B5E20),
          body: Center(child: CircularProgressIndicator(color: Colors.white54)),
        );
      }
      facade = f;
      onBid = (v, s) => mpNotifier.sendBid(v, s);
      onPass = mpNotifier.sendPass;
      onPlayCard = mpNotifier.sendPlay;
      onNextRound = mpNotifier.sendNextRound;
      onRestartMatch = () => Navigator.of(context).pop();
    } else {
      ref.watch(gameNotifierProvider);
      final notifier = ref.read(gameNotifierProvider.notifier);
      facade = notifier.engine;
      onBid = (v, s) => notifier.bid(v, s);
      onPass = notifier.pass;
      onPlayCard = notifier.playCard;
      onNextRound = notifier.nextRound;
      onRestartMatch = null; // uses _NewMatchStarter
    }

    final phase = facade.phase;

    final isPlaying = phase == EnginePhase.playing;

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Always visible: table ───────────────────────────────────────
            Column(
              children: [
                _ScoreBar(facade: facade),
                Expanded(
                  child: _TableLayout(
                    facade: facade,
                    onPlayCard: onPlayCard,
                    seatNames: seatNames,
                  ),
                ),
              ],
            ),

            // ── Overlays (do not cover the hand at bottom) ──────────────────
            if (phase == EnginePhase.bidding)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 116,
                child: _BiddingOverlay(
                  facade: facade,
                  onBid: onBid,
                  onPass: onPass,
                  seatNames: seatNames,
                ),
              ),

            if (phase == EnginePhase.roundEnd)
              _RoundSummaryOverlay(facade: facade, onNextRound: onNextRound),

            if (phase == EnginePhase.matchEnd)
              _MatchEndOverlay(facade: facade, onRestart: onRestartMatch),

            // ── Human hand — always on top so it shows during bidding ───────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _HumanHand(
                facade: facade,
                isPlaying: isPlaying,
                onPlayCard: onPlayCard,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Score bar
// ══════════════════════════════════════════════════════════════════════════════

class _ScoreBar extends StatelessWidget {
  final GameFacade facade;
  const _ScoreBar({required this.facade});

  @override
  Widget build(BuildContext context) {
    final match = facade.matchState;
    final ns = match.scores[Team.northSouth] ?? 0;
    final ew = match.scores[Team.eastWest] ?? 0;
    final round = facade.roundState;
    final bid = round?.bidState;

    String centerText = 'جولة ${match.currentRoundNumber}';
    if (bid != null && bid.isComplete && !bid.needsRedeal) {
      final suitLabel = bid.trumpSuit == null ? 'NT' : suitSymbol(bid.trumpSuit!);
      centerText = '${bid.bidValue} $suitLabel';
    }

    return Container(
      color: Colors.black38,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios,
                color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 8),
          _ScoreChip(
              label: 'ش/ج',
              score: ns,
              highlight: facade.winner == Team.northSouth),
          const Spacer(),
          Text(centerText,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          _ScoreChip(
              label: 'ش/غ',
              score: ew,
              highlight: facade.winner == Team.eastWest),
          const SizedBox(width: 8),
          Text('/${match.targetScore}',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int score;
  final bool highlight;
  const _ScoreChip(
      {required this.label, required this.score, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? Colors.amber.withValues(alpha: 0.3) : Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: highlight
            ? Border.all(color: Colors.amber, width: 1.5)
            : Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: highlight ? Colors.amber : Colors.white60,
                  fontSize: 11)),
          const SizedBox(width: 6),
          Text('$score',
              style: TextStyle(
                  color: highlight ? Colors.amber : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Table layout — 4 player positions + trick center
// ══════════════════════════════════════════════════════════════════════════════

/// Compass-direction names by absolute seat index.
const _kSeatNames = ['شمال', 'شرق', 'جنوب', 'غرب'];

String _playerDisplayName(
  int seatIndex,
  int humanIndex, [
  Map<int, String>? seatNames,
]) {
  if (seatIndex == humanIndex) return 'أنت';
  if (seatNames != null && seatNames.containsKey(seatIndex)) {
    return seatNames[seatIndex]!;
  }
  if (seatIndex == (humanIndex + 2) % 4) return 'شريكك';
  return _kSeatNames[seatIndex];
}

class _TableLayout extends StatelessWidget {
  final GameFacade facade;
  final void Function(Card) onPlayCard;
  final Map<int, String>? seatNames;

  const _TableLayout({
    required this.facade,
    required this.onPlayCard,
    this.seatNames,
  });

  @override
  Widget build(BuildContext context) {
    final h = facade.humanIndex;
    final topIdx = (h + 2) % 4;    // partner
    final leftIdx = (h + 3) % 4;   // left opponent
    final rightIdx = (h + 1) % 4;  // right opponent

    final round = facade.roundState;
    final trick = round?.currentTrick;
    final phase = facade.phase;
    final isPlaying = phase == EnginePhase.playing;

    return Column(
      children: [
        const SizedBox(height: 8),

        // ── Partner (top) ──────────────────────────────────────────────────
        _PlayerSeat(
          playerIndex: topIdx,
          displayName: _playerDisplayName(topIdx, h, seatNames),
          cardCount: round?.hands[topIdx].length ?? 0,
          tricksWon: round?.tricksWon[teamOf(topIdx)] ?? 0,
          isBidder: round?.bidState.biddingPlayerIndex == topIdx,
          isTrickWinner: trick != null &&
              trick.isComplete &&
              trick.winnerIndex == topIdx,
          position: _SeatPosition.top,
        ),

        // ── Middle row ─────────────────────────────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left opponent
              _PlayerSeat(
                playerIndex: leftIdx,
                displayName: _playerDisplayName(leftIdx, h, seatNames),
                cardCount: round?.hands[leftIdx].length ?? 0,
                tricksWon: round?.tricksWon[teamOf(leftIdx)] ?? 0,
                isBidder: round?.bidState.biddingPlayerIndex == leftIdx,
                isTrickWinner: trick != null &&
                    trick.isComplete &&
                    trick.winnerIndex == leftIdx,
                position: _SeatPosition.left,
              ),

              // Center trick area
              Expanded(
                child: _TrickArea(
                  trick: trick,
                  trickNumber: round?.trickNumber ?? 1,
                  isPlaying: isPlaying,
                  humanIndex: h,
                ),
              ),

              // Right opponent
              _PlayerSeat(
                playerIndex: rightIdx,
                displayName: _playerDisplayName(rightIdx, h, seatNames),
                cardCount: round?.hands[rightIdx].length ?? 0,
                tricksWon: round?.tricksWon[teamOf(rightIdx)] ?? 0,
                isBidder: round?.bidState.biddingPlayerIndex == rightIdx,
                isTrickWinner: trick != null &&
                    trick.isComplete &&
                    trick.winnerIndex == rightIdx,
                position: _SeatPosition.right,
              ),
            ],
          ),
        ),

        // Space reserved for the hand rendered in the Stack above
        const SizedBox(height: 116),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Player seat widget
// ══════════════════════════════════════════════════════════════════════════════

enum _SeatPosition { top, left, right }

class _PlayerSeat extends StatelessWidget {
  final int playerIndex;
  final String displayName;
  final int cardCount;
  final int tricksWon;
  final bool isBidder;
  final bool isTrickWinner;
  final _SeatPosition position;

  const _PlayerSeat({
    required this.playerIndex,
    required this.displayName,
    required this.cardCount,
    required this.tricksWon,
    required this.isBidder,
    required this.isTrickWinner,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    final isHorizontal = position == _SeatPosition.top;

    final nameWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isBidder ? Colors.amber.withValues(alpha: 0.25) : Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: isBidder
            ? Border.all(color: Colors.amber, width: 1)
            : Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(displayName,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
          if (tricksWon > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$tricksWon',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );

    final cardsWidget = _CardFan(
      count: cardCount,
      isHorizontal: isHorizontal,
      width: position == _SeatPosition.top ? 44 : 30,
      height: position == _SeatPosition.top ? 62 : 44,
    );

    if (position == _SeatPosition.top) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [nameWidget, const SizedBox(height: 4), cardsWidget],
        ),
      );
    }

    return SizedBox(
      width: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [nameWidget, const SizedBox(height: 6), cardsWidget],
      ),
    );
  }
}

class _CardFan extends StatelessWidget {
  final int count;
  final bool isHorizontal;
  final double width;
  final double height;

  const _CardFan({
    required this.count,
    required this.isHorizontal,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final visible = count.clamp(1, 5);
    const overlap = 14.0;

    if (isHorizontal) {
      return SizedBox(
        width: width + (visible - 1) * overlap,
        height: height,
        child: Stack(
          children: [
            for (int i = 0; i < visible; i++)
              Positioned(
                left: i * overlap,
                child: CardBackWidget(width: width, height: height),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height + (visible - 1) * (overlap * 0.6),
      child: Stack(
        children: [
          for (int i = 0; i < visible; i++)
            Positioned(
              top: i * (overlap * 0.6),
              child: CardBackWidget(width: width, height: height),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Center trick area
// ══════════════════════════════════════════════════════════════════════════════

class _TrickArea extends StatelessWidget {
  final TrickState? trick;
  final int trickNumber;
  final bool isPlaying;
  final int humanIndex;

  const _TrickArea({
    required this.trick,
    required this.trickNumber,
    required this.isPlaying,
    required this.humanIndex,
  });

  @override
  Widget build(BuildContext context) {
    const slotW = 54.0;
    const slotH = 76.0;
    const gap = 6.0;

    // Map absolute seat indices to display positions.
    final topIdx = (humanIndex + 2) % 4;
    final leftIdx = (humanIndex + 3) % 4;
    final rightIdx = (humanIndex + 1) % 4;
    final bottomIdx = humanIndex;

    Card? topCard, leftCard, rightCard, bottomCard;
    int? winner;

    if (trick != null) {
      winner = trick!.winnerIndex;
      for (final pc in trick!.playedCards) {
        if (pc.playerIndex == topIdx) topCard = pc.card;
        if (pc.playerIndex == leftIdx) leftCard = pc.card;
        if (pc.playerIndex == rightIdx) rightCard = pc.card;
        if (pc.playerIndex == bottomIdx) bottomCard = pc.card;
      }
    }

    Widget slot(Card? card, int playerIdx) {
      final isWinner = trick?.isComplete == true && winner == playerIdx;
      if (card == null) {
        return EmptyCardSlot(width: slotW, height: slotH);
      }
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: isWinner
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              )
            : null,
        child: PlayingCardWidget(card: card, width: slotW, height: slotH),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isPlaying)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'خدعة $trickNumber / 13',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        slot(topCard, topIdx),
        const SizedBox(height: gap),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            slot(leftCard, leftIdx),
            const SizedBox(width: gap * 2),
            slot(rightCard, rightIdx),
          ],
        ),
        const SizedBox(height: gap),
        slot(bottomCard, bottomIdx),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Human hand
// ══════════════════════════════════════════════════════════════════════════════

class _HumanHand extends StatelessWidget {
  final GameFacade facade;
  final bool isPlaying;
  final void Function(Card) onPlayCard;

  const _HumanHand({
    required this.facade,
    required this.isPlaying,
    required this.onPlayCard,
  });

  @override
  Widget build(BuildContext context) {
    final hand = facade.humanHand;
    final legal = isPlaying ? facade.legalCardsForHuman() : <Card>[];

    if (hand.isEmpty) return const SizedBox(height: 100);

    final sorted = [...hand]..sort((a, b) {
        final sc = a.suit.index.compareTo(b.suit.index);
        return sc != 0 ? sc : a.rank.value.compareTo(b.rank.value);
      });

    return Container(
      height: 108,
      decoration: const BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final card = sorted[index];
          final canPlay = legal.contains(card);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: PlayingCardWidget(
              card: card,
              enabled: isPlaying,
              highlighted: canPlay,
              onTap: canPlay ? () => onPlayCard(card) : null,
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bidding overlay
// ══════════════════════════════════════════════════════════════════════════════

class _BiddingOverlay extends ConsumerStatefulWidget {
  final GameFacade facade;
  final void Function(int, Suit?) onBid;
  final VoidCallback onPass;
  final Map<int, String>? seatNames;

  const _BiddingOverlay({
    required this.facade,
    required this.onBid,
    required this.onPass,
    this.seatNames,
  });

  @override
  ConsumerState<_BiddingOverlay> createState() => _BiddingOverlayState();
}

class _BiddingOverlayState extends ConsumerState<_BiddingOverlay> {
  int? _selectedBid;
  Suit? _selectedTrump;
  bool _trumpDecided = false;

  @override
  Widget build(BuildContext context) {
    final round = widget.facade.roundState;
    if (round == null) return const SizedBox.shrink();

    final order = biddingOrder(widget.facade.matchState.starterIndex);
    final currentBidder = order[round.bidState.turnIndex];
    final isHumanTurn = currentBidder == widget.facade.humanIndex;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20),
            ],
          ),
          child: isHumanTurn
              ? _humanBidPanel()
              : _waitingPanel(currentBidder),
        ),
      ),
    );
  }

  Widget _waitingPanel(int playerIndex) {
    final name = _playerDisplayName(
        playerIndex, widget.facade.humanIndex, widget.seatNames);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white54),
        const SizedBox(height: 12),
        Text(
          '$name يزايد...',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  Widget _humanBidPanel() {
    final hand = widget.facade.humanHand;

    // Koz count for the currently selected (non-NT) trump suit.
    final int? kozCount = (_trumpDecided && _selectedTrump != null)
        ? hand.where((c) => c.suit == _selectedTrump).length
        : null;

    // Minimum valid bid when this trump is chosen.
    final int minBidForKoz = kozCount != null ? kozCount + 3 : 7;

    // A bid value is allowed when NT is chosen, trump not yet decided,
    // or bid >= minBidForKoz.
    bool bidAllowed(int b) =>
        !_trumpDecided || _selectedTrump == null || b >= minBidForKoz;

    final selectionValid =
        _selectedBid == null || bidAllowed(_selectedBid!);
    final canBid =
        _selectedBid != null && _trumpDecided && selectionValid;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'اختر مزايدتك',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        const Text('القيمة:',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          children: [
            for (int b = 7; b <= 13; b++)
              _BidChip(
                label: '$b',
                selected: _selectedBid == b,
                enabled: bidAllowed(b),
                onTap: () {
                  if (bidAllowed(b)) setState(() => _selectedBid = b);
                },
              ),
          ],
        ),

        // Koz hint — shown once a suited trump is picked.
        if (kozCount != null && kozCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              minBidForKoz <= 13
                  ? 'لديك $kozCount كوز — الحد الأدنى للتسمية $minBidForKoz'
                  : 'لديك $kozCount كوز — لا يمكن تسمية هذا الكوز',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: minBidForKoz <= 13
                    ? Colors.white54
                    : Colors.orangeAccent,
                fontSize: 11,
              ),
            ),
          ),

        const SizedBox(height: 14),

        const Text('الأتم:',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          children: [
            for (final suit in Suit.values)
              _BidChip(
                label: suitSymbol(suit),
                color: suitColor(suit),
                selected: _trumpDecided && _selectedTrump == suit,
                onTap: () => setState(() {
                  _selectedTrump = suit;
                  _trumpDecided = true;
                  // Clear bid if it now violates the Koz rule.
                  if (_selectedBid != null) {
                    final koz =
                        hand.where((c) => c.suit == suit).length;
                    if (_selectedBid! < koz + 3) _selectedBid = null;
                  }
                }),
              ),
            _BidChip(
              label: 'NT',
              selected: _trumpDecided && _selectedTrump == null,
              onTap: () => setState(() {
                _selectedTrump = null;
                _trumpDecided = true;
              }),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: const BorderSide(color: Colors.white24),
                ),
                onPressed: widget.onPass,
                child: const Text('تمرير',
                    textDirection: TextDirection.rtl),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: canBid
                      ? const Color(0xFF2E7D32)
                      : Colors.grey.shade700,
                ),
                onPressed: canBid
                    ? () => widget.onBid(_selectedBid!, _selectedTrump)
                    : null,
                child: const Text('مزايدة',
                    textDirection: TextDirection.rtl),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BidChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final Color? color;
  final VoidCallback onTap;

  const _BidChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2E7D32)
              : (enabled ? Colors.white10 : Colors.white10.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Colors.greenAccent
                : (enabled ? Colors.white24 : Colors.white12),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (enabled ? (color ?? Colors.white70) : Colors.white24),
            fontSize: 16,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            decoration: enabled ? null : TextDecoration.lineThrough,
            decorationColor: Colors.white24,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Round summary overlay
// ══════════════════════════════════════════════════════════════════════════════

class _RoundSummaryOverlay extends StatelessWidget {
  final GameFacade facade;
  final VoidCallback onNextRound;

  const _RoundSummaryOverlay(
      {required this.facade, required this.onNextRound});

  @override
  Widget build(BuildContext context) {
    final result = facade.lastRoundResult;
    if (result == null) return const SizedBox.shrink();

    if (result.wasRedeal) {
      return _buildSheet(
        context,
        title: 'إعادة توزيع',
        rows: const [
          ('جميع اللاعبين مرروا — سيتم إعادة توزيع الأوراق', '')
        ],
        isRedeal: true,
      );
    }

    final bTeam = result.biddingTeam!;
    final oTeam = opposingTeam(bTeam);
    final bTeamName = _teamName(bTeam);
    final oTeamName = _teamName(oTeam);
    final bTricks = result.tricksWon[bTeam]!;
    final oTricks = result.tricksWon[oTeam]!;
    final success = bTricks >= result.bidValue!;
    final bDelta = result.scoreChange[bTeam]!;
    final oDelta = result.scoreChange[oTeam]!;

    final rows = <(String, String)>[
      ('المزايد', '$bTeamName — ${result.bidValue}'),
      ('خدع $bTeamName', '$bTricks'),
      ('خدع $oTeamName', '$oTricks'),
      ('نتيجة $bTeamName', success ? '+$bDelta ✓' : '$bDelta ✗'),
      if (oDelta > 0) ('نتيجة $oTeamName', '+$oDelta'),
    ];

    final match = facade.matchState;
    final nsTotal = match.scores[Team.northSouth]!;
    final ewTotal = match.scores[Team.eastWest]!;

    return _buildSheet(
      context,
      title: success ? 'نجح المزايد ✓' : 'فشل المزايد ✗',
      titleColor: success ? Colors.greenAccent : Colors.redAccent,
      rows: rows,
      footer: 'المجموع — ش/ج: $nsTotal  |  ش/غ: $ewTotal',
    );
  }

  Widget _buildSheet(
    BuildContext context, {
    required String title,
    Color titleColor = Colors.white,
    required List<(String, String)> rows,
    String? footer,
    bool isRedeal = false,
  }) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      color: titleColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  textDirection: TextDirection.rtl),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(value,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text(label,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              if (footer != null) ...[
                const Divider(color: Colors.white24),
                Text(footer,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13),
                    textDirection: TextDirection.rtl),
              ],
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32)),
                onPressed: onNextRound,
                child: Text(isRedeal ? 'توزيع جديد' : 'جولة جديدة',
                    textDirection: TextDirection.rtl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _teamName(Team team) =>
      team == Team.northSouth ? 'شمال/جنوب' : 'شرق/غرب';
}

// ══════════════════════════════════════════════════════════════════════════════
// Match end overlay
// ══════════════════════════════════════════════════════════════════════════════

class _MatchEndOverlay extends StatelessWidget {
  final GameFacade facade;
  final VoidCallback? onRestart;

  const _MatchEndOverlay({required this.facade, this.onRestart});

  @override
  Widget build(BuildContext context) {
    final winner = facade.winner;
    final match = facade.matchState;
    final winnerName =
        winner == Team.northSouth ? 'شمال / جنوب' : 'شرق / غرب';
    final isHumanWinner = winner == teamOf(facade.humanIndex);

    return Container(
      color: const Color(0xB3000000),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isHumanWinner
                  ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                  : [const Color(0xFF4A0000), const Color(0xFF7B1818)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isHumanWinner ? Colors.greenAccent : Colors.redAccent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (isHumanWinner ? Colors.green : Colors.red)
                        .withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isHumanWinner ? 'فزت! 🎉' : 'خسرت',
                style: TextStyle(
                    color: isHumanWinner
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Text(
                'فريق $winnerName فاز بالمباراة',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 16),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FinalScore(
                    label: 'شمال/جنوب',
                    score: match.scores[Team.northSouth]!,
                    isWinner: winner == Team.northSouth,
                  ),
                  const SizedBox(width: 24),
                  _FinalScore(
                    label: 'شرق/غرب',
                    score: match.scores[Team.eastWest]!,
                    isWinner: winner == Team.eastWest,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('القائمة',
                        textDirection: TextDirection.rtl),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isHumanWinner
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF7B1818),
                    ),
                    onPressed: onRestart ??
                        () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const _NewMatchStarter(),
                              ),
                            ),
                    child: const Text('لعبة جديدة',
                        textDirection: TextDirection.rtl),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinalScore extends StatelessWidget {
  final String label;
  final int score;
  final bool isWinner;

  const _FinalScore(
      {required this.label, required this.score, required this.isWinner});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$score',
            style: TextStyle(
                color: isWinner ? Colors.white : Colors.white54,
                fontSize: 32,
                fontWeight: FontWeight.bold)),
        Text(label,
            textDirection: TextDirection.rtl,
            style: TextStyle(
                color: isWinner ? Colors.white70 : Colors.white38,
                fontSize: 12)),
      ],
    );
  }
}

/// Starts a new single-player match and replaces itself with GameTableScreen.
class _NewMatchStarter extends ConsumerWidget {
  const _NewMatchStarter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameNotifierProvider.notifier).startSinglePlayer();
    });
    return const GameTableScreen();
  }
}
