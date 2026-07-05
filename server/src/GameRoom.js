const WebSocket = require('ws');
const crypto = require('crypto');

class GameRoom {
  constructor(code) {
    this.code = code;
    // seats[i] = { ws, name, token } or null
    this.seats = [null, null, null, null];
    // seatTokens[i] holds the token of the seat's current or most recent
    // occupant, so a disconnected player can prove they own that seat when
    // sending REJOIN_ROOM — without it, anyone who knows the room code could
    // claim an empty seat (including seat 0, the authoritative host).
    this.seatTokens = [null, null, null, null];
    this.lastState = null; // most recent game state snapshot from host
  }

  // Returns { seatIndex, token }, or null if room is full.
  addPlayer(ws, name) {
    const idx = this.seats.findIndex((s) => s === null);
    if (idx === -1) return null;
    const token = crypto.randomUUID();
    this.seats[idx] = { ws, name, token };
    this.seatTokens[idx] = token;
    return { seatIndex: idx, token };
  }

  // Returns the seat index of the removed player, or -1 if not found.
  // Caller is responsible for broadcasting SEAT_UPDATE after removing.
  removePlayer(ws) {
    const idx = this.seats.findIndex((s) => s?.ws === ws);
    if (idx === -1) return -1;
    if (this.lastState != null && idx !== 0) {
      // Mid-match guest disconnect: reserve the seat (ws: null) instead of
      // freeing it outright, so a stranger can't steal it via JOIN_ROOM
      // before the original owner reconnects — only their seatToken can
      // reclaim it via REJOIN_ROOM. Pre-game leaves and host disconnects
      // still fully free the seat, matching existing behavior.
      this.seats[idx] = {
        ws: null,
        name: this.seats[idx].name,
        token: this.seats[idx].token,
      };
    } else {
      this.seats[idx] = null;
    }
    return idx;
  }

  // Fully frees every seat. Used when the host leaves mid-match: the match
  // can't continue, and reserved guest seats would otherwise block the room
  // from ever being pruned by RoomManager.pruneEmpty().
  clearAllSeats() {
    this.seats = [null, null, null, null];
  }

  get isEmpty() {
    return this.seats.every((s) => s === null);
  }

  get isFull() {
    return this.seats.every((s) => s !== null);
  }

  get hostWs() {
    return this.seats[0]?.ws ?? null;
  }

  seatInfo() {
    return this.seats.map((s, i) => ({
      seatIndex: i,
      playerName: s?.name ?? null,
      connected: s?.ws != null,
    }));
  }

  // Send to every connected seat, optionally skipping one ws. Reserved seats
  // (disconnected mid-match, ws: null) are silently skipped.
  broadcast(msg, excludeWs = null) {
    const data = JSON.stringify(msg);
    for (const seat of this.seats) {
      if (seat?.ws && seat.ws !== excludeWs && seat.ws.readyState === WebSocket.OPEN) {
        seat.ws.send(data);
      }
    }
  }

  // Send to a specific seat index.
  sendToSeat(seatIndex, msg) {
    const seat = this.seats[seatIndex];
    if (seat?.ws && seat.ws.readyState === WebSocket.OPEN) {
      seat.ws.send(JSON.stringify(msg));
    }
  }
}

module.exports = { GameRoom };
