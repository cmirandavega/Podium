// Tests the NFL parser and scoring against a sample API response. No API key or network needed.
const test = require('node:test');
const assert = require('node:assert');
const { parsePlayerStats, weekNumber } = require('../adapters/nfl');
const { fantasyPoints } = require('../scoring');

const sample = [
  {
    team: { id: 1, name: 'Las Vegas Raiders' },
    groups: [
      {
        name: 'Passing',
        players: [{
          player: { id: 101, name: 'Sample Quarterback' },
          statistics: [
            { name: 'comp att', value: '24/35' },
            { name: 'yards', value: '300' },
            { name: 'passing touch downs', value: '2' },
            { name: 'interceptions', value: '1' },
          ],
        }],
      },
      {
        name: 'Rushing',
        players: [
          {
            player: { id: 101, name: 'Sample Quarterback' },
            statistics: [{ name: 'total rushes', value: '3' }, { name: 'yards', value: '20' }],
          },
          {
            player: { id: 102, name: 'Sample Running Back' },
            statistics: [
              { name: 'total rushes', value: '18' },
              { name: 'yards', value: '95' },
              { name: 'rushing touch downs', value: '1' },
            ],
          },
        ],
      },
      {
        name: 'Receiving',
        players: [{
          player: { id: 103, name: 'Sample Receiver' },
          statistics: [
            { name: 'total receptions', value: '7' },
            { name: 'longest reception', value: '41' },
            { name: 'yards', value: '110' },
            { name: 'receiving touch downs', value: '1' },
          ],
        }],
      },
      {
        name: 'Fumbles',
        players: [{
          player: { id: 102, name: 'Sample Running Back' },
          statistics: [{ name: 'total', value: '1' }, { name: 'lost', value: '1' }],
        }],
      },
      { name: 'Kicking', players: [{ player: { id: 104, name: 'Sample Kicker' }, statistics: [{ name: 'field goals', value: '2/2' }] }] },
    ],
  },
];

test('parses players and merges stat groups', () => {
  const players = parsePlayerStats(sample);
  const byName = Object.fromEntries(players.map((p) => [p.fullName, p]));

  assert.deepStrictEqual(byName['Sample Quarterback'].stats, { passYds: 300, passTD: 2, passInt: 1, rushYds: 20 });
  assert.strictEqual(byName['Sample Quarterback'].position, 'QB');
  assert.deepStrictEqual(byName['Sample Running Back'].stats, { rushYds: 95, rushTD: 1, fumLost: 1 });
  assert.strictEqual(byName['Sample Running Back'].position, 'RB');
  assert.deepStrictEqual(byName['Sample Receiver'].stats, { rec: 7, recYds: 110, recTD: 1 });
  assert.strictEqual(byName['Sample Receiver'].position, 'WR');
  assert.strictEqual(byName['Sample Kicker'], undefined, 'kickers are not scored yet');
  assert.strictEqual(byName['Sample Receiver'].realTeam, 'Las Vegas Raiders');
});

test('scores with PPR rules', () => {
  // 300*0.04 + 2*4 - 1*2 + 20*0.1 = 12 + 8 - 2 + 2 = 20
  assert.strictEqual(fantasyPoints('NFL', { passYds: 300, passTD: 2, passInt: 1, rushYds: 20 }), 20);
  // 7 + 11 + 6 = 24
  assert.strictEqual(fantasyPoints('NFL', { rec: 7, recYds: 110, recTD: 1 }), 24);
  // 9.5 + 6 - 2 = 13.5
  assert.strictEqual(fantasyPoints('NFL', { rushYds: 95, rushTD: 1, fumLost: 1 }), 13.5);
});

test('reads week numbers from API strings', () => {
  assert.strictEqual(weekNumber('Week 7'), 7);
  assert.strictEqual(weekNumber(3), 3);
  assert.strictEqual(weekNumber(undefined), null);
});
