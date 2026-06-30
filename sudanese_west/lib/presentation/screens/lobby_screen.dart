import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/multiplayer_provider.dart';
import 'waiting_room_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _nameCtrl = TextEditingController(text: '');
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MultiplayerState>(multiplayerProvider, (prev, next) {
      if (!mounted) return;

      // Navigate to waiting room when server confirms room creation/join.
      if (next.lobbyPhase == LobbyPhase.waitingRoom) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WaitingRoomScreen()),
        );
      }

      // Show server errors as a snackbar.
      if (next.lobbyPhase == LobbyPhase.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!,
                textDirection: TextDirection.rtl),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });

    final mpState = ref.watch(multiplayerProvider);
    final isLoading = mpState.lobbyPhase == LobbyPhase.connecting;

    return Scaffold(
      backgroundColor: const Color(0xFF0A2E0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'متعدد اللاعبين',
          textDirection: TextDirection.rtl,
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // ── Player name ────────────────────────────────────────────────
            _SectionTitle(title: 'اسمك'),
            const SizedBox(height: 10),
            _TextField(
              controller: _nameCtrl,
              hint: 'أدخل اسمك (اختياري)',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 32),

            // ── Create room ────────────────────────────────────────────────
            _SectionTitle(title: 'إنشاء غرفة جديدة'),
            const SizedBox(height: 10),
            const Text(
              'أنشئ غرفة وشارك الرمز مع أصدقائك (٣ لاعبين آخرين)',
              textDirection: TextDirection.rtl,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _ActionButton(
              label: 'إنشاء غرفة',
              icon: Icons.add_circle_outline,
              color: const Color(0xFF2E7D32),
              loading: isLoading,
              onPressed: () => ref.read(multiplayerProvider.notifier).createRoom(
                    _nameCtrl.text.trim(),
                  ),
            ),
            const SizedBox(height: 36),

            // ── Join room ──────────────────────────────────────────────────
            _SectionTitle(title: 'الانضمام إلى غرفة'),
            const SizedBox(height: 10),
            _TextField(
              controller: _codeCtrl,
              hint: 'أدخل رمز الغرفة (٤ أحرف)',
              icon: Icons.login,
              textCapitalization: TextCapitalization.characters,
              maxLength: 4,
            ),
            const SizedBox(height: 12),
            _ActionButton(
              label: 'انضمام',
              icon: Icons.group_add,
              color: const Color(0xFF1565C0),
              loading: isLoading,
              onPressed: () {
                final code = _codeCtrl.text.trim();
                if (code.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('الرمز يجب أن يكون ٤ أحرف',
                          textDirection: TextDirection.rtl),
                    ),
                  );
                  return;
                }
                ref.read(multiplayerProvider.notifier).joinRoom(
                      code,
                      _nameCtrl.text.trim(),
                    );
              },
            ),

            const SizedBox(height: 48),

            // ── Connection note ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'يتطلب تشغيل خادم اللعبة على الشبكة المحلية.\n'
                'يمكن تغيير عنوان الخادم في server_config.dart',
                textDirection: TextDirection.rtl,
                style: TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textDirection: TextDirection.rtl,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextCapitalization textCapitalization;
  final int? maxLength;

  const _TextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.textCapitalization = TextCapitalization.words,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textDirection: TextDirection.rtl,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white54),
        counterStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white70),
              )
            : Icon(icon),
        label: Text(label,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
