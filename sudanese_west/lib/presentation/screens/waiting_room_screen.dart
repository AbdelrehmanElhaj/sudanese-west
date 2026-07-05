import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/multiplayer_provider.dart';
import 'game_table_screen.dart';

class WaitingRoomScreen extends ConsumerWidget {
  const WaitingRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<MultiplayerState>(multiplayerProvider, (prev, next) {
      if (!context.mounted) return;

      // Navigate guests to game table when host starts the match.
      if (next.lobbyPhase == LobbyPhase.inGame &&
          next.role == MultiplayerRole.guest) {
        final seatNames = Map<int, String>.fromEntries(
          next.seats
              .where((s) => s.playerName != null)
              .map((s) => MapEntry(s.index, s.playerName!)),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameTableScreen(
              multiplayerMode: true,
              seatNames: seatNames,
            ),
          ),
        );
        return;
      }

      // Surface connection errors (server unreachable, host left, etc.)
      // instead of leaving the player stuck on a waiting room that will
      // never progress.
      if (next.lobbyPhase == LobbyPhase.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(next.errorMessage!, textDirection: TextDirection.rtl),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });

    final state = ref.watch(multiplayerProvider);
    final isHost = state.role == MultiplayerRole.host;

    return Scaffold(
      backgroundColor: const Color(0xFF0A2E0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          // Just leaves the screen — the room and connection stay alive so
          // the player can rejoin from the main menu instead of losing it.
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'غرفة الانتظار',
          textDirection: TextDirection.rtl,
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Room code ──────────────────────────────────────────────────
            if (state.roomCode != null) ...[
              const Text(
                'رمز الغرفة',
                textDirection: TextDirection.rtl,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: state.roomCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ الرمز',
                          textDirection: TextDirection.rtl),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.roomCode!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 10,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.copy,
                          color: Colors.white38, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'اضغط للنسخ وشارك الرمز مع أصدقائك',
                textDirection: TextDirection.rtl,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 32),
            ],

            // ── Seat slots ─────────────────────────────────────────────────
            const Text(
              'اللاعبون',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),

            ...List.generate(4, (i) {
              final seat = state.seats.length > i ? state.seats[i] : null;
              final isMySeat = i == state.seatIndex;
              final isFilled = seat?.playerName != null;
              return _SeatTile(
                seatIndex: i,
                playerName: seat?.playerName,
                isMySeat: isMySeat,
                isFilled: isFilled,
              );
            }),

            const Spacer(),

            // ── Status / Start button ──────────────────────────────────────
            if (isHost) ...[
              _HostStartArea(state: state),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white38),
                    SizedBox(width: 14),
                    Text(
                      'في انتظار المضيف لبدء اللعبة...',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.read(multiplayerProvider.notifier).disconnect();
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text(
                'مغادرة الغرفة',
                textDirection: TextDirection.rtl,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

}

class _SeatTile extends StatelessWidget {
  final int seatIndex;
  final String? playerName;
  final bool isMySeat;
  final bool isFilled;

  const _SeatTile({
    required this.seatIndex,
    required this.playerName,
    required this.isMySeat,
    required this.isFilled,
  });

  static const _seatNames = ['شمال ↑', 'شرق →', 'جنوب ↓', 'غرب ←'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMySeat
            ? Colors.white12
            : (isFilled ? Colors.white.withValues(alpha: 0.05) : Colors.black26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMySeat
              ? Colors.greenAccent.withValues(alpha: 0.5)
              : (isFilled ? Colors.white24 : Colors.white12),
        ),
      ),
      child: Row(
        children: [
          // Seat indicator dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? Colors.greenAccent : Colors.white24,
            ),
          ),
          const SizedBox(width: 12),

          // Player name / waiting label
          Expanded(
            child: Text(
              isFilled ? (playerName ?? 'لاعب') : 'في انتظار اللاعب...',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: isFilled ? Colors.white : Colors.white38,
                fontSize: 15,
                fontStyle:
                    isFilled ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),

          // Position label
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _seatNames[seatIndex],
              style:
                  const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),

          if (isMySeat) ...[
            const SizedBox(width: 8),
            const Text('(أنت)',
                style:
                    TextStyle(color: Colors.greenAccent, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _HostStartArea extends ConsumerWidget {
  final MultiplayerState state;
  const _HostStartArea({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canStart = state.filledSeatCount >= 2; // allow 2+ for testing

    return Column(
      children: [
        Text(
          '${state.filledSeatCount} / 4 لاعبين جاهزون',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: canStart ? Colors.greenAccent : Colors.white54,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor:
                  canStart ? const Color(0xFF2E7D32) : Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: canStart
                ? () {
                    ref.read(multiplayerProvider.notifier).startHostGame();
                    final seatNames = Map<int, String>.fromEntries(
                      state.seats
                          .where((s) => s.playerName != null)
                          .map((s) => MapEntry(s.index, s.playerName!)),
                    );
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => GameTableScreen(
                          multiplayerMode: false,
                          seatNames: seatNames,
                        ),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text(
              'بدء اللعبة',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        if (!canStart) ...[
          const SizedBox(height: 8),
          const Text(
            'يجب أن يكون هناك لاعبان على الأقل',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ],
    );
  }
}
