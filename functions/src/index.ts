import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { Resend } from "resend";

initializeApp();
const db = getFirestore();

// ── Types ─────────────────────────────────────────────────────────────────────

interface Visit {
  plate: string;
  vehicleType: string;
  packageId: string;
  amount: number;
  paid: boolean;
  voided?: boolean;
  createdAt: Timestamp;
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
  return (
    {
      hatch_sedan: "Hatch / Sedan",
      suv: "SUV",
      bike: "Bike",
    }[t] ?? t
  );
}

function labelPkg(p: string): string {
  return (
    {
      exterior: "Express Exterior Wash",
      full: "Exterior + Interior Wash",
      underbody: "Exterior + Interior + Under Body",
      detailing: "Full Detailing",
      bike_wash: "Express Bike Wash",
    }[p] ?? p
  );
}

async function computeSummary(dayStart: Date, dayEnd: Date): Promise<DaySummary> {
  const snap = await db
    .collection("visits")
    .where("createdAt", ">=", Timestamp.fromDate(dayStart))
    .where("createdAt", "<", Timestamp.fromDate(dayEnd))
    .get();

  let revenue = 0;
  let unpaid = 0;
  const byType: Record<string, number> = {};
  const byPackage: Record<string, number> = {};

  snap.docs.forEach((d) => {
    const v = d.data() as Visit;
    if (v.voided) return; // skip voided — filter client-side to avoid compound index
    if (v.paid) revenue += v.amount;
    else unpaid += v.amount;
    byType[v.vehicleType] = (byType[v.vehicleType] ?? 0) + 1;
    byPackage[v.packageId] = (byPackage[v.packageId] ?? 0) + 1;
  });

  const total = Object.values(byType).reduce((a, b) => a + b, 0);
  return { total, revenue, unpaid, byType, byPackage };
}

