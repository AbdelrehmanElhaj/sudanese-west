class ServerConfig {
  // Production: wss://swgame.hdrelhaj.com/ws
  // Local dev:  --dart-define=WS_URL=ws://localhost:8080
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://swgame.hdrelhaj.com/ws',
  );
}
