const { GameRoom } = require('./GameRoom');

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no confusable chars

class RoomManager {
  constructor() {
    // Map<code, GameRoom>
    this.rooms = new Map();
  }

  _generateCode() {
    let code;
    do {
      code = Array.from({ length: 4 }, () =>
        CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)]
      ).join('');
    } while (this.rooms.has(code));
    return code;
  }

  createRoom() {
    const code = this._generateCode();
    const room = new GameRoom(code);
    this.rooms.set(code, room);
    return room;
  }

  getRoom(code) {
    return this.rooms.get(code.toUpperCase().trim()) ?? null;
  }

  // Remove rooms where all seats are empty.
  pruneEmpty() {
    for (const [code, room] of this.rooms) {
      if (room.isEmpty) this.rooms.delete(code);
    }
  }

  get roomCount() {
    return this.rooms.size;
  }
}

module.exports = { RoomManager };
