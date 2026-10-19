// API-Sports HTTP client: one place for the key header, rate limiting,
// daily quota protection, error handling, and response caching.
const fs = require('fs');
const path = require('path');

const BASE_URLS = {
  nfl: 'https://v1.american-football.api-sports.io',
  // Added as adapters are written:
  // nba: 'https://v2.nba.api-sports.io',
  // mlb: 'https://v1.baseball.api-sports.io',
  // soccer: 'https://v3.football.api-sports.io',
};

const MIN_GAP_MS = 6500;     // free plan allows 10 requests per minute
const DAILY_RESERVE = 5;     // stop before the last few requests of the day
const CACHE_DIR = path.join(__dirname, 'cache');

let lastCallAt = 0;
let remainingToday = null;
let requestsMade = 0;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function cacheFile(sport, endpoint, params) {
  const key = `${sport}_${endpoint}_${new URLSearchParams(params).toString()}`
    .replace(/[^a-zA-Z0-9_=-]/g, '_');
  return path.join(CACHE_DIR, `${key}.json`);
}

function hasErrors(errors) {
  if (!errors) return false;
  if (Array.isArray(errors)) return errors.length > 0;
  return Object.keys(errors).length > 0;
}

/**
 * GET an API-Sports endpoint and return the `response` array.
 * Cached responses cost zero requests; pass { refresh: true } to bypass the cache.
 */
async function apiGet(sport, endpoint, params = {}, { cache = true, refresh = false } = {}) {
  const base = BASE_URLS[sport];
  if (!base) throw new Error(`Unknown sport "${sport}"`);
  const key = process.env.APISPORTS_KEY;
  if (!key) throw new Error('APISPORTS_KEY is not set. Copy .env.example to .env and add your key.');

  const file = cacheFile(sport, endpoint, params);
  if (cache && !refresh && fs.existsSync(file)) {
    return JSON.parse(fs.readFileSync(file, 'utf8')).response;
  }

  if (remainingToday !== null && remainingToday <= DAILY_RESERVE) {
    throw new Error(`Stopping: only ${remainingToday} API requests left today (resets at 00:00 UTC).`);
  }

  const wait = lastCallAt + MIN_GAP_MS - Date.now();
  if (wait > 0) await sleep(wait);
  lastCallAt = Date.now();

  const url = `${base}/${endpoint}?${new URLSearchParams(params)}`;
  const res = await fetch(url, { headers: { 'x-apisports-key': key } });
  requestsMade += 1;

  const header = res.headers.get('x-ratelimit-requests-remaining');
  if (header !== null) remainingToday = Number(header);

  if (!res.ok) throw new Error(`${endpoint} failed with HTTP ${res.status}`);
  const body = await res.json();

  // API-Sports returns HTTP 200 with an `errors` field for plan limits, bad keys, and quota.
  if (hasErrors(body.errors)) {
    throw new Error(`${endpoint}: ${JSON.stringify(body.errors)}`);
  }

  if (cache) {
    fs.mkdirSync(CACHE_DIR, { recursive: true });
    fs.writeFileSync(file, JSON.stringify(body, null, 2));
  }
  return body.response;
}

function usage() {
  return { requestsMade, remainingToday };
}

module.exports = { apiGet, usage, BASE_URLS };
