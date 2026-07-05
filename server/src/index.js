const WebSocket = require('ws');
const { RoomManager } = require('./RoomManager');
const { MSG } = require('./Protocol');

const PORT = process.env.PORT || 8080;
const HEARTBEAT_INTERVAL_MS = 30000;
const wss = new WebSocket.Server({ port: PORT, maxPayload: 128 * 1024 });
const roomManager = new RoomManager();

// Tracks which room/seat each WebSocket belongs to.
// WeakMap so closed connections are GC'd automatically.
const wsContext = new WeakMap(); // ws → { room, seatIndex }

// ── Helpers ──────────────────────────────────────────────────────────────────

function send(ws, msg) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(msg));
  }
}

function sendError(ws, message) {
  send(ws, { type: MSG.ERROR, message });
}

// ── Message handler ───────────────────────────────────────────────────────────

function handleMessage(ws, raw) {
  let msg;
  try {
    msg = JSON.parse(raw);
  } catch {
    sendError(ws, 'Invalid JSON');
    return;
  }

  if (!msg || typeof msg !== 'object' || typeof msg.type !== 'string') {
    sendError(ws, 'Invalid message');
    return;
  }

  const type = msg.type;

  if (type === MSG.PING) {
    send(ws, { type: MSG.PONG });
    return;
  }

  if (type === MSG.CREATE_ROOM) {
    const room = roomManager.createRoom();
    const { seatIndex, token } = room.addPlayer(ws, msg.playerName || 'لاعب ١');
    wsContext.set(ws, { room, seatIndex });

    send(ws, { type: MSG.ROOM_CREATED, roomCode: room.code, seatIndex, token });
    room.broadcast({ type: MSG.SEAT_UPDATE, seats: room.seatInfo() });

    console.log(`[${room.code}] Room created by seat ${seatIndex}. Rooms: ${roomManager.roomCount}`);
    return;
  }

  if (type === MSG.JOIN_ROOM) {
    const room = roomManager.getRoom(msg.roomCode ?? '');
    if (!room) { sendError(ws, 'الغرفة غير موجودة'); return; }
    if (room.isFull) { sendError(ws, 'الغرفة ممتلئة'); return; }

    const added = room.addPlayer(ws, msg.playerName || `لاعب ${room.seats.filter(Boolean).length}`);
    if (added === null) { sendError(ws, 'لا توجد مقاعد متاحة'); return; }
    const { seatIndex, token } = added;

    wsContext.set(ws, { room, seatIndex });

    send(ws, { type: MSG.ROOM_JOINED, roomCode: room.code, seatIndex, token });
    room.broadcast({ type: MSG.SEAT_UPDATE, seats: room.seatInfo() });

    console.log(`[${room.code}] Player joined seat ${seatIndex}.`);
    return;
  }

  if (type === MSG.REJOIN_ROOM) {
    const room = roomManager.getRoom(msg.roomCode ?? '');
    if (!room) { sendError(ws, 'الغرفة غير موجودة'); return; }

    const targetSeat = typeof msg.seatIndex === 'number' ? msg.seatIndex : -1;
    if (targetSeat < 0 || targetSeat > 3) { sendError(ws, 'مقعد غير صالح'); return; }
    if (room.seats[targetSeat]?.ws != null) { sendError(ws, 'المقعد غير متاح للانضمام مجدداً'); return; }
    if (!msg.token || room.seatTokens[targetSeat] !== msg.token) {
      sendError(ws, 'غير مصرح بإعادة الانضمام لهذا المقعد');
      return;
    }

    const name = msg.playerName || 'لاعب';
    room.seats[targetSeat] = { ws, name, token: msg.token };
    wsContext.set(ws, { room, seatIndex: targetSeat });

    send(ws, { type: MSG.ROOM_REJOINED, roomCode: room.code, seatIndex: targetSeat });
    room.broadcast({ type: MSG.SEAT_UPDATE, seats: room.seatInfo() });

    // Catch the rejoining player up if a game is already in progress.
    if (room.lastState) {
      send(ws, { type: MSG.GAME_STATE, state: room.lastState });
    }

    console.log(`[${room.code}] Seat ${targetSeat} rejoined.`);
    return;
  }

  // The rest require the sender to already be in a room.
  const ctx = wsContext.get(ws);
  if (!ctx) { sendError(ws, 'Not in a room'); return; }
  const { room, seatIndex } = ctx;

  if (type === MSG.GAME_STATE_BROADCAST) {
    // Only host (seat 0) may broadcast state.
    if (seatIndex !== 0) { sendError(ws, 'Only the host may broadcast state'); return; }
    room.lastState = msg.state;
    // Relay state to all non-host seats.
    room.broadcast({ type: MSG.GAME_STATE, state: msg.state }, ws /* exclude host */);
    return;
  }

  if (type === MSG.GAME_ACTION) {
    // Non-host relays action to host.
    if (seatIndex === 0) return; // host acts locally, never sends GAME_ACTION
    const hostWs = room.hostWs;
    if (hostWs) {
      send(hostWs, { type: MSG.ACTION_RELAY, seatIndex, action: msg.action });
    } else {
      sendError(ws, 'المضيف غير متصل حالياً');
    }
    return;
  }

  sendError(ws, `Unknown message type: ${type}`);
}

// ── Connection lifecycle ──────────────────────────────────────────────────────

wss.on('connection', (ws) => {
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });

  ws.on('message', (raw) => handleMessage(ws, raw.toString()));

  ws.on('close', () => {
    const ctx = wsContext.get(ws);
    if (ctx) {
      const { room, seatIndex } = ctx;
      const wasHost = seatIndex === 0;
      const hadGame = room.lastState != null;

      room.removePlayer(ws);

      if (wasHost && hadGame) {
        // The match can't continue without the host — end it for everyone
        // and fully free the room instead of leaving guest seats reserved
        // forever (which would block pruneEmpty from ever collecting it).
        room.broadcast({ type: MSG.HOST_DISCONNECTED });
        room.clearAllSeats();
      } else {
        room.broadcast({ type: MSG.SEAT_UPDATE, seats: room.seatInfo() });
      }

      roomManager.pruneEmpty();
      console.log(`[${room.code}] Seat ${seatIndex} disconnected. Room ${room.isEmpty ? 'deleted' : 'still active'}.`);
    }
  });

  ws.on('error', (err) => {
    console.error('WS error:', err.message);
    ws.terminate();
  });
});

// Periodically ping every client; terminate ones that never pong back.
// This frees seats left behind by connections that drop without a clean
// close (app killed, network vanished) so the seat becomes rejoinable.
const heartbeatInterval = setInterval(() => {
  for (const ws of wss.clients) {
    if (ws.isAlive === false) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
}, HEARTBEAT_INTERVAL_MS);

wss.on('close', () => clearInterval(heartbeatInterval));

wss.on('listening', () => {
  console.log(`West Sudanese game server listening on ws://0.0.0.0:${PORT}`);
  console.log('Change ServerConfig.wsUrl in Flutter to your machine IP to connect from device.');
});
