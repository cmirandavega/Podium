// Checks your API key, plan, quota, and which seasons the plan can access.
//   npm run probe            NFL
//   npm run probe -- soccer  Premier League
// /status is free; /leagues costs 1 request.
const { apiGet, usage } = require('./client');

const SPORTS = {
  nfl: { leagueId: 1, coverage: (c) => c.games?.statisitcs?.players ?? c.games?.statistics?.players },
  soccer: { leagueId: 39, coverage: (c) => c.fixtures?.statistics_players },
};

async function main() {
  const sport = (process.argv[2] ?? 'nfl').toLowerCase();
  const config = SPORTS[sport];
  if (!config) throw new Error(`Unknown sport "${sport}". Use: ${Object.keys(SPORTS).join(', ')}`);

  const status = await apiGet(sport, 'status', {}, { cache: false });
  const s = Array.isArray(status) ? status[0] ?? status : status;
  console.log('Plan:', s?.subscription?.plan, '| active:', s?.subscription?.active);
  console.log('Requests today:', s?.requests?.current, '/', s?.requests?.limit_day);

  const leagues = await apiGet(sport, 'leagues', { id: config.leagueId }, { cache: false });
  const league = leagues[0];
  console.log(`\n${league.league.name} seasons:`);
  for (const season of league.seasons) {
    const playerStats = config.coverage(season.coverage ?? {});
    console.log(`  ${season.year}${season.current ? ' (current)' : ''}  player game stats: ${playerStats ? 'yes' : 'no'}`);
  }
  console.log('\nThe free plan may still block some seasons; try one with ingest.js --dry-run to confirm.');
  console.log('Usage:', usage());
}

main().catch((err) => {
  console.error('Probe failed:', err.message);
  process.exit(1);
});
