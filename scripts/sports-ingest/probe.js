// Checks your API key, plan, quota, and which NFL seasons the plan can access.
// /status is free; /leagues costs 1 request.
const { apiGet, usage } = require('./client');

async function main() {
  const status = await apiGet('nfl', 'status', {}, { cache: false });
  const s = Array.isArray(status) ? status[0] ?? status : status;
  console.log('Plan:', s?.subscription?.plan, '| active:', s?.subscription?.active);
  console.log('Requests today:', s?.requests?.current, '/', s?.requests?.limit_day);

  const leagues = await apiGet('nfl', 'leagues', { id: 1 }, { cache: false });
  const nfl = leagues[0];
  console.log(`\n${nfl.league.name} seasons:`);
  for (const season of nfl.seasons) {
    const c = season.coverage ?? {};
    const playerStats = c.games?.statisitcs?.players ?? c.games?.statistics?.players;
    console.log(`  ${season.year}${season.current ? ' (current)' : ''}  player game stats: ${playerStats ? 'yes' : 'no'}`);
  }
  console.log('\nThe free plan may still block some seasons; try one with ingest.js --dry-run to confirm.');
  console.log('Usage:', usage());
}

main().catch((err) => {
  console.error('Probe failed:', err.message);
  process.exit(1);
});
