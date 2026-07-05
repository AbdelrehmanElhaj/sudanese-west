import 'dart:async';

import 'package:engine_west/engine_west.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_provider.dart';
import 'network/game_serializer.dart';
import 'network/remote_game_facade.dart';
import 'network/server_config.dart';
import 'network/ws_client.dart';
import 'network/ws_protocol.dart';

// ── Domain types ──────────────────────────────────────────────────────────────

enum MultiplayerRole { none, host, guest }

enum LobbyPhase { idle, connecting, waitingRoom, inGame, error }

@immutable
class SeatInfo {
  final int index;
  final String? playerName;
  const SeatInfo(this.index, this.playerName);
}

@immutable
class MultiplayerState {
  final MultiplayerRole role;
  final LobbyPhase lobbyPhase;
  final String? roomCode;
  final int seatIndex; // -1 = not yet assigned
  final List<SeatInfo> seats;
  final String? errorMessage;
  final RemoteSnapshot? gameSnapshot; // non-null when guest is in-game

  static const initial = MultiplayerState(
    role: MultiplayerRole.none,
    lobbyPhase: LobbyPhase.idle,
    roomCode: null,
    seatIndex: -1,
    seats: [
      SeatInfo(0, null),
      SeatInfo(1, null),
      SeatInfo(2, null),
      SeatInfo(3, null),
    ],
    errorMessage: null,
    gameSnapshot: null,
  );

  const MultiplayerState({
    required this.role,
    required this.lobbyPhase,
    required this.roomCode,
    required this.seatIndex,
    required this.seats,
    required this.errorMessage,
    required this.gameSnapshot,
  });

  MultiplayerState copyWith({
    MultiplayerRole? role,
    LobbyPhase? lobbyPhase,
    String? roomCode,
    int? seatIndex,
    List<SeatInfo>? seats,
    String? errorMessage,
    RemoteSnapshot? gameSnapshot,
    bool clearError = false,
    bool clearSnapshot = false,
  }) {
    return MultiplayerState(
      role: role ?? this.role,
      lobbyPhase: lobbyPhase ?? this.lobbyPhase,
      roomCode: roomCode ?? this.roomCode,
      seatIndex: seatIndex ?? this.seatIndex,
      seats: seats ?? this.seats,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      gameSnapshot: clearSnapshot ? null : (gameSnapshot ?? this.gameSnapshot),
    );
  }

