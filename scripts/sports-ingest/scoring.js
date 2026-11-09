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
  // Based on Fantasy Premier League: goals are worth more for defenders and midfielders,
  // clean sheets reward the back line, and keepers earn a point per three saves.
  Soccer: {
    played: 1, played60: 1,
    goalFwd: 4, goalMid: 5, goalDef: 6,
    assists: 3,
    cleanSheetDef: 4, cleanSheetMid: 1,
    concededDef: -0.5,
    saves: 1 / 3, penSaved: 5, penMissed: -2,
    yellow: -1, red: -3,
  },
};

// Cross-sport normalization: multiplies each sport's points so that a typical starter
// in every sport earns a similar weekly total. NFL is the baseline (1.0). Other sports
// get their factor once their adapters exist and average weekly totals can be measured.
const NORMALIZATION = {
  NFL: 1.0,
  // A typical Premier League starter scores about 4-5 of these points per match and plays
  // once a week, while a typical NFL starter scores about 11-13 PPR points. 2.5 puts them on
  // a similar scale; re-measure once a few weeks of both are loaded.
  Soccer: 2.5,
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
