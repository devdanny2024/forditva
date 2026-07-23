# Forditva — Project Notes for Claude

Handoff notes so any Claude (or developer) can pick up this project. Kept
current as of **2026-07-23, version 1.0.1+57**. Update the "Current status"
and "Open / blocked" sections as work lands.

## What this is

Forditva is a **Flutter** speech + text + image translation app. Core language
pair is **Hungarian ⇄ German**; a third language is user-selectable
(EN/NL/FR/IT/RU/ES). It is branded for the **wir-in-ungarn.hu** community. The
client is **Markus Messemer** (communicates via Telegram; the user/developer
here is **Kayode**, "Jordanz"). Markus's WordPress developer is **Shahin**.

Stack: Flutter/Dart, **Gemini** for translation + image OCR (raw REST,
`gemini-flash-latest`), Google Cloud **STT** + **TTS**, `drift`/sqlite for
history, `flutter_localizations` (EN/DE/HU ARB files in `lib/l10n/`). Secrets
live in a bundled `.env` (Flutter asset): `GEMINI_API_KEY`, `GOOGLE_STT_KEY`,
`OPENAI_API_KEY`, `LINGVANEX_API_KEY`, `PREPAID_API_BASE_URL`,
`PREPAID_API_KEY`.

## Repo & environment

- Repo root: `D:\projects\forditva\forditva` (double-nested; the outer
  `D:\projects\forditva` just wraps it). Git branch: **main**.
