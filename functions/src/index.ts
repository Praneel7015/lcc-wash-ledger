import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Resend } from "resend";

admin.initializeApp();
const db = admin.firestore();

// ── Types ─────────────────────────────────────────────────────────────────────

interface Visit {
  plate: string;
  vehicleType: string;
  packageId: string;
  amount: number;
  paid: boolean;
  createdAt: admin.firestore.Timestamp;
}

interface DaySummary {
  total: number;
  revenue: number;
  unpaid: number;
  byType: Record<string, number>;
  byPackage: Record<string, number>;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function formatINR(n: number): string {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(n);
}

function labelType(t: string): string {
  return { hatchSedan: "Hatch/Sedan", suv: "SUV", bike: "Bike" }[t] ?? t;
}

function labelPkg(p: string): string {
  return (
    { exterior: "Exterior", interior: "Interior", full: "Full Wash", wax: "Wax" }[p] ?? p
  );
}

async function computeSummary(dayStart: Date, dayEnd: Date): Promise<DaySummary> {
  const snap = await db
    .collection("visits")
    .where("voided", "!=", true)
    .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(dayStart))
    .where("createdAt", "<", admin.firestore.Timestamp.fromDate(dayEnd))
    .get();

  let revenue = 0;
  let unpaid = 0;
  const byType: Record<string, number> = {};
  const byPackage: Record<string, number> = {};

  snap.docs.forEach((d) => {
    const v = d.data() as Visit;
    if (v.paid) revenue += v.amount;
    else unpaid += v.amount;
    byType[v.vehicleType] = (byType[v.vehicleType] ?? 0) + 1;
    byPackage[v.packageId] = (byPackage[v.packageId] ?? 0) + 1;
  });

  return { total: snap.size, revenue, unpaid, byType, byPackage };
}

