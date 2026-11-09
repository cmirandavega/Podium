# Podium

Cross-sport fantasy sports app built with Flutter. Draft NBA, NFL, MLB, and soccer players onto one roster with unified scoring, live updates, trades, and AI-assisted lineup analysis.

CSC 4350 Software Engineering, Group 8, Fall 2026
Abdoulaye Barry, Amyas Hayes, Christopher Miranda Vega, Nabia Lavala, Tiwobista Belachew

## Tech stack

- **Frontend:** Flutter (Dart), targeting Android and iOS
- **Authentication:** Firebase Authentication (email and password)
- **Database:** Cloud Firestore
- **Notifications:** Firebase Cloud Messaging (planned)

## Features implemented

**Sprint 2: User management**
- Registration with unique usernames
- Login, logout, and password reset
- Persistent sessions across app restarts
- Roles: players and admins; admins can suspend and reactivate accounts

**Sprint 3**
- Live Scoring from real NFL stats (sports ingestion script), notifications inbox, user reporting and admin review, mock draft simulator, leaderboard

**Sprint 4: the full season loop**
- Leagues (Use Case 2): create single- or multi-sport leagues, join with a 6-character invite code, commissioner edits sports before the season
- Team Builder (Use Case 3): add and drop players from the league's sports, starters and bench, lineup locks
- League Chat (Use Case 7): live chat with report, delete, and mute
- Matchups and playoffs (Use Case 15), standings (Use Case 11), and Weekly Analysis (Use Case 5): round-robin schedule, weekly scoring from starters, 2- or 4-team playoffs, recaps with lineup efficiency
- Trades (Use Case 8): propose, counter, accept, reject, withdraw; rosters swap in one transaction
- AI Trade and Team Analyzer (Use Case 4) and AI Assistant Coach (Use Case 12): Gemini through Firebase AI Logic, grounded in the user's real roster and stats
- Prediction Wagers (Use Case 13): head-to-head wagers on matchups with Podium coins (no cash value), settled when the week is scored

### Demo walkthrough

1. Load stats for a few weeks: `node --env-file=.env ingest.js --sport nfl --season 2024 --week 1` (repeat for weeks 2-5) in `scripts/sports-ingest`
2. In the app, create a league (NFL, 4 teams, 3 regular-season weeks, 2 playoff teams) and copy the invite code
3. Fill the other teams and draft every roster: `node demo-league.js <INVITE_CODE>` in `scripts/firestore-seed`
4. Ask the AI Coach about your lineup, propose a trade and analyze it, post a wager
5. As commissioner, open Matchups: Start season, Lock lineups, Score week. Check Standings, Weekly Analysis, and wager payouts, then repeat through the playoffs

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android Studio with an Android emulator, or an Android phone with USB debugging enabled

Run `flutter doctor` to confirm your setup.

### Run the app

```bash
git clone https://github.com/cmirandavega/Podium.git
cd Podium
flutter pub get
flutter run
```

Start the emulator before `flutter run`. If more than one device is connected, list them with `flutter devices` and pick one with `flutter run -d <device-id>`.

No Firebase setup is needed to run the app; the project configuration is already included.

### AI features (one-time project setup)

The AI Trade Analyzer and AI Assistant Coach call Gemini through
[Firebase AI Logic](https://firebase.google.com/docs/ai-logic/get-started) using the
Gemini Developer API, which works on the free Spark plan. The Gemini API key is created
and stored in the Firebase project; never add it to the app code.

1. In the Firebase console, open **AI Services → AI Logic** and click **Get started**
2. Choose **Gemini Developer API**
3. Deploy the security rules so the daily AI limits are enforced: `firebase deploy --only firestore:rules`

Shared AI code lives in `lib/services/ai/`:

- `ai_service.dart`: the only place that calls Gemini (chat turns and structured JSON, with timeout and one retry for JSON)
- `ai_usage_service.dart`: daily request limits in the `aiUsage` collection (10 per day for the Trade Analyzer, 30 for the Coach)
- `ai_prompts.dart`: the grounding rules and the DATA block that keep answers based on the user's real roster and stats

## Project structure

```
lib/
  main.dart            App entry point
  theme.dart           Colors and theme
  models/              Data models (AppUser)
  services/            Firebase logic (AuthService, UserService)
  screens/             UI, one folder per area (auth, home, profile, admin)
  widgets/             Reusable UI components
  utils/               Validators and helpers
scripts/
  firestore-seed/      Script that creates the Firestore collections with sample data
firestore.rules        Firestore Security Rules
```

## Database seed script

`scripts/firestore-seed/seed.js` creates all Firestore collections with sample documents.

1. In the Firebase console, go to **Project settings → Service accounts → Generate new private key**
2. Save the file as `scripts/firestore-seed/serviceAccountKey.json` (it is gitignored; never commit it)
3. Run:

```bash
cd scripts/firestore-seed
npm install
node seed.js
```

## Contributing

1. Update main: `git checkout main` then `git pull`
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit, push, and open a pull request into `main`
4. Never push directly to `main`

Deploy security rule changes with `firebase deploy --only firestore:rules`.
