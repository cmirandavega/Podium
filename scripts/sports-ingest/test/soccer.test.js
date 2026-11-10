// Tests the soccer parser, scoring, and week windows against a sample API response.
// No API key or network needed.
const test = require('node:test');
const assert = require('node:assert');
const { parsePlayerStats, weekWindow } = require('../adapters/soccer');
const { fantasyPoints } = require('../scoring');

const game = { gameId: '1', homeTeam: 'Arsenal', awayTeam: 'Chelsea', homeGoals: 2, awayGoals: 0 };

const line = (id, name, position, minutes, extra = {}) => ({
  player: { id, name },
  statistics: [{
    games: { minutes, position },
    goals: { total: extra.goals ?? null, assists: extra.assists ?? null, saves: extra.saves ?? null, conceded: 0 },
    cards: { yellow: extra.yellow ?? 0, red: 0 },
    penalty: { saved: null, missed: null },
  }],
});

const sample = [
  {
    team: { id: 42, name: 'Arsenal' },
    players: [
      line(1, 'Home Keeper', 'G', 90, { saves: 3 }),
      line(2, 'Home Defender', 'D', 90, { goals: 1 }),
      line(3, 'Home Forward', 'F', 70, { goals: 1, assists: 1 }),
      line(4, 'Unused Sub', 'M', null),
    ],
  },
  {
    team: { id: 49, name: 'Chelsea' },
    players: [line(5, 'Away Midfielder', 'M', 45, { yellow: 1 })],
  },
];

test('skips players who did not play and maps positions', () => {
  const players = parsePlayerStats(sample, game);
  assert.deepStrictEqual(players.map((p) => p.position), ['GK', 'DEF', 'FWD', 'MID']);
  assert.ok(!players.some((p) => p.fullName === 'Unused Sub'));
});

test('clean sheets go to the team that conceded nothing, after 60 minutes', () => {
  const [keeper, defender, , away] = parsePlayerStats(sample, game);
  assert.strictEqual(keeper.stats.cleanSheetDef, 1);
  assert.strictEqual(defender.stats.cleanSheetDef, 1);
  assert.strictEqual(away.stats.cleanSheetMid, undefined);
  assert.strictEqual(away.stats.played60, 0);
});

test('fantasy points follow the position-based rules, times the normalization factor', () => {
  const [keeper, defender, forward, away] = parsePlayerStats(sample, game);
  // Keeper: played 1 + 60 min 1 + clean sheet 4 + 3 saves 1 = 7, times 2.5
  assert.strictEqual(fantasyPoints('Soccer', keeper.stats), 17.5);
  // Defender: 2 + defender goal 6 + clean sheet 4 = 12, times 2.5
  assert.strictEqual(fantasyPoints('Soccer', defender.stats), 30);
  // Forward: 2 + goal 4 + assist 3 = 9, times 2.5
  assert.strictEqual(fantasyPoints('Soccer', forward.stats), 22.5);
  // Away midfielder: played 1, yellow -1 = 0
  assert.strictEqual(fantasyPoints('Soccer', away.stats), 0);
});

test('weeks follow the NFL calendar: Tuesday after Labor Day through Monday', () => {
  const w1 = weekWindow(2024, 1);
  assert.strictEqual(w1.start.toISOString().slice(0, 10), '2024-09-03');
  assert.strictEqual(w1.end.toISOString().slice(0, 10), '2024-09-09');
  assert.strictEqual(weekWindow(2024, 2).start.toISOString().slice(0, 10), '2024-09-10');
  assert.strictEqual(weekWindow(2023, 1).start.toISOString().slice(0, 10), '2023-09-05');
});