function buildEmailHtml(summary: DaySummary, dateLabel: string): string {
  const typeRows = Object.entries(summary.byType)
    .map(
      ([k, v]) =>
        `<tr><td style="padding:6px 12px;">${labelType(k)}</td><td style="padding:6px 12px;text-align:right;font-weight:bold;">${v}</td></tr>`
    )
    .join("");

  const pkgRows = Object.entries(summary.byPackage)
    .map(
      ([k, v]) =>
        `<tr><td style="padding:6px 12px;">${labelPkg(k)}</td><td style="padding:6px 12px;text-align:right;font-weight:bold;">${v}</td></tr>`
    )
    .join("");

  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"/></head>
<body style="font-family:'Helvetica Neue',Arial,sans-serif;background:#0D0F14;color:#EDF0F7;margin:0;padding:0;">
  <div style="max-width:520px;margin:32px auto;background:#161A22;border-radius:16px;overflow:hidden;border:1px solid #252B38;">
    <div style="background:#FFD60A;padding:24px 28px;">
      <h1 style="margin:0;color:#0D0F14;font-size:24px;font-weight:700;">WashLog — End of Day</h1>
      <p style="margin:4px 0 0;color:#0D0F14;opacity:0.7;font-size:14px;">${dateLabel}</p>
    </div>
    <div style="padding:28px;">
      <div style="display:flex;gap:16px;margin-bottom:24px;">
        <div style="flex:1;background:#0D0F14;border-radius:10px;padding:16px;border:1px solid #252B38;">
          <div style="font-size:12px;color:#8A92A6;margin-bottom:4px;">Total vehicles</div>
          <div style="font-size:32px;font-weight:700;">${summary.total}</div>
        </div>
        <div style="flex:1;background:#0D0F14;border-radius:10px;padding:16px;border:1px solid #252B38;">
          <div style="font-size:12px;color:#8A92A6;margin-bottom:4px;">Revenue</div>
          <div style="font-size:28px;font-weight:700;color:#22C55E;">${formatINR(summary.revenue)}</div>
        </div>
        ${
          summary.unpaid > 0
            ? `<div style="flex:1;background:#0D0F14;border-radius:10px;padding:16px;border:1px solid #252B38;">
          <div style="font-size:12px;color:#8A92A6;margin-bottom:4px;">Unpaid</div>
          <div style="font-size:28px;font-weight:700;color:#EF4444;">${formatINR(summary.unpaid)}</div>
        </div>`
            : ""
        }
      </div>
      <h3 style="color:#8A92A6;font-size:12px;text-transform:uppercase;letter-spacing:1px;margin:0 0 8px;">By vehicle type</h3>
      <table style="width:100%;border-collapse:collapse;background:#0D0F14;border-radius:8px;margin-bottom:20px;">
        ${typeRows || "<tr><td colspan='2' style='padding:12px;color:#4A5166;'>No data</td></tr>"}
      </table>
      <h3 style="color:#8A92A6;font-size:12px;text-transform:uppercase;letter-spacing:1px;margin:0 0 8px;">By package</h3>
      <table style="width:100%;border-collapse:collapse;background:#0D0F14;border-radius:8px;">
        ${pkgRows || "<tr><td colspan='2' style='padding:12px;color:#4A5166;'>No data</td></tr>"}
      </table>
    </div>
    <div style="padding:16px 28px;border-top:1px solid #252B38;font-size:12px;color:#4A5166;">
      WashLog · Auto-generated report. Log in to the dashboard for more.
    </div>
  </div>
</body>
</html>`;
}

async function sendDayEmail(dayStart: Date, dayEnd: Date): Promise<void> {
  const settingsDoc = await db.collection("settings").doc("app").get();
  const settings = settingsDoc.data() ?? {};
  const ownerEmail: string = settings.ownerEmail ?? "";
  if (!ownerEmail) {
    functions.logger.warn("No owner email in settings — skipping day email.");
    return;
  }

  const summary = await computeSummary(dayStart, dayEnd);
  if (summary.total === 0) {
    functions.logger.info("No visits today — skipping email.");
    return;
  }

  const dateLabel = dayStart.toLocaleDateString("en-IN", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "Asia/Kolkata",
  });

  const apiKey = process.env.RESEND_API_KEY ?? "";
  if (!apiKey) {
    functions.logger.error("RESEND_API_KEY not set in functions/.env.wash-ledgar — cannot send email.");
    return;
  }

  const fromAddress = process.env.RESEND_FROM ?? "WashLog <reports@sindhole.com>";

  const resend = new Resend(apiKey);
  const { error } = await resend.emails.send({
    from: fromAddress,
    to: ownerEmail,
    subject: `WashLog — ${summary.total} washes · ${dateLabel}`,
    html: buildEmailHtml(summary, dateLabel),
  });

  if (error) {
    functions.logger.error("Resend error:", error);
    throw new Error(error.message);
  }

  functions.logger.info(`Day email sent to ${ownerEmail} — ${summary.total} visits`);
}

// ── Scheduled: runs at 9:30pm IST (16:00 UTC) every day ──────────────────────

export const scheduledDayClose = functions.pubsub
  .schedule("0 16 * * *")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const istMidnight = new Date(
      new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Kolkata" }) + "T00:00:00+05:30"
    );
    await sendDayEmail(istMidnight, new Date());
  });

// ── Manual trigger: owner taps "Close day" in the app ────────────────────────

export const manualDayClose = functions.firestore
  .document("emailTasks/{id}")
  .onCreate(async (snap) => {
    const data = snap.data();
    if (data.type !== "closeDay") return;
    const istMidnight = new Date(
      new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Kolkata" }) + "T00:00:00+05:30"
    );
    await sendDayEmail(istMidnight, new Date());
    await snap.ref.update({ status: "done" });
  });

// ── Storage lifecycle: delete photos older than 90 days ──────────────────────

export const cleanOldPhotos = functions.pubsub
  .schedule("0 2 * * *")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
    const snap = await db
      .collection("visits")
      .where("createdAt", "<", admin.firestore.Timestamp.fromDate(cutoff))
      .select("platePhotoUrl", "frontPhotoUrl")
      .get();

    const bucket = admin.storage().bucket();
    let deleted = 0;
    for (const doc of snap.docs) {
      const data = doc.data();
      for (const field of ["platePhotoUrl", "frontPhotoUrl"] as const) {
        const url: string | undefined = data[field];
        if (!url) continue;
        try {
          const match = url.match(/\/o\/(.+?)\?/);
          if (!match) continue;
          await bucket.file(decodeURIComponent(match[1])).delete();
          deleted++;
        } catch {
          // File already deleted — ignore
        }
      }
    }
    functions.logger.info(`Cleaned ${deleted} old photos`);
  });
