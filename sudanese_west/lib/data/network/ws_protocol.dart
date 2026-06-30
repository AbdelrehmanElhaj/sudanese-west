class WsProtocol {
  // Client → Server
  static const String createRoom = 'CREATE_ROOM';
  static const String joinRoom = 'JOIN_ROOM';
  static const String rejoinRoom = 'REJOIN_ROOM';
  static const String gameStateBroadcast = 'GAME_STATE_BROADCAST';
  static const String gameAction = 'GAME_ACTION';
  static const String ping = 'PING';

  // Server → Client
  static const String roomCreated = 'ROOM_CREATED';
  static const String roomJoined = 'ROOM_JOINED';
  static const String roomRejoined = 'ROOM_REJOINED';
  static const String seatUpdate = 'SEAT_UPDATE';
  static const String gameState = 'GAME_STATE';
  static const String actionRelay = 'ACTION_RELAY';
  static const String hostDisconnected = 'HOST_DISCONNECTED';
  static const String error = 'ERROR';
  static const String pong = 'PONG';

  // GAME_ACTION sub-types
  static const String actionBid = 'BID';
  static const String actionPass = 'PASS';
  static const String actionPlayCard = 'PLAY_CARD';
  static const String actionNextRound = 'NEXT_ROUND';
}
