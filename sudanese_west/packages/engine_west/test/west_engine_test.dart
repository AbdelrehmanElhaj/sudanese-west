import 'dart:async';
import 'dart:math';

import 'package:engine_west/engine_west.dart';
import 'package:test/test.dart';

void main() {
  group('WestEngine bot substitution (multiplayer)', () {
    test('setSeatBotControlled is a no-op outside multiplayer mode', () {
      final engine = WestEngine(humanIndex: 0, rng: Random(1));
      engine.startMatch();
      engine.setSeatBotControlled(1, true);
      expect(engine.botControlledSeats, isEmpty);
    });

    test('botControlledSeats reflects current bot-controlled seats', () {
      // Short but comfortably above the bot-seat decision delay (350ms) so
      // this doesn't leave a real ~20s Timer dangling past test teardown.
      final engine = WestEngine(
        humanIndex: 0,
        multiplayerMode: true,
        rng: Random(1),
        turnTimeout: const Duration(milliseconds: 600),
      );
      engine.startMatch(gameMode: GameMode.onlineMultiplayer);

      expect(engine.botControlledSeats, isEmpty);
      engine.setSeatBotControlled(2, true);
      expect(engine.botControlledSeats, {2});
      engine.setSeatBotControlled(2, false);
      expect(engine.botControlledSeats, isEmpty);
    });

    test('a bot-controlled seat bids on its own without external input',
        () async {
      final engine = WestEngine(
        humanIndex: 0,
        multiplayerMode: true,
        rng: Random(1),
        turnTimeout: const Duration(milliseconds: 600),
      );
      engine.startMatch(gameMode: GameMode.onlineMultiplayer);

      final seat = engine.currentBidderIndex;
      engine.setSeatBotControlled(seat, true);

      // Bot bid decisions run after a short (350ms) internal delay — well
      // under the configured turn timeout, so this exercises the immediate
      // bot-seat path, not the timeout-escalation path.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final movedOn = engine.currentBidderIndex != seat ||
          engine.phase == EnginePhase.playing;
      expect(movedOn, isTrue,
          reason: 'bidding should have advanced past the bot-controlled seat');
    });

    test(
        'a single missed turn auto-plays once without escalating to bot '
        'control', () async {
      final engine = WestEngine(
        humanIndex: 0,
        multiplayerMode: true,
        rng: Random(1),
        turnTimeout: const Duration(milliseconds: 150),
      );
      engine.startMatch(gameMode: GameMode.onlineMultiplayer);

      final seat = engine.currentBidderIndex;
      // Nobody acts for this seat — let its turn timeout fire once.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // A lone missed turn is a stand-in for a merely slow player, not a
      // permanent bot handover.
      expect(engine.botControlledSeats, isNot(contains(seat)));
      final movedOn = engine.currentBidderIndex != seat ||
          engine.phase == EnginePhase.playing;
      expect(movedOn, isTrue,
          reason: 'the timed-out turn should have been auto-played once');
    });
  });
}
