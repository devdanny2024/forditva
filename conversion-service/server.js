// Forditva document-conversion service.
//
// Converts DOC/DOCX/XLS/XLSX/ODT/ODS/TXT to PDF via headless LibreOffice, so
// the Flutter app can feed the result through the same PDF path it already
// uses for Gemini (which only accepts images and PDF via inline_data).
//
// Every request must carry a valid Firebase App Check token (Play Integrity
// on Android, App Attest on iOS) in the X-Firebase-AppCheck header — this
// proves the request comes from a genuine, unmodified install of the app,
// no bundled static API key involved (Markus, 2026-08: "we should not use a
// bundled static API key... I prefer the properly secure solution").
//
// Setup needed before this can verify tokens: a real Firebase project
// (matching lib/firebase_options.dart on the Flutter side) and a service
// account. Point GOOGLE_APPLICATION_CREDENTIALS at that service account's
// JSON key file, or run this on infrastructure with Application Default
// Credentials already available (e.g. GCP). See
// https://firebase.google.com/docs/app-check/custom-resource-backend
import express from "express";
import multer from "multer";
import rateLimit from "express-rate-limit";
import fs from "fs/promises";
import os from "os";
import path from "path";
import { pathToFileURL } from "url";
import { execFile } from "child_process";
import { promisify } from "util";
import admin from "firebase-admin";

const execFileAsync = promisify(execFile);

admin.initializeApp();

const app = express();

const port = process.env.PORT || 8080;
// Markus, 2026-08: "Please use a maximum upload size of 4 MB per file
// initially. That should be sufficient... keeps conversion time, server
// load, and abuse risk under control."
const maxFileSizeBytes = 4 * 1024 * 1024;

const allowedExtensions = new Set([
  ".doc",
  ".docx",
  ".xls",
  ".xlsx",
  ".odt",
  ".ods",
  ".txt",
]);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: maxFileSizeBytes,
  },
});

// Strict per-IP rate limiting, on top of App Check auth (Markus, 2026-08:
// "Play Integrity API... together with strict server-side rate limiting").
// Tune once real traffic patterns are known.
const conversionLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many conversion requests. Please try again later." },
});

function getSafeFileName(originalName) {
  const baseName = path.basename(originalName || "document");
  return baseName.replace(/[^a-zA-Z0-9._-]/g, "_");
}

/// Verifies the Firebase App Check token on every /convert-to-pdf request.
/// Rejects with 401 if missing or invalid — this is the entire auth
/// mechanism, there is no bundled API key to check instead.
async function requireAppCheck(req, res, next) {
  const token = req.header("X-Firebase-AppCheck");
  if (!token) {
    return res.status(401).json({ error: "Missing App Check token." });
  }
  try {
    await admin.appCheck().verifyToken(token);
    next();
  } catch (error) {
    console.error("App Check verification failed:", error.message);
    return res.status(401).json({ error: "Invalid App Check token." });
  }
}

app.get("/health", (_, res) => {
  res.json({ status: "ok" });
});

app.post(
  "/convert-to-pdf",
  conversionLimiter,
  requireAppCheck,
  upload.single("file"),
  async (req, res) => {
    let tempDirectory;

    try {
      if (!req.file) {
        return res.status(400).json({ error: "No file was uploaded." });
      }

      const safeFileName = getSafeFileName(req.file.originalname);
      const extension = path.extname(safeFileName).toLowerCase();

      if (!allowedExtensions.has(extension)) {
        return res.status(400).json({
          error: `Unsupported file type: ${extension || "unknown"}`,
        });
      }

      tempDirectory = await fs.mkdtemp(
        path.join(os.tmpdir(), "document-conversion-")
      );

      const inputDirectory = path.join(tempDirectory, "input");
      const outputDirectory = path.join(tempDirectory, "output");
      // A dedicated profile directory per conversion avoids LibreOffice
      // profile-locking problems when several conversions run at once.
      const profileDirectory = path.join(tempDirectory, "lo-profile");

      await fs.mkdir(inputDirectory);
      await fs.mkdir(outputDirectory);
      await fs.mkdir(profileDirectory);

      const inputPath = path.join(inputDirectory, safeFileName);
      await fs.writeFile(inputPath, req.file.buffer);

      await execFileAsync(
        "soffice",
        [
          "--headless",
          `-env:UserInstallation=${pathToFileURL(profileDirectory).href}`,
          "--convert-to",
          "pdf",
          "--outdir",
          outputDirectory,
          inputPath,
        ],
        {
          timeout: 60000,
          maxBuffer: 1024 * 1024,
        }
      );

      const expectedPdfName = `${path.basename(safeFileName, extension)}.pdf`;

      const pdfPath = path.join(outputDirectory, expectedPdfName);
      const pdfBytes = await fs.readFile(pdfPath);

      res.setHeader("Content-Type", "application/pdf");
      res.setHeader(
        "Content-Disposition",
        `attachment; filename="${path.basename(expectedPdfName)}"`
      );

      return res.send(pdfBytes);
    } catch (error) {
      console.error("Document conversion failed:", error);

      return res.status(500).json({
        error: "Document conversion failed.",
      });
    } finally {
      // Delete the original document and generated PDF immediately after
      // processing — nothing user-uploaded persists on this server.
      if (tempDirectory) {
        await fs.rm(tempDirectory, { recursive: true, force: true });
      }
    }
  }
);

app.listen(port, () => {
  console.log(`Conversion service listening on port ${port}`);
});
