import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_provider.dart';
import '../../data/multiplayer_provider.dart';
import 'game_table_screen.dart';
import 'lobby_screen.dart';
import 'waiting_room_screen.dart';

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  static void _openGameTable(BuildContext context, MultiplayerState state) {
    final seatNames = Map<int, String>.fromEntries(
      state.seats
          .where((s) => s.playerName != null)
          .map((s) => MapEntry(s.index, s.playerName!)),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameTableScreen(
          multiplayerMode: state.role == MultiplayerRole.guest,
          seatNames: seatNames,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A guest may have backed out to the menu while the host started the
    // match — jump them straight into the game table when that happens.
    ref.listen<MultiplayerState>(multiplayerProvider, (prev, next) {
      if (!context.mounted) return;
      if (next.role == MultiplayerRole.guest &&
          next.lobbyPhase == LobbyPhase.inGame &&
          prev?.lobbyPhase != LobbyPhase.inGame) {
        _openGameTable(context, next);
      }
    });

    final mpState = ref.watch(multiplayerProvider);
    final hasActiveRoom = mpState.roomCode != null &&
        (mpState.lobbyPhase == LobbyPhase.waitingRoom ||
            mpState.lobbyPhase == LobbyPhase.inGame);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A2E0A), Color(0xFF1B5E20), Color(0xFF0D3D0D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo / Title ──────────────────────────────────────────────
              Column(
                children: [
                  // Card suits decoration
                  const Text(
                    '♠  ♥  ♦  ♣',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 28, letterSpacing: 12),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ويست',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(2, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'السوداني',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 60,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // ── Menu buttons ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasActiveRoom) ...[
                      _RejoinRoomBanner(
                        roomCode: mpState.roomCode!,
                        onPressed: () {
                          if (mpState.lobbyPhase == LobbyPhase.inGame) {
                            _openGameTable(context, mpState);
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const WaitingRoomScreen(),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    _MenuButton(
                      icon: Icons.person,
                      label: 'لعب فردي',
                      subtitle: 'أنت ضد ثلاثة بوتات',
                      onPressed: () {
                        ref
                            .read(gameNotifierProvider.notifier)
                            .startSinglePlayer();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GameTableScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _MenuButton(
                      icon: Icons.group,
                      label: 'متعدد اللاعبين',
                      subtitle: '٤ لاعبين — شبكة محلية',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LobbyScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MenuButton(
                      icon: Icons.bar_chart,
                      label: 'الإحصائيات',
                      subtitle: 'سجل المباريات — قريباً',
                      onPressed: null,
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // ── Footer ─────────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Khatwa Tech • v0.1.0',
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RejoinRoomBanner extends StatelessWidget {
  final String roomCode;
  final VoidCallback onPressed;

  const _RejoinRoomBanner({required this.roomCode, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9A825),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.replay_circle_filled,
                  color: Colors.black87, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'لديك غرفة نشطة — العودة إليها',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'الرمز: $roomCode',
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onPressed;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: enabled ? const Color(0xFF2E7D32) : Colors.white10,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        label,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_back_ios,
                    color: Colors.white38, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
