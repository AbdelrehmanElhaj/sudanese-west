import 'team.dart';

class RoundResult {
  final Team? biddingTeam;
  final int? bidValue;
  final Map<Team, int> tricksWon;
  final Map<Team, int> scoreChange;
  final bool wasRedeal;
  final bool wasKabout; // one team won all 13 tricks

  const RoundResult({
    required this.biddingTeam,
    required this.bidValue,
    required this.tricksWon,
    required this.scoreChange,
    this.wasRedeal = false,
    this.wasKabout = false,
  });
}
