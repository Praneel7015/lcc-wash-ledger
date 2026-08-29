# CI/CD Setup Guide — Washlog

This document explains how to set up GitHub Actions for automated web deployment and Android APK releases.

---

## Workflows Overview

| Workflow | File | Trigger |
|---|---|---|
| Deploy web dashboard | `.github/workflows/deploy-web.yml` | Push to `main` |
| Build & release APK | `.github/workflows/build-apk.yml` | Push a `v*` tag |

---

## Secrets You Must Add to GitHub

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

### 1. `FIREBASE_SERVICE_ACCOUNT` (required for web deploy)

This is the Firebase service account key that authorises the deploy action to push to Firebase Hosting.

**Steps to obtain it:**

1. Open the [Firebase Console](https://console.firebase.google.com/) and select the `wash-ledgar` project.
2. Go to **Project Settings** (gear icon) → **Service accounts** tab.
3. Click **Generate new private key** → **Generate key**.
4. A `.json` file will download. Open it and copy the **entire file contents**.
5. In GitHub, create a secret named `FIREBASE_SERVICE_ACCOUNT` and paste the JSON as the value.

> **Security note:** Never commit this JSON file to the repository. The `.gitignore` should exclude `*.json` service account files.

---

### 2. `GITHUB_TOKEN` (automatic — no action needed)

The `GITHUB_TOKEN` secret is automatically provided by GitHub Actions for every workflow run. You do **not** need to create it manually. It is used by:
- `FirebaseExtended/action-hosting-deploy` (to post PR preview links)
- `softprops/action-gh-release` (to create GitHub Releases and attach the APK)

---

## Triggering a New APK Release

To build the Android APK and publish a GitHub Release, push a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow will:
1. Strip the `v` prefix to get the version string (`1.0.0`).
2. Patch `pubspec.yaml` with the new version (preserving the existing build number, e.g. `1.0.0+1`).
3. Run `flutter build apk --release`.
4. Create a GitHub Release named **"Luxury Car Care v1.0.0"** with the APK attached and auto-generated release notes.

---

## APK Signing (Production Releases)

The APK built by the workflow is an **unsigned debug-keystore APK** unless you configure a release keystore. For distribution outside of direct sideloading (e.g. Google Play), you need to:

1. Generate a keystore: `keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Add the keystore and its credentials as GitHub secrets.
3. Configure `android/app/build.gradle` with a `signingConfigs` block that reads from environment variables.

A full keystore signing setup is outside the scope of this guide; refer to the [Flutter Android deployment docs](https://docs.flutter.dev/deployment/android) for details.

---

## Web Deploy Notes

- The workflow deploys to the **live** channel of Firebase Hosting (production URL).
- `firebase.json` in the project root is used automatically by the deploy action — no extra configuration needed.
- To preview a deploy on a PR before merging, the `FirebaseExtended/action-hosting-deploy` action will automatically post a preview URL as a PR comment when run on a pull request (it uses `GITHUB_TOKEN` for this).
