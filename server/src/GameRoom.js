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
    if (idx !== -1) {
      this.seats[idx] = null;
    }
    return idx;
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
    }));
  }

  // Send to every connected seat, optionally skipping one ws.
  broadcast(msg, excludeWs = null) {
    const data = JSON.stringify(msg);
    for (const seat of this.seats) {
      if (seat && seat.ws !== excludeWs && seat.ws.readyState === WebSocket.OPEN) {
        seat.ws.send(data);
      }
    }
  }

  // Send to a specific seat index.
  sendToSeat(seatIndex, msg) {
    const seat = this.seats[seatIndex];
    if (seat && seat.ws.readyState === WebSocket.OPEN) {
      seat.ws.send(JSON.stringify(msg));
    }
  }
}

module.exports = { GameRoom };
