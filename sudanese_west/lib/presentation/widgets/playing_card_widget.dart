import 'package:engine_west/engine_west.dart';
import 'package:flutter/material.dart' hide Card;

// ── Helpers ────────────────────────────────────────────────────────────────

String rankLabel(Rank rank) {
  if (rank == Rank.ace) return 'A';
  if (rank == Rank.king) return 'K';
  if (rank == Rank.queen) return 'Q';
  if (rank == Rank.jack) return 'J';
  return rank.value.toString();
}

String suitSymbol(Suit suit) {
  if (suit == Suit.spades) return '♠';
  if (suit == Suit.hearts) return '♥';
  if (suit == Suit.diamonds) return '♦';
  return '♣';
}

Color suitColor(Suit suit) =>
    (suit == Suit.hearts || suit == Suit.diamonds) ? Colors.red : Colors.black87;

// ── PlayingCardWidget ───────────────────────────────────────────────────────

class PlayingCardWidget extends StatelessWidget {
  final Card card;
  final bool enabled;
  final bool highlighted; // legal to play
  final VoidCallback? onTap;
  final double width;
  final double height;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.enabled = true,
    this.highlighted = false,
    this.onTap,
    this.width = 54,
    this.height = 76,
  });

  @override
  Widget build(BuildContext context) {
    final color = suitColor(card.suit);
    final symbol = suitSymbol(card.suit);
    final label = rankLabel(card.rank);

    return GestureDetector(
      onTap: (enabled && onTap != null) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: width,
        height: height,
        transform: highlighted
            ? Matrix4.translationValues(0, -8, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: highlighted
                ? const Color(0xFF4CAF50)
                : Colors.grey.shade300,
            width: highlighted ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: highlighted
                  ? Colors.green.withValues(alpha: 0.4)
                  : Colors.black26,
              blurRadius: highlighted ? 8 : 3,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Stack(
              children: [
                // Top-left corner
                Positioned(
                  top: 0,
                  left: 2,
                  child: _CornerLabel(label: label, symbol: symbol, color: color),
                ),
                // Center suit
                Center(
                  child: Text(
                    symbol,
                    style: TextStyle(
                      color: color,
                      fontSize: height * 0.3,
                      height: 1,
                    ),
                  ),
                ),
                // Bottom-right corner (rotated)
                Positioned(
                  bottom: 0,
                  right: 2,
                  child: Transform.rotate(
                    angle: 3.14159,
                    child: _CornerLabel(
                        label: label, symbol: symbol, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerLabel extends StatelessWidget {
  final String label;
  final String symbol;
  final Color color;

  const _CornerLabel(
      {required this.label, required this.symbol, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.1)),
        Text(symbol,
            style: TextStyle(color: color, fontSize: 10, height: 1.1)),
      ],
    );
  }
}

// ── CardBackWidget ──────────────────────────────────────────────────────────

class CardBackWidget extends StatelessWidget {
  final double width;
  final double height;

  const CardBackWidget({super.key, this.width = 40, this.height = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24, width: 1),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
        ],
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white38, width: 1),
          ),
          child: const Center(
            child: Text(
              'W',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

// ── EmptyCardSlot ───────────────────────────────────────────────────────────

class EmptyCardSlot extends StatelessWidget {
  final double width;
  final double height;

  const EmptyCardSlot({super.key, this.width = 54, this.height = 76});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
    );
  }
}
