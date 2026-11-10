import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/draft.dart';

void main() {
  const order = ['A', 'B', 'C'];

  test('snake order goes 1..N then N..1', () {
    final picks = [for (var n = 0; n < 9; n++) Draft.teamForPick(order, n)];
    expect(picks, ['A', 'B', 'C', 'C', 'B', 'A', 'A', 'B', 'C']);
  });

  test('round, pick in round, and what comes next', () {
    const draft = Draft(
      leagueId: 'L',
      status: 'live',
      order: order,
      rounds: 3,
      pickNumber: 4,
      currentTeamId: 'B',
    );
    expect(draft.totalPicks, 9);
    expect(draft.round, 2);
    expect(draft.pickInRound, 2);
    expect(draft.upcoming(3), ['A', 'A', 'B']);
  });

  test('no upcoming picks past the end of the draft', () {
    const draft = Draft(leagueId: 'L', status: 'live', order: order, rounds: 1, pickNumber: 2, currentTeamId: 'C');
    expect(draft.upcoming(5), isEmpty);
  });
}
