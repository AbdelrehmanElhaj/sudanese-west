const WebSocket = require('ws');

class GameRoom {
  constructor(code) {
    this.code = code;
    // seats[i] = { ws, name } or null
    this.seats = [null, null, null, null];
    this.lastState = null; // most recent game state snapshot from host
  }

  // Returns the seat index assigned, or null if room is full.
  addPlayer(ws, name) {
    const idx = this.seats.findIndex((s) => s === null);
    if (idx === -1) return null;
    this.seats[idx] = { ws, name };
    return idx;
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
