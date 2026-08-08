# Forditva document-conversion service

Converts DOC/DOCX/XLS/XLSX/ODT/ODS/TXT to PDF via headless LibreOffice, so
Forditva's Image page can feed the result through the existing PDF path
(page picker, then Gemini) instead of teaching Gemini new file types.

Deployed standalone — not part of the Flutter app's build or CI.

## Blocked on

- **A real Firebase project.** This service verifies every request's Firebase
  App Check token (`X-Firebase-AppCheck` header) using `firebase-admin`,
  which needs a service account. Point `GOOGLE_APPLICATION_CREDENTIALS` at
  that service account's JSON key, or run on infrastructure with Application
  Default Credentials already available. Matches `lib/firebase_options.dart`
  on the Flutter side — both need the same project.
- **Hosting.** Meant to run on the same server as `wiu.hu` / `wir-verify`
  (see Andy). Needs a subdomain (Markus's preference:
  `convert.wir-in-ungarn.hu`) and a port assigned.

## Build and run

```bash
npm install
docker build -t forditva-conversion-service .
docker run \
  --rm \
  -p 8080:8080 \
  --memory="1g" \
  --cpus="1.5" \
  -e GOOGLE_APPLICATION_CREDENTIALS=/secrets/service-account.json \
  -v /path/to/service-account.json:/secrets/service-account.json:ro \
  forditva-conversion-service
```

## API

```
POST /convert-to-pdf
Headers: X-Firebase-AppCheck: <token>
Form field: file
Response: application/pdf
```

```
GET /health
```

## Operational notes

- 4MB max upload size (Markus, 2026-08 — deliberately conservative for v1).
- Rate limited to 20 requests / 15 min per IP, on top of App Check auth.
  Tune once real traffic patterns are known.
- Each conversion gets its own temp directory and LibreOffice user profile
  (avoids profile-locking issues under concurrent load), deleted immediately
  after the response is sent — nothing user-uploaded persists here.
- Should run behind HTTPS in production (terminate TLS at the reverse proxy,
  e.g. NPM per Andy's existing setup for the other wir-in-ungarn services).
