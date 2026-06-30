// Shared message-type constants for client↔server communication.
const MSG = {
  // Client → Server
  CREATE_ROOM: 'CREATE_ROOM',
  JOIN_ROOM: 'JOIN_ROOM',
  REJOIN_ROOM: 'REJOIN_ROOM',                   // reconnecting player reclaims seat
  GAME_STATE_BROADCAST: 'GAME_STATE_BROADCAST', // host → server → all guests
  GAME_ACTION: 'GAME_ACTION',                   // guest → server → host
  PING: 'PING',

  // Server → Client
  ROOM_CREATED: 'ROOM_CREATED',
  ROOM_JOINED: 'ROOM_JOINED',
  ROOM_REJOINED: 'ROOM_REJOINED',               // server confirms seat reclaim
  SEAT_UPDATE: 'SEAT_UPDATE',
  GAME_STATE: 'GAME_STATE',                     // server → guest (relayed from host)
  ACTION_RELAY: 'ACTION_RELAY',                 // server → host (relayed from guest)
  HOST_DISCONNECTED: 'HOST_DISCONNECTED',       // server → guests when host leaves mid-game
  ERROR: 'ERROR',
  PONG: 'PONG',
};

module.exports = { MSG };
