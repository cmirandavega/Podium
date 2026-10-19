# Sports data ingestion

Fetches statistics from API-Sports, converts them to fantasy points, and writes them to Cloud Firestore.
The Flutter app never calls the sports API; it only reads the Firestore collections below.

## Setup

1. Create a free account at api-sports.io and copy your key from **Account → My Access**.
2. In this folder:
   ```bash
   npm install
   cp .env.example .env          # Windows PowerShell: Copy-Item .env.example .env
   ```
   Put your key in `.env`.
3. Copy your Firebase service account key into this folder as `serviceAccountKey.json`
   (Firebase console → Project settings → Service accounts → Generate new private key).

`.env`, `serviceAccountKey.json`, and `cache/` are gitignored. Never commit them.

## Commands

```bash
npm run probe                                                       # plan, quota, and available seasons
npm test                                                            # parser and scoring tests (no key needed)
node --env-file=.env ingest.js --season 2024 --week 1 --dry-run     # score a week without writing
node --env-file=.env ingest.js --season 2024 --week 1               # score a week and write to Firestore
```

Options: `--limit 2` processes only two games (cheap testing), and `--refresh` ignores cached responses
(use it for a week that is still being played, or to pick up stat corrections).

## Request budget (free plan: 100 per day, 10 per minute)

| Call | Cost |
|---|---|
| Season game list | 1 request per season (cached after the first run) |
| Player stats | 1 request per finished game (cached) |
| One NFL week | about 17 requests the first time, 0 after that |

The client waits 6.5 seconds between requests and stops when 5 requests remain for the day.
The quota resets at 00:00 UTC. Cached responses are reused, so re-running a week or changing
scoring rules costs nothing.

## Data written to Firestore

| Collection | Document ID | Fields |
|---|---|---|
| `players` | `NFL_{apiPlayerId}` | sport, externalApiId, fullName, realTeam, position (inferred: QB, RB, or WR), updatedAt |
| `playerStats` | `NFL_{apiPlayerId}_{gameId}` | playerId, sport, fullName, realTeam, position, scoringPeriodId, gameId, gameDate, rawStats (map), fantasyPoints |
| `scoringPeriods` | `period_{season}_w{week}` | season, week, startDate, endDate, lockTime |

Example query for a team builder screen: `players` where `sport == "NFL"`.
Example query for a player's week: `playerStats` where `playerId == "NFL_123"` and `scoringPeriodId == "period_2024_w1"`.

## Adding a sport

Each sport is an adapter in `adapters/` that exports `listGames(season, week)` and
`playerStatsForGame(game)` and returns the same shape as `adapters/nfl.js`. Add its base URL in
`client.js`, its scoring rules and normalization factor in `scoring.js`, and register it in `ingest.js`.

## Scoring

NFL uses standard PPR: 0.04 per passing yard, 4 per passing TD, −2 per interception,
0.1 per rushing or receiving yard, 6 per rushing or receiving TD, 1 per reception,
2 per two-point conversion, −2 per fumble lost. Kickers and defenses are not scored yet.
