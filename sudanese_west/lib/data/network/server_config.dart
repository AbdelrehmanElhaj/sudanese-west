class ServerConfig {
  // Android emulator → host machine: 10.0.2.2
  // Physical device → use your LAN IP e.g. 192.168.1.x
  // Override at build time: --dart-define=WS_URL=ws://192.168.1.50:8080
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://10.0.2.2:8080',
  );
}