- Flutter SDK: `D:\tools\flutter` (not on PATH by default; call the full path).
- JDK 17: `C:\Program Files\Java\jdk-17` (and a Temurin 17 under
  `C:\Program Files\Eclipse Adoptium\`).
- The project lives on the **D: drive**. It has been unmounted at times (e.g.
  after a laptop repair). If `D:\` is missing, the project is unreachable; the
  bundled `.env` can be extracted from a built APK
  (`assets/flutter_assets/.env`) if you need a key while D: is down.

## Build & deploy — READ before building

**Local Android builds fail on this Windows machine** with
`java.io.IOException: Unable to establish loopback connection` (root cause:
`sun.nio.ch.PipeImpl` opens an AF_UNIX socket whose `connect` fails here). The
fix is the JVM property **`jdk.net.unixdomain.tmpdir`** (NOT `java.io.tmpdir`):

```
JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=C:\jtmp"
GRADLE_OPTS="-Djdk.net.unixdomain.tmpdir=C:\jtmp"
```

set on the build command (create `C:\jtmp` first). Setting it only in
`org.gradle.jvmargs` does NOT work (Gradle filters custom -D from the daemon).
Confirmed working 2026-07-23. Reboot / JDK upgrade / `java.io.tmpdir` overrides
do nothing.

**Because of that, builds run on GitHub Actions** (workflows in
`.github/workflows/`):

- `android-apk.yml` — auto on every push to main. Debug-signed **APK** for
  **sideload testing** (this is what Markus installs). Download the artifact:
  `gh run download <run-id> -n forditva-apk`.
- `android-aab.yml` — **manual** (`workflow_dispatch`). Upload-key-signed
  **.aab** for the **Play Store**. Artifact name `forditva-aab`.
- `ios-testflight.yml` — auto on push. Builds the IPA and uploads to
  **TestFlight** (App Store Connect API key auth).

`android/gradle.properties` pins the JVM to 1536m for the RAM-constrained local
machine; the CI workflows bump it to 4g (Jetifier OOMs at 1536m on the runner).

**Always verify a downloaded APK's signature before sending it to Markus:**
`apksigner verify --print-certs <apk>` and confirm the SHA-256 below.

## Signing keys

- **Debug/sideload key** (all APKs Markus installs): SHA-256
  `037e7f9488a7920ad7961494f89c697207f1b71a72ae9b12e8f76a7e2530401c`. The
  release build type signs with the *debug* key so testers can install updates
  over the top. The real `~/.android/debug.keystore` is stored as GitHub secret
  `ANDROID_DEBUG_KEYSTORE` (base64); `build.gradle.kts` reads
  `FORDITVA_DEBUG_KEYSTORE` to use it on CI. The APK workflow **fails** if the
  built APK's signer != repo variable `ANDROID_SIGNING_SHA256`. Do not let a
  runner-generated key ship: Play Protect blocks it and testers can't update.
- **Play upload key** (the .aab only): generated 2026-07-23, alias `upload`,
  SHA-256 `1F:51:05:AD:A2:19:B5:E1:...:8F:75`. Lives in **`.deploy/`**
  (gitignored: `upload-keystore.jks`, `upload-keystore-password.txt`,
  `PLAY_SIGNING.md`) AND as GitHub secrets `ANDROID_UPLOAD_KEYSTORE`(base64) /
  `_KEYSTORE_PASSWORD` / `_KEY_ALIAS` / `_KEY_PASSWORD`. `build.gradle.kts`
  signs release with it only when `FORDITVA_UPLOAD_KEYSTORE` is set (the AAB
  job); otherwise release still uses the debug key. **`.deploy/` is not in git —
  back it up off-machine. Losing the upload key needs a Play support reset.**
- iOS signing is fully automated in `ios-testflight.yml` via the App Store
  Connect API key (GitHub secrets `APP_STORE_CONNECT_*`, `APPLE_TEAM_ID`,
  `IOS_BUNDLE_ID`). iOS bundle id: `hu.wirinungarn.forditva3`.

## App identifiers

- **Android applicationId: `hu.wirinungarn.forditva`** (changed 2026-07-23 from
  the default `com.example.forditva`, which Play rejects). The internal
  `namespace`/MainActivity package is still `com.example.forditva` (code-only,
  fine). Because the applicationId changed, the +57 build installs as a **fresh
  app** — testers uninstall the old `com.example` build once, then install the
  new one; updates are normal after that.
- iOS bundle id: `hu.wirinungarn.forditva3`.

## Current status (2026-07-23, v1.0.1+57)

Latest verified sideload APK for Markus:
`Downloads\forditva-2026-07-23-feemargin-playpackage.apk` (v1.0.1+57, package
`hu.wirinungarn.forditva`, debug-key signed). Contains the fee margin + the new
package name. iOS +57 build path is the same commit.

## This session's work

All shipped to main and built on CI:

1. **PDF page picker (Image page).** `lib/widgets/pdf_page_selector.dart`
   (`PdfPageSelectorDialog`). A **modal** over the dimmed Image page that renders
   each PDF page to a thumbnail with **`pdfx`** (iOS PDFKit / Android
   PdfRenderer, rendered serially — Android can't render pages in parallel), and
   the user ticks pages with a corner checkbox. Assets:
   `assets/png24/black/b_checkbox_checked|empty.png`, `b_arrow_left|right.png`.
   Selected pages collapse to a spec ("1-3,5") fed to the existing Gemini prompt.
   Replaced the old "type a page number" dialog.
2. **"No matching text found" message.** When Gemini returns an empty result
   (found no text in the selected source language) the app now says to check the
   source language, instead of the misleading "image not clear". Note: the test
   PDF Markus reported (`Hungarian-Contemporary-001-009.pdf`) is **English text
   about Hungarian art**, so selecting Hungarian correctly finds nothing — not a
   bug.
3. **+30% translation fee margin.** `lib/services/gemini_cost.dart` — a
   `feeMargin = 1.30` multiplier on the real per-token cost (Markus: stay covered
   on fees even if the estimate runs low). Applies to text + image translation
   (both bill through `geminiWiuCost`); TTS bills separately and did NOT get it.
   Locked in by `test/gemini_cost_test.dart`.
4. **Play Store prep.** New package name + upload signing + `android-aab.yml`
   (see above). AAB build validated on CI.

## Open / blocked tasks (from the 17-22 Jul Telegram export)

- **Forditva → Play Store: BLOCKED on Markus.** He must open the Play Console
  ($25, Personal account, identity verification ~1-2 days), add Kayode's Google
  email as Admin, and send 12 tester emails for the mandatory 14-day closed
  test. Then: build the store listing (German short + long description — Kayode
  drafts), upload the .aab (`android-aab.yml` artifact), content rating +
  data-safety forms, start the closed test. Privacy policy already exists:
  wir-in-ungarn.hu/datenschutz-forditva.
- **wir-in-ungarn scheduling + video-call confirmation email** (regio.is,
  Shahin's WordPress side): finish the scheduler and make the confirmation email
  actually send to the user when Markus schedules a video meeting.
- **URL Shortener** — new project. Python backend (PostgreSQL) + Next.js
  frontend; framework TBD (FastAPI vs Flask). Markus is generating a base with
  AI; review before modifying.
- **"tudva"** — new project. A discussion platform for the wir-in-ungarn
  community: users post/discuss in their own language (DE/HU/EN) and each sees
  every message translated into their own language in parallel columns; tasks
  get generated out of the discussions. Markus will spec it.
- **TTS fee margin** — the +30% was applied to translation/image only. Ask
  Markus if he wants it on TTS too (one-line change in `gemini_tts_service.dart`).

## Client & workflow notes

- Markus relays feedback via Telegram text, transcribed **voice notes** (German,
  sometimes English), and **screenshots**. Voice notes are transcribed with
  Google STT using `GOOGLE_STT_KEY`. Telegram exports land in
  `C:\Users\KAYODE SOLIU\Downloads\Telegram Desktop\`.
- **Do not overpromise.** Markus has been burned by vague "soon" timelines.
  Give honest, specific status.
- Asset rule (emphatic): resizing his supplied assets is fine, but **never change
  their shape** (flags stay square-with-rounded-corners, never round).
- Established loop per change: find root cause in code (don't guess) → fix
  surgically → `flutter analyze` (clean) → bump `pubspec.yaml` build number →
  push (CI builds) → verify APK signature → rename into Downloads → report both
  Android + iOS results.

## Writing style

Prose the client sees (messages, commit messages, docs): no em dashes, active
voice, specific, no filler. See the user's global stop-slop rules.