function buildEmailHtml(summary: DaySummary, dateLabel: string): string {
  const typeRows = Object.entries(summary.byType)
    .map(
      ([k, v]) =>
        `<tr><td style="padding:8px 14px;color:#FAFAF8;border-bottom:1px solid #2A2420;word-break:break-word;white-space:normal;">${labelType(k)}</td><td style="padding:8px 14px;text-align:right;font-weight:700;color:#C9952A;border-bottom:1px solid #2A2420;white-space:nowrap;">${v}</td></tr>`
    )
    .join("");

  const pkgRows = Object.entries(summary.byPackage)
    .map(
      ([k, v]) =>
        `<tr><td style="padding:8px 14px;color:#FAFAF8;border-bottom:1px solid #2A2420;word-break:break-word;white-space:normal;">${labelPkg(k)}</td><td style="padding:8px 14px;text-align:right;font-weight:700;color:#C9952A;border-bottom:1px solid #2A2420;white-space:nowrap;">${v}</td></tr>`
    )
    .join("");

  const kpiRows = [
    {
      label: "Vehicles",
      value: `${summary.total}`,
      valueColor: "#FAFAF8",
      valueSize: "32px",
    },
    {
      label: "Revenue",
      value: formatINR(summary.revenue),
      valueColor: "#10B981",
      valueSize: "24px",
    },
    ...(summary.unpaid > 0
      ? [
          {
            label: "Pending",
            value: formatINR(summary.unpaid),
            valueColor: "#F43F5E",
            valueSize: "24px",
          },
        ]
      : []),
  ]
    .map(
      (card) => `
      <tr>
        <td style="padding:0 0 12px;">
          <div style="background:#0F0E0D;border-radius:10px;padding:14px 16px;border:1px solid #3A322A;">
            <div style="font-size:11px;color:#9C9489;letter-spacing:1px;text-transform:uppercase;margin-bottom:6px;">${card.label}</div>
            <div style="font-size:${card.valueSize};line-height:1.2;font-weight:800;color:${card.valueColor};word-break:break-word;white-space:normal;">${card.value}</div>
          </div>
        </td>
      </tr>`
    )
    .join("");

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <style>
    @media only screen and (max-width: 600px) {
      .mail-wrap {
        padding: 16px 8px !important;
      }
      .mail-card {
        border-radius: 12px !important;
      }
      .mail-header,
      .mail-body,
      .mail-footer {
        padding-left: 16px !important;
        padding-right: 16px !important;
      }
      .mail-title {
        font-size: 17px !important;
      }
    }
  </style>
</head>
<body style="font-family:'Inter',Arial,sans-serif;background:#0F0E0D;color:#FAFAF8;margin:0;padding:0;">
  <div class="mail-wrap" style="padding:32px 16px;">
  <div class="mail-card" style="max-width:520px;margin:0 auto;background:#1C1917;border-radius:16px;overflow:hidden;border:1px solid #3A322A;">

    <!-- Header bar -->
    <div class="mail-header" style="background:#0F0E0D;padding:28px 32px;border-bottom:3px solid #C9952A;">
      <table role="presentation" style="border-collapse:collapse;">
        <tr>
          <td style="width:14px;vertical-align:top;padding-right:8px;">
            <div style="width:6px;height:32px;background:#C9952A;border-radius:3px;"></div>
          </td>
          <td style="vertical-align:top;">
            <div style="font-size:11px;letter-spacing:2px;color:#9C9489;text-transform:uppercase;margin-bottom:2px;">End of Day Report</div>
            <div class="mail-title" style="font-size:20px;font-weight:800;letter-spacing:0.5px;">
              <span style="color:#FAFAF8;">LUXURY </span><span style="color:#C9952A;">CAR CARE</span>
            </div>
          </td>
        </tr>
      </table>
      <div style="margin-top:8px;font-size:13px;color:#9C9489;">${dateLabel}</div>
    </div>

    <!-- KPI strip -->
    <div class="mail-body" style="padding:24px 32px 0;">
      <table role="presentation" style="width:100%;border-collapse:collapse;margin-bottom:12px;">
        ${kpiRows}
      </table>

      <!-- By package (shown first) -->
      <div style="font-size:11px;color:#9C9489;letter-spacing:1.5px;text-transform:uppercase;margin-bottom:8px;">By Package</div>
      <table style="width:100%;border-collapse:collapse;background:#0F0E0D;border-radius:8px;margin-bottom:20px;border:1px solid #2A2420;table-layout:fixed;">
        ${pkgRows || "<tr><td colspan='2' style='padding:12px 14px;color:#5C5751;'>No data</td></tr>"}
      </table>

      <!-- By vehicle type -->
      <div style="font-size:11px;color:#9C9489;letter-spacing:1.5px;text-transform:uppercase;margin-bottom:8px;">By Vehicle Type</div>
      <table style="width:100%;border-collapse:collapse;background:#0F0E0D;border-radius:8px;margin-bottom:20px;border:1px solid #2A2420;table-layout:fixed;">
        ${typeRows || "<tr><td colspan='2' style='padding:12px 14px;color:#5C5751;'>No data</td></tr>"}
      </table>

      <!-- Dashboard CTA -->
      <div style="margin-bottom:24px;text-align:center;">
        <a href="https://wash.sindhole.com" style="display:inline-block;padding:12px 28px;background:#C9952A;color:#0F0E0D;font-weight:700;font-size:13px;letter-spacing:0.5px;border-radius:8px;text-decoration:none;">View Full Dashboard →</a>
        <div style="margin-top:8px;font-size:11px;color:#5C5751;">wash.sindhole.com</div>
      </div>
    </div>

    <!-- Footer -->
    <div class="mail-footer" style="padding:16px 32px;border-top:1px solid #2A2420;font-size:12px;color:#5C5751;">
      <div style="margin-bottom:4px;">Luxury Car Care · Auto-generated report</div>
      <div style="color:#C9952A;">Bidar, Karnataka</div>
    </div>
  </div>
  </div>
</body>
</html>`;
}

async function sendDayEmail(dayStart: Date, dayEnd: Date): Promise<void> {
  const settingsDoc = await db.collection("settings").doc("app").get();
  const settings = settingsDoc.data() ?? {};

  // ownerEmails can be a string, string[], or nested string[][] — flatten all cases
  const raw = settings.ownerEmails ?? settings.ownerEmail;
  let ownerEmails: string[] = [];
  if (Array.isArray(raw)) {
    ownerEmails = raw
      .flat(Infinity)
      .map((e: unknown) => String(e).trim())
      .filter(Boolean);
  } else if (typeof raw === "string" && raw.trim()) {
    ownerEmails = raw.split(",").map((e) => e.trim()).filter(Boolean);
  }

  if (ownerEmails.length === 0) {
    logger.warn("No owner email(s) in settings — skipping day email.");
    return;
  }

  const summary = await computeSummary(dayStart, dayEnd);
  if (summary.total === 0) {
    logger.info("No visits today — skipping email.");
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
    logger.error("RESEND_API_KEY not set — cannot send email.");
    return;
  }

  const fromAddress = process.env.RESEND_FROM ?? "Luxury Car Care <wash@sindhole.com>";

  const resend = new Resend(apiKey);
  const { error } = await resend.emails.send({
    from: fromAddress,
    to: ownerEmails,
    subject: `Luxury Car Care — ${summary.total} washes · ${dateLabel}`,
    html: buildEmailHtml(summary, dateLabel),
  });

  if (error) {
    logger.error("Resend error:", error);
    throw new Error(error.message);
  }

  logger.info(`Day email sent to ${ownerEmails.join(", ")} — ${summary.total} visits`);
}

function istMidnightToday(): Date {
  return new Date(
    new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Kolkata" }) + "T00:00:00+05:30"
  );
}

// ── Scheduled: runs at 9:30pm IST (16:00 UTC) every day ──────────────────────

export const scheduledDayClose = onSchedule(
  { schedule: "0 16 * * *", timeZone: "Asia/Kolkata" },
  async () => {
    await sendDayEmail(istMidnightToday(), new Date());
  }
);

// ── Manual trigger: owner taps "Close day" in the app ────────────────────────

export const manualDayClose = onDocumentCreated("emailTasks/{id}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data();
  if (data.type !== "closeDay") return;
  try {
    await sendDayEmail(istMidnightToday(), new Date());
    await snap.ref.update({ status: "done" });
  } catch (err) {
    await snap.ref.update({ status: "error", error: String(err) });
    throw err;
  }
});

// ── Storage lifecycle: delete photos older than 90 days ──────────────────────

export const cleanOldPhotos = onSchedule(
  { schedule: "0 2 * * *", timeZone: "Asia/Kolkata" },
  async () => {
    const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
    const snap = await db
      .collection("visits")
      .where("createdAt", "<", Timestamp.fromDate(cutoff))
      .select("platePhotoUrl", "frontPhotoUrl")
      .get();

    const bucket = getStorage().bucket();
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
    logger.info(`Cleaned ${deleted} old photos`);
  }
);
