// Fetches one week of games, scores every player, and writes the results to Firestore.
//
//   node --env-file=.env ingest.js --sport nfl --season 2024 --week 1 --dry-run
//   node --env-file=.env ingest.js --sport nfl --season 2024 --week 1
//
// Options:
//   --dry-run   score and print results without writing to Firestore
//   --refresh   ignore cached API responses (costs requests; use for stat corrections)
//   --limit N   only process the first N finished games (useful while testing)
const { usage } = require('./client');
const { fantasyPoints } = require('./scoring');

const ADAPTERS = {
  nfl: require('./adapters/nfl'),
};

function parseArgs(argv) {
  const args = { sport: 'nfl', dryRun: false, refresh: false, limit: Infinity };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === '--sport') args.sport = argv[++i];
    else if (flag === '--season') args.season = Number(argv[++i]);
    else if (flag === '--week') args.week = Number(argv[++i]);
    else if (flag === '--limit') args.limit = Number(argv[++i]);
    else if (flag === '--dry-run') args.dryRun = true;
    else if (flag === '--refresh') args.refresh = true;
  }
  if (!args.season || !args.week) {
    throw new Error('Usage: node --env-file=.env ingest.js --sport nfl --season 2024 --week 1 [--dry-run]');
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const adapter = ADAPTERS[args.sport];
  if (!adapter) throw new Error(`No adapter for "${args.sport}". Available: ${Object.keys(ADAPTERS).join(', ')}`);
  const options = { refresh: args.refresh };

  const games = await adapter.listGames(args.season, args.week, options);
  if (games.length === 0) throw new Error(`No ${adapter.SPORT} games found for ${args.season} week ${args.week}.`);
  const finished = games.filter((g) => g.finished).slice(0, args.limit);
  console.log(`${adapter.SPORT} ${args.season} week ${args.week}: ${games.length} games, ${finished.length} to process.`);

  const rows = [];
  for (const game of finished) {
    const players = await adapter.playerStatsForGame(game, options);
    for (const p of players) {
      rows.push({
        ...p,
        sport: adapter.SPORT,
        gameId: game.gameId,
        gameDate: game.date,
        fantasyPoints: fantasyPoints(adapter.SPORT, p.stats),
      });
    }
    console.log(`  ${game.awayTeam} at ${game.homeTeam}: ${players.length} players`);
  }

  const dates = games.map((g) => g.date).sort((a, b) => a - b);
  const period = {
    id: `period_${args.season}_w${args.week}`,
    season: args.season,
    week: args.week,
    startDate: dates[0],
    endDate: dates[dates.length - 1],
    lockTime: dates[0],
  };

  const top = [...rows].sort((a, b) => b.fantasyPoints - a.fantasyPoints).slice(0, 10);
  console.log('\nTop 10 players:');
  for (const r of top) {
    console.log(`  ${r.fantasyPoints.toFixed(2).padStart(6)}  ${r.fullName} (${r.position ?? '?'}, ${r.realTeam})`);
  }

  if (args.dryRun) {
    console.log(`\nDry run: ${rows.length} player stat lines scored, nothing written to Firestore.`);
  } else {
    const count = await writeWeekSafe(period, rows);
    console.log(`\nWrote ${count} documents to Firestore (scoring period ${period.id}).`);
  }
  console.log('API usage this run:', usage());
}

async function writeWeekSafe(period, rows) {
  const { writeWeek } = require('./writer'); // only loaded when writing, so dry runs need no service account
  return writeWeek(period, rows);
}

main().catch((err) => {
  console.error('Ingest failed:', err.message);
  console.error('API usage this run:', usage());
  process.exit(1);
});
