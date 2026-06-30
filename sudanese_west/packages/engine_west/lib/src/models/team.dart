// Players: North=0, East=1, South=2, West=3
// Teams:   northSouth = [0,2], eastWest = [1,3]
enum Team { northSouth, eastWest }

Team teamOf(int playerIndex) =>
    playerIndex % 2 == 0 ? Team.northSouth : Team.eastWest;

int partnerOf(int playerIndex) => (playerIndex + 2) % 4;

List<int> playersOf(Team team) =>
    team == Team.northSouth ? [0, 2] : [1, 3];

Team opposingTeam(Team team) =>
    team == Team.northSouth ? Team.eastWest : Team.northSouth;
