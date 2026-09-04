# WashLog

Car wash vehicle tracking app — Flutter (Android + Web) + Firebase.

---

## What it is

- **Worker Android app** — shake or tap widget → photograph plate (OCR) → photograph front → pick type + package → enter phone + paid → done in ~30 seconds.
- **Owner web dashboard** — today's revenue, date-range reports, CSV export, rate table editor, end-of-day email.
- **Light & dark themes** — both apps follow the OS setting by default; the toggle in the app bar overrides it and the choice is remembered.

Which app a user gets is decided by their `role` custom claim (`owner` or
`worker`), not by the platform they sign in from. Owners can open the dashboard
on a phone; workers cannot reach it from the web URL.

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

### 5 — Assign roles

Roles are Firebase Auth custom claims. Edit the user list in
`functions/set-roles.js`, then run it once with a service-account key present:

```bash
cd functions
node set-roles.js
```

A user with no `role` claim can sign in but lands in the worker flow, so every
account needs an entry here.

### 6 — Configure the daily email

The end-of-day email is sent through [Resend](https://resend.com), not SMTP.

1. Create a Resend API key and verify your sending domain.
2. Set the function secrets:
```bash
firebase functions:secrets:set RESEND_API_KEY
# optional — defaults to "Luxury Car Care <wash@sindhole.com>"
firebase functions:secrets:set RESEND_FROM
```
3. Add the recipient(s) to the `settings/app` document as `ownerEmails`
   (a list of addresses, or a single comma-separated string).

`scheduledDayClose` runs at 21:30 IST daily. "Close Day" in the dashboard
writes an `emailTasks` document, which `manualDayClose` picks up.

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

## Fonts

The theme asks for `Inter`. On **web** that resolves through the Google Fonts
`<link>` in `web/index.html`. On **Android** there is no bundled `Inter` asset,
so the app silently falls back to the system font — the two platforms do not
currently look identical.

To make Android match, drop the TTFs into `assets/fonts/` and declare them in
`pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
```

---

## Shake service (Android)

Workers start the shake service from the app once at the beginning of the shift. While the service is running (shown as a persistent notification), shaking the phone opens the camera screen. The service uses the native `ShakeForegroundService.kt` and reads from the accelerometer with no additional permissions.

---

## Data model

| Collection | Key fields |
|---|---|
| `users` | name (uid → display name, for reports) |
| `customers` | doc id = normalised plate; phone, visitCount, lastVisitAt |
| `visits` | plate, phone, vehicleType, packageId, amount, paid, paymentMethod, voided, workerId, createdAt, platePhotoUrl, frontPhotoUrl |
| `rates` | doc id = `{vehicleType}__{packageId}`; vehicleType, packageId, amountRupees |
| `packages` | doc id = package id; label, description, vehicleTypes, order |
| `settings/app` | ownerEmails |
| `emailTasks` | trigger doc written by the dashboard → `manualDayClose` reads it |

Roles live in Firebase Auth custom claims, not in Firestore.

> **Photo retention is not implemented.** `photoRetentionDays` exists in
> `lib/core/constants.dart` and this README used to claim a `cleanOldPhotos`
> function deleted photos after 90 days — there is no such function. Storage
> grows without bound. See the audit notes before relying on the free tier.

---

## Free-tier cost

At ~20 vehicles/day with no SMS the Firestore and Functions usage sits well
inside the Blaze free tier.

Storage grows ~8 MB/day and **is never cleaned up** (see the note in the data
model above), so it crosses the 5 GB free tier at roughly 20 months and keeps
going. Add a scheduled cleanup function before then.