  int get filledSeatCount => seats.where((s) => s.playerName != null).length;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class MultiplayerNotifier extends Notifier<MultiplayerState> {
  final _ws = WsClient();
  StreamSubscription<Map<String, dynamic>>? _sub;
  String? _playerName; // stored for reconnection
  String? _seatToken; // proves ownership of our seat when sending REJOIN_ROOM

  @override
  MultiplayerState build() {
    // When host: broadcast state after every engine tick.
    ref.listen<int>(gameNotifierProvider, (_, _) {
      if (state.role == MultiplayerRole.host &&
          state.lobbyPhase == LobbyPhase.inGame) {
        _broadcastGameState();
      }
    });

    // Re-authenticate after an automatic reconnection.
    _ws.onReconnected = () {
      final code = state.roomCode;
      if (code != null &&
          state.seatIndex >= 0 &&
          _playerName != null &&
          _seatToken != null) {
        _ws.send({
          'type': WsProtocol.rejoinRoom,
          'roomCode': code,
          'seatIndex': state.seatIndex,
          'playerName': _playerName,
          'token': _seatToken,
        });
      }
      // If the host's connection dropped right as the match started, the
      // initial GAME_STATE_BROADCAST is silently lost (_ws wasn't connected
      // yet). Re-send it so guests aren't stuck waiting forever.
      if (state.role == MultiplayerRole.host &&
          state.lobbyPhase == LobbyPhase.inGame) {
        _broadcastGameState();
      }
    };

    ref.onDispose(() {
      _sub?.cancel();
      _ws.disconnect();
    });

    return MultiplayerState.initial;
  }

  // ── Read-only access for UI ───────────────────────────────────────────────

  /// Returns the appropriate GameFacade for the current role.
  /// Host → local WestEngine; Guest → RemoteGameFacade from snapshot.
  GameFacade? get facade {
    if (state.role == MultiplayerRole.host) {
      return ref.read(gameNotifierProvider.notifier).engine;
    }
    if (state.role == MultiplayerRole.guest &&
        state.gameSnapshot != null) {
      return RemoteGameFacade(state.gameSnapshot!, state.seatIndex);
    }
    return null;
  }

  // ── Connection ────────────────────────────────────────────────────────────

  Future<void> _ensureConnected() async {
    if (_ws.isConnected) return;
    state = state.copyWith(lobbyPhase: LobbyPhase.connecting, clearError: true);
    try {
      await _ws.connect(ServerConfig.wsUrl);
      _sub = _ws.messages.listen(
        _onMessage,
        onError: (_) => state = state.copyWith(
          lobbyPhase: LobbyPhase.error,
          errorMessage: 'انقطع الاتصال بالخادم',
        ),
      );
    } catch (_) {
      state = state.copyWith(
        lobbyPhase: LobbyPhase.error,
        errorMessage: 'تعذّر الاتصال بالخادم — تأكد من تشغيله',
      );
    }
  }

  Future<void> createRoom(String playerName) async {
    _playerName = playerName.isEmpty ? 'لاعب' : playerName;
    await _ensureConnected();
    if (state.lobbyPhase == LobbyPhase.error) return;
    _ws.send({
      'type': WsProtocol.createRoom,
      'playerName': _playerName,
    });
  }

  Future<void> joinRoom(String roomCode, String playerName) async {
    _playerName = playerName.isEmpty ? 'لاعب' : playerName;
    await _ensureConnected();
    if (state.lobbyPhase == LobbyPhase.error) return;
    _ws.send({
      'type': WsProtocol.joinRoom,
      'roomCode': roomCode.trim().toUpperCase(),
      'playerName': _playerName,
    });
  }

  // ── Game lifecycle ────────────────────────────────────────────────────────

  /// Host-only: start the match. Navigating to the game table is the caller's
  /// responsibility.
  void startHostGame() {
    ref.read(gameNotifierProvider.notifier).startMultiplayerHost();
    state = state.copyWith(lobbyPhase: LobbyPhase.inGame);
    // Immediately push initial state to guests.
    _broadcastGameState();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void sendBid(int bidValue, Suit? trumpSuit) {
    if (state.role == MultiplayerRole.host) {
      ref.read(gameNotifierProvider.notifier).bid(bidValue, trumpSuit);
    } else {
      _ws.send({
        'type': WsProtocol.gameAction,
        'action': {
          'type': WsProtocol.actionBid,
          'bidValue': bidValue,
          'trumpSuit': GameSerializer.encodeSuit(trumpSuit),
        },
      });
    }
  }

  void sendPass() {
    if (state.role == MultiplayerRole.host) {
      ref.read(gameNotifierProvider.notifier).pass();
    } else {
      _ws.send({
        'type': WsProtocol.gameAction,
        'action': {'type': WsProtocol.actionPass},
      });
    }
  }

  void sendPlay(Card card) {
    if (state.role == MultiplayerRole.host) {
      ref.read(gameNotifierProvider.notifier).playCard(card);
    } else {
      _ws.send({
        'type': WsProtocol.gameAction,
        'action': {
          'type': WsProtocol.actionPlayCard,
          'card': GameSerializer.encodeCard(card),
        },
      });
    }
  }

  void sendNextRound() {
    if (state.role == MultiplayerRole.host) {
      ref.read(gameNotifierProvider.notifier).nextRound();
    } else {
      _ws.send({
        'type': WsProtocol.gameAction,
        'action': {'type': WsProtocol.actionNextRound},
      });
    }
  }

  void disconnect() {
    _sub?.cancel();
    _sub = null;
    _ws.disconnect();
    _seatToken = null;
    state = MultiplayerState.initial;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _onMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String;

    if (type == WsProtocol.roomCreated) {
      _seatToken = msg['token'] as String?;
      state = state.copyWith(
        role: MultiplayerRole.host,
        roomCode: msg['roomCode'] as String,
        seatIndex: msg['seatIndex'] as int,
        lobbyPhase: LobbyPhase.waitingRoom,
        clearError: true,
      );
      return;
    }

    if (type == WsProtocol.roomJoined) {
      _seatToken = msg['token'] as String?;
      state = state.copyWith(
        role: MultiplayerRole.guest,
        roomCode: msg['roomCode'] as String,
        seatIndex: msg['seatIndex'] as int,
        lobbyPhase: LobbyPhase.waitingRoom,
        clearError: true,
      );
      return;
    }

    if (type == WsProtocol.roomRejoined) {
      // Server will follow immediately with GAME_STATE if game is in progress.
      // Just update the seat index in case it changed and clear any error.
      state = state.copyWith(
        seatIndex: msg['seatIndex'] as int,
        clearError: true,
      );
      return;
    }

    if (type == WsProtocol.hostDisconnected) {
      state = state.copyWith(
        lobbyPhase: LobbyPhase.error,
        errorMessage: 'انقطع اتصال المضيف — لا يمكن متابعة اللعبة',
      );
      return;
    }

    if (type == WsProtocol.seatUpdate) {
      final seatsJson = msg['seats'] as List<dynamic>;
      final seats = seatsJson.map((s) {
        final sm = s as Map<String, dynamic>;
        return SeatInfo(
          sm['seatIndex'] as int,
          sm['playerName'] as String?,
        );
      }).toList();
      state = state.copyWith(seats: seats);
      return;
    }

    if (type == WsProtocol.gameState) {
      // Guest receives authoritative state from host.
      final snapshot = GameSerializer.deserialize(
        msg['state'] as Map<String, dynamic>,
        state.seatIndex,
      );
      state = state.copyWith(
        gameSnapshot: snapshot,
        lobbyPhase: LobbyPhase.inGame,
      );
      return;
    }

    if (type == WsProtocol.actionRelay) {
      // Host receives guest action.
      if (state.role != MultiplayerRole.host) return;
      final seatIndex = msg['seatIndex'] as int;
      final action = msg['action'] as Map<String, dynamic>;
      _applyRelayedAction(seatIndex, action);
      return;
    }

    if (type == WsProtocol.error) {
      state = state.copyWith(
        lobbyPhase: LobbyPhase.error,
        errorMessage: msg['message'] as String?,
      );
      return;
    }
  }

  void _applyRelayedAction(int seatIndex, Map<String, dynamic> action) {
    final engine = ref.read(gameNotifierProvider.notifier).engine;
    final actionType = action['type'] as String;
    try {
      if (actionType == WsProtocol.actionBid) {
        final bidValue = action['bidValue'] as int;
        final trump = GameSerializer.decodeSuit(action['trumpSuit'] as String?);
        engine.applyBidForSeat(seatIndex, bidValue, trump);
      } else if (actionType == WsProtocol.actionPass) {
        engine.applyPassForSeat(seatIndex);
      } else if (actionType == WsProtocol.actionPlayCard) {
        final card = GameSerializer.decodeCard(action['card'] as String);
        engine.applyPlayForSeat(seatIndex, card);
      } else if (actionType == WsProtocol.actionNextRound) {
        engine.proceedToNextRound();
      }
    } catch (e) {
      debugPrint('Ignored invalid relayed action from seat $seatIndex: $e');
    }
  }

  void _broadcastGameState() {
    if (!_ws.isConnected) return;
    final engine = ref.read(gameNotifierProvider.notifier).engine;
    final serialized = GameSerializer.serialize(engine);
    _ws.send({
      'type': WsProtocol.gameStateBroadcast,
      'state': serialized,
    });
  }
}

final multiplayerProvider =
    NotifierProvider<MultiplayerNotifier, MultiplayerState>(
        MultiplayerNotifier.new);
