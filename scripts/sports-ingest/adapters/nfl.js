// NFL adapter: converts API-American-Football responses into Podium's common shape.
// Every sport adapter exports the same functions so ingest.js never cares which sport it handles:
//   listGames(season, week)        -> [{ gameId, week, date, finished, homeTeam, awayTeam }]
//   playerStatsForGame(game)       -> [{ externalApiId, fullName, realTeam, position, stats }]
const { apiGet } = require('../client');

const SPORT = 'NFL';
const LEAGUE_ID = 1;
const FINISHED = new Set(['FT', 'AOT']); // final, final after overtime

function weekNumber(value) {
  const match = String(value ?? '').match(/\d+/);
  return match ? Number(match[0]) : null;
}

function toNumber(value) {
  if (value === null || value === undefined || value === '') return 0;
  const n = parseFloat(String(value).replace(/,/g, ''));
  return Number.isFinite(n) ? n : 0;
}

/** All regular-season games for one week. Uses one request per season (cached). */
async function listGames(season, week, options = {}) {
  const games = await apiGet('nfl', 'games', { league: LEAGUE_ID, season }, options);
  return games
    .filter((g) => /regular/i.test(g.game?.stage ?? '') && weekNumber(g.game?.week) === week)
    .map((g) => ({
      gameId: String(g.game.id),
      week,
      date: g.game.date?.timestamp ? new Date(g.game.date.timestamp * 1000) : new Date(g.game.date?.date),
      finished: FINISHED.has(g.game.status?.short),
      homeTeam: g.teams?.home?.name,
      awayTeam: g.teams?.away?.name,
    }));
}

// Maps one stat line, inside one group, to a Podium stat key.
function statKey(group, name) {
  const n = name.toLowerCase();
  const isTd = n.includes('touch') || n === 'td' || n === 'tds';
  if (group === 'passing') {
    if (n === 'yards') return 'passYds';
    if (isTd) return 'passTD';
    if (n.startsWith('interception')) return 'passInt';
    if (n.startsWith('two')) return 'twoPt';
  }
  if (group === 'rushing') {
    if (n === 'yards') return 'rushYds';
    if (isTd) return 'rushTD';
    if (n.startsWith('two')) return 'twoPt';
  }
  if (group === 'receiving') {
    if (n === 'yards') return 'recYds';
    if (isTd) return 'recTD';
    if (n.includes('reception') && !n.includes('long')) return 'rec';
    if (n.startsWith('two')) return 'twoPt';
  }
  if (group === 'fumbles' && n === 'lost') return 'fumLost';
  return null; // kicking, defense, and returns are not scored yet
}

// The stats endpoint doesn't return positions, so infer a skill position from the stat groups.
function inferPosition(stats) {
  if ((stats.passYds ?? 0) > 0 || (stats.passTD ?? 0) > 0) return 'QB';
  if ((stats.recYds ?? 0) + (stats.rec ?? 0) > (stats.rushYds ?? 0)) return 'WR';
  if ((stats.rushYds ?? 0) > 0 || (stats.rushTD ?? 0) > 0) return 'RB';
  return null;
}

/** Converts a /games/statistics/players response into Podium's common player shape. */
function parsePlayerStats(response) {
  const players = new Map();
  for (const teamBlock of response ?? []) {
    const realTeam = teamBlock.team?.name ?? null;
    for (const groupBlock of teamBlock.groups ?? []) {
      const group = String(groupBlock.name ?? '').toLowerCase();
      for (const entry of groupBlock.players ?? []) {
        const id = entry.player?.id;
        if (id === undefined || id === null) continue;
        const key = String(id);
        if (!players.has(key)) {
          players.set(key, { externalApiId: key, fullName: entry.player.name, realTeam, stats: {} });
        }
        const p = players.get(key);
        for (const stat of entry.statistics ?? []) {
          const statName = statKey(group, String(stat.name ?? ''));
          if (statName) p.stats[statName] = (p.stats[statName] ?? 0) + toNumber(stat.value);
        }
      }
    }
  }
  return [...players.values()]
    .filter((p) => Object.keys(p.stats).length > 0)
    .map((p) => ({ ...p, position: inferPosition(p.stats) }));
}

/** Player stats for one finished game. One request per game (cached). */
async function playerStatsForGame(game, options = {}) {
  const response = await apiGet('nfl', 'games/statistics/players', { id: game.gameId }, options);
  return parsePlayerStats(response);
}

module.exports = { SPORT, listGames, playerStatsForGame, parsePlayerStats, weekNumber };
