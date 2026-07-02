# لعبة الويست السودانية — Sudanese West

A Flutter web/mobile implementation of the classic Sudanese West card game, supporting single-player (vs. bots) and multiplayer modes.

---

## Game Rules

### Overview
West is a trick-taking card game for 4 players in two partnerships:
- **North / South** (شمال / جنوب)
- **East / West** (شرق / غرب)

Each round, 13 tricks are played. The winning team is the first to reach the target score (default: 25 points).

### Bidding
- Players bid clockwise starting from the dealer.
- A bid declares how many tricks the bidding team will take (minimum 7, maximum 13), and optionally names a trump suit.
- If all four players pass, the cards are redealt.

#### Koz Rule (قاعدة الكوز)
When naming a trump suit, the number of cards the player holds in that suit must not exceed `bidValue − 3`:

| Bid | Max trump cards in hand |
|-----|------------------------|
| 7   | 4                       |
| 8   | 5                       |
| 9   | 6                       |
| 10  | 7                       |
| 11  | 8                       |
| 12  | 9                       |
| 13  | 10                      |

No-trump (NT) bids are exempt from this rule.

### Play
- The bidding player leads the first trick.
- Players must follow the lead suit if possible; otherwise they may play any card.
- Trump beats all non-trump cards.
- On trick 1, if a trump suit was named, the leading player must play a trump card if they have one.

### Scoring
- **Bidding team succeeds** (wins ≥ bid tricks): scores equal to the bid value.
- **Bidding team fails**: loses the bid value from their score.
- **Opposing team**: scores 1 point per trick won (no minimum).

---

## Features

- Single-player vs. bots with heuristic AI
- Multiplayer over WebSocket (lobby + 4-seat game)
- Bidding overlay showing each player's turn
- Koz rule enforced in UI (invalid bid values disabled) and engine
- Trick area with per-seat card slots
- Round summary and match-end screens
- Score tracking across rounds

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | Flutter (Dart), Riverpod 2.x |
| Game engine | Pure Dart package (`engine_west`) |
| Multiplayer server | Node.js + `ws` WebSocket |
| Target platforms | Web (Chrome), Android, iOS |

---

## Project Structure

```
sudanese_west/          # Flutter app
  lib/
    data/               # Providers (Riverpod)
    presentation/
      screens/          # GameTableScreen, lobby screens
      widgets/          # PlayingCardWidget, etc.
  packages/
    engine_west/        # Game engine (pure Dart)
      src/
        bot/            # BotPlayer heuristics
        engine/         # WestEngine, BidEngine, PlayEngine, ScoreEngine
        models/         # Card, Suit, TrickState, RoundState, …

server/                 # Node.js WebSocket multiplayer server
```

---

## Running Locally

### Flutter app (web)
```bash
cd sudanese_west
flutter run -d chrome
```

### Multiplayer server
```bash
cd server
npm install
node index.js
```

---

## Engine Package

The `engine_west` package is framework-agnostic and can be used independently:

```dart
final engine = WestEngine(humanIndex: 0);
engine.onStateChanged = () { /* rebuild UI */ };
engine.startMatch();

// Human bid
engine.humanBid(8, Suit.hearts);

// Human plays a card
engine.humanPlay(card);
```
