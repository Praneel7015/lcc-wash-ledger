# WashLog

Car wash vehicle tracking app — Flutter (Android + Web) + Firebase.

---

## What it is

- **Worker Android app** — shake or tap widget → photograph plate (OCR) → photograph front → pick type + package → enter phone + paid → done in ~30 seconds.
- **Owner web dashboard** — today's revenue, date-range reports, CSV export, rate table editor, end-of-day email.

---

## First-time setup (do this once)

### 1 — Create a Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project, e.g. `washlog-prod`
3. Enable **Firestore** (production mode) and **Storage** and **Authentication** (Email/Password)
4. Upgrade the project to **Blaze** (needed for scheduled Cloud Functions) — set a budget alert of ₹500/month

### 2 — Connect Flutter to Firebase

Install the FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

Run from the project root:
```bash
flutterfire configure
```

Select the `washlog-prod` project and enable Android + Web platforms. This rewrites `lib/firebase_options.dart` with your real keys and places `google-services.json` in `android/app/`.

### 3 — Create user accounts in Firebase Auth

For each worker + yourself (owner), create accounts in Firebase Console → Authentication → Users.

Then in Firestore, create a document in the `workers` collection with the user's UID as the document ID:
```json
{
  "name": "Ravi",
  "isOwner": false
}
```
For the owner account set `"isOwner": true`.

### 4 — Seed the rates

Open the owner dashboard → Rates tab → enter prices for each vehicle type × package combination.

### 5 — Configure the daily email

1. In Firebase Console → Project Settings → Service Accounts → generate a new private key.
2. Set SMTP credentials (Gmail App Password recommended):
```bash
firebase functions:config:set smtp.user="you@gmail.com" smtp.pass="your-app-password"
```
3. In the app → Settings → enter your email address and save.

---

## Build & run

### Android (worker phone)

```bash
flutter pub get
flutter run                   # debug on connected device
flutter build apk --release   # release APK for sideloading
```

Sideload the APK: transfer `build/app/outputs/flutter-apk/app-release.apk` to worker phones via USB or WhatsApp.

### Web (owner dashboard)

```bash
flutter build web --release
firebase deploy --only hosting
```

---

## Deploy Cloud Functions

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions,firestore,storage
```

---

## Download fonts

The app uses [Space Grotesk](https://fonts.google.com/specimen/Space+Grotesk) and [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono). Download the TTF files and place them in `assets/fonts/`:

- `assets/fonts/SpaceGrotesk-Regular.ttf`
- `assets/fonts/SpaceGrotesk-Medium.ttf`
- `assets/fonts/SpaceGrotesk-Bold.ttf`
- `assets/fonts/JetBrainsMono-Regular.ttf`
- `assets/fonts/JetBrainsMono-Bold.ttf`

---

## Shake service (Android)

Workers start the shake service from the app once at the beginning of the shift. While the service is running (shown as a persistent notification), shaking the phone opens the camera screen. The service uses the native `ShakeForegroundService.kt` and reads from the accelerometer with no additional permissions.

---

## Data model

| Collection | Key fields |
|---|---|
| `workers` | name, isOwner |
| `customers` | plate (normalised), phone, visitCount, lastVisitAt |
| `visits` | plate, phone, vehicleType, package, amount, paid, workerId, createdAt, platePhotoUrl, frontPhotoUrl |
| `rates` | `{vehicleType}_{package}` → amount |
| `settings` | ownerEmail, closeDayHour, closeDayMinute |
| `closeDayRequests` | trigger doc written by app → Cloud Function reads and deletes |

Photos are kept for 90 days then auto-deleted by the `cleanOldPhotos` Cloud Function. Firestore records are kept permanently.

---

## Free-tier cost

At ~20 vehicles/day with no SMS: **₹0/month** (well within Blaze free tier). Storage grows ~8 MB/day but is cleaned after 90 days (~720 MB peak, within the 5 GB free tier).
