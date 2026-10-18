// Fantasy scoring: per-sport rules, then cross-sport normalization.
// Raw stats are stored separately, so changing these numbers only requires re-running
// ingest.js against cached responses, with no new API requests.

const RULES = {
  // Standard PPR (point per reception) NFL scoring.
  NFL: {
    passYds: 0.04, passTD: 4, passInt: -2,
    rushYds: 0.1, rushTD: 6,
    rec: 1, recYds: 0.1, recTD: 6,
    twoPt: 2, fumLost: -2,
  },
};

// Cross-sport normalization: multiplies each sport's points so that a typical starter
// in every sport earns a similar weekly total. NFL is the baseline (1.0). Other sports
// get their factor once their adapters exist and average weekly totals can be measured.
const NORMALIZATION = {
  NFL: 1.0,
};

function rawPoints(sport, stats) {
  const rules = RULES[sport];
  if (!rules) throw new Error(`No scoring rules for ${sport}`);
  return Object.entries(stats).reduce((total, [stat, value]) => total + (rules[stat] ?? 0) * value, 0);
}

/** Fantasy points for one player in one game, rounded to 2 decimals. */
function fantasyPoints(sport, stats) {
  const points = rawPoints(sport, stats) * (NORMALIZATION[sport] ?? 1);
  return Math.round(points * 100) / 100;
}

module.exports = { RULES, NORMALIZATION, fantasyPoints };
