// Soccer adapter: English Premier League matches from API-Football, converted into Podium's
// common shape. Exports the same functions as adapters/nfl.js:
//   listGames(season, week)        -> [{ gameId, week, date, finished, homeTeam, awayTeam, ... }]
//   playerStatsForGame(game)       -> [{ externalApiId, fullName, realTeam, position, stats }]
//
// Podium's scoring weeks follow the NFL calendar, so "week N" here means every Premier League
// match played during NFL week N of the same season (Tuesday through Monday). The 2024 NFL
// season lines up with the 2024-25 Premier League season. Weeks that fall on an international
// break have no matches.
const { apiGet } = require('../client');

const SPORT = 'Soccer';
const LEAGUE_ID = 39; // English Premier League
const FINISHED = new Set(['FT', 'AET', 'PEN']); // full time, after extra time, after penalties
const POSITIONS = { G: 'GK', D: 'DEF', M: 'MID', F: 'FWD' };

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Tuesday-to-Monday window for NFL week [week] of [season]. NFL week 1 starts the Tuesday
 * after Labor Day (the first Monday in September); the season kicks off that Thursday.
 */
function weekWindow(season, week) {
  const sept1 = new Date(Date.UTC(season, 8, 1));
  const daysToMonday = (8 - sept1.getUTCDay()) % 7; // getUTCDay: 0 = Sunday, 1 = Monday
  const laborDay = new Date(sept1.getTime() + daysToMonday * DAY_MS);
  const start = new Date(laborDay.getTime() + (1 + 7 * (week - 1)) * DAY_MS);
  const end = new Date(start.getTime() + 6 * DAY_MS);
  return { start, end };
}

const isoDate = (d) => d.toISOString().slice(0, 10);

/** Premier League matches in NFL week [week]. One request per week (cached). */
async function listGames(season, week, options = {}) {
  const { start, end } = weekWindow(season, week);
  const fixtures = await apiGet(
    'soccer',
    'fixtures',
    { league: LEAGUE_ID, season, from: isoDate(start), to: isoDate(end) },
    options,
  );
  return fixtures.map((f) => ({
    gameId: String(f.fixture.id),
    week,
    date: new Date(f.fixture.date),
    finished: FINISHED.has(f.fixture.status?.short),
    homeTeam: f.teams?.home?.name,
    awayTeam: f.teams?.away?.name,
    homeGoals: f.goals?.home ?? 0,
    awayGoals: f.goals?.away ?? 0,
  }));
}

const n = (value) => (Number.isFinite(Number(value)) ? Number(value) : 0);

/**
 * Converts a /fixtures/players response into Podium's player shape. [game] supplies the final
 * score, which decides clean sheets. Goals and clean sheets are stored under position-specific
 * keys because they're worth different points by position (see scoring.js).
 */
function parsePlayerStats(response, game) {
  const players = [];
  for (const teamBlock of response ?? []) {
    const realTeam = teamBlock.team?.name ?? null;
    const isHome = realTeam === game.homeTeam;
    const conceded = isHome ? n(game.awayGoals) : n(game.homeGoals);

    for (const entry of teamBlock.players ?? []) {
      const id = entry.player?.id;
      const s = entry.statistics?.[0];
      if (id === undefined || id === null || !s) continue;
      const minutes = n(s.games?.minutes);
      if (minutes <= 0) continue; // unused substitutes

      const position = POSITIONS[s.games?.position] ?? 'MID';
      const defensive = position === 'GK' || position === 'DEF';
      const goals = n(s.goals?.total);
      const stats = {
        minutes,
        played: 1,
        played60: minutes >= 60 ? 1 : 0,
        assists: n(s.goals?.assists),
        saves: n(s.goals?.saves),
        penSaved: n(s.penalty?.saved),
        penMissed: n(s.penalty?.missed),
        yellow: n(s.cards?.yellow),
        red: n(s.cards?.red),
      };
      if (position === 'FWD') stats.goalFwd = goals;
      else if (position === 'MID') stats.goalMid = goals;
      else stats.goalDef = goals;

      if (minutes >= 60 && conceded === 0) {
        if (defensive) stats.cleanSheetDef = 1;
        else if (position === 'MID') stats.cleanSheetMid = 1;
      }
      if (defensive) stats.concededDef = conceded;

      players.push({ externalApiId: String(id), fullName: entry.player.name, realTeam, position, stats });
    }
  }
  return players;
}

/** Player stats for one finished match. One request per match (cached). */
async function playerStatsForGame(game, options = {}) {
  const response = await apiGet('soccer', 'fixtures/players', { fixture: game.gameId }, options);
  return parsePlayerStats(response, game);
}

module.exports = { SPORT, LEAGUE_ID, listGames, playerStatsForGame, parsePlayerStats, weekWindow };
