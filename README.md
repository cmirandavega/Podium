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
