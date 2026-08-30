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
  paymentMethod?: string | null;
  voided?: boolean;
  createdAt: Timestamp;
}

interface DaySummary {
  total: number;
  revenue: number;
  cashRevenue: number;
  upiRevenue: number;
  unknownRevenue: number;
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

function labelPaymentMethod(paid: boolean, method?: string | null): string {
  if (!paid) return "";
  if (method === "cash") return "Cash";
  if (method === "upi") return "UPI";
  return "Unknown";
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
  let cashRevenue = 0;
  let upiRevenue = 0;
  let unknownRevenue = 0;
  let unpaid = 0;
  const byType: Record<string, number> = {};
  const byPackage: Record<string, number> = {};

  snap.docs.forEach((d) => {
    const v = d.data() as Visit;
    if (v.voided) return; // skip voided — filter client-side to avoid compound index
    if (v.paid) {
      revenue += v.amount;
      if (v.paymentMethod === "cash") cashRevenue += v.amount;
      else if (v.paymentMethod === "upi") upiRevenue += v.amount;
      else unknownRevenue += v.amount;
    } else {
      unpaid += v.amount;
    }
    byType[v.vehicleType] = (byType[v.vehicleType] ?? 0) + 1;
    byPackage[v.packageId] = (byPackage[v.packageId] ?? 0) + 1;
  });

  const total = Object.values(byType).reduce((a, b) => a + b, 0);
  return { total, revenue, cashRevenue, upiRevenue, unknownRevenue, unpaid, byType, byPackage };
}

function buildEmailHtml(summary: DaySummary, dateLabel: string): string {
  // NOTE: Gmail strips <style> and @media entirely, so every style must be
  // inline and naturally fluid (% widths, small padding, word-break).

  const dataRowStyle =
    "padding:10px 12px;color:#FAFAF8;border-bottom:1px solid #2A2420;" +
    "word-break:break-word;";
  const countCellStyle =
    "padding:10px 12px;text-align:right;font-weight:700;color:#C9952A;" +
    "border-bottom:1px solid #2A2420;white-space:nowrap;width:36px;";

  const typeRows = Object.entries(summary.byType)
    .map(([k, v]) =>
      `<tr><td style="${dataRowStyle}">${labelType(k)}</td>` +
      `<td style="${countCellStyle}">${v}</td></tr>`
    )
    .join("");

  const pkgRows = Object.entries(summary.byPackage)
    .map(([k, v]) =>
      `<tr><td style="${dataRowStyle}">${labelPkg(k)}</td>` +
      `<td style="${countCellStyle}">${v}</td></tr>`
    )
    .join("");

  const kpis = [
    { label: "VEHICLES", value: `${summary.total}`, color: "#FAFAF8", size: "30px" },
    { label: "REVENUE", value: formatINR(summary.revenue), color: "#10B981", size: "24px" },
    { label: "CASH", value: formatINR(summary.cashRevenue), color: "#10B981", size: "20px" },
    { label: "UPI", value: formatINR(summary.upiRevenue), color: "#C9952A", size: "20px" },
    ...(summary.unknownRevenue > 0
      ? [{ label: "UNKNOWN", value: formatINR(summary.unknownRevenue), color: "#9C9489", size: "20px" }]
      : []),
    { label: "PENDING", value: formatINR(summary.unpaid), color: "#F43F5E", size: "20px" },
  ];

  // Each KPI is its own full-width row — no columns that can overflow.
  const kpiRows = kpis
    .map((k) =>
      `<tr><td style="padding:0 0 10px;">` +
        `<table width="100%" cellpadding="0" cellspacing="0" style="background:#0F0E0D;border-radius:10px;border:1px solid #3A322A;">` +
          `<tr><td style="padding:14px 16px;">` +
            `<div style="font-size:10px;color:#9C9489;letter-spacing:1.5px;text-transform:uppercase;margin-bottom:4px;">${k.label}</div>` +
            `<div style="font-size:${k.size};line-height:1.2;font-weight:800;color:${k.color};word-break:break-word;">${k.value}</div>` +
          `</td></tr>` +
        `</table>` +
      `</td></tr>`
    )
    .join("");

  const sectionLabel = (text: string) =>
    `<div style="font-size:10px;color:#9C9489;letter-spacing:1.5px;text-transform:uppercase;` +
    `margin-bottom:8px;padding:0 2px;">${text}</div>`;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <meta name="x-apple-disable-message-reformatting"/>
</head>
<body style="margin:0;padding:0;background:#0F0E0D;font-family:Arial,sans-serif;-webkit-text-size-adjust:100%;mso-line-height-rule:exactly;">

  <!-- outer wrapper -->
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#0F0E0D;">
    <tr><td align="center" style="padding:24px 12px;">

      <!-- card -->
      <table width="100%" cellpadding="0" cellspacing="0"
             style="max-width:520px;background:#1C1917;border-radius:16px;border:1px solid #3A322A;overflow:hidden;">

        <!-- header -->
        <tr><td style="background:#0F0E0D;padding:22px 20px;border-bottom:3px solid #C9952A;">
          <table cellpadding="0" cellspacing="0">
            <tr>
              <td style="width:10px;vertical-align:top;padding-right:10px;">
                <div style="width:5px;height:28px;background:#C9952A;border-radius:3px;"></div>
              </td>
              <td>
                <div style="font-size:10px;letter-spacing:2px;color:#9C9489;text-transform:uppercase;margin-bottom:3px;">End of Day Report</div>
                <div style="font-size:18px;font-weight:800;">
                  <span style="color:#FAFAF8;">LUXURY </span><span style="color:#C9952A;">CAR CARE</span>
                </div>
              </td>
            </tr>
          </table>
          <div style="margin-top:6px;font-size:12px;color:#9C9489;">${dateLabel}</div>
        </td></tr>

        <!-- body -->
        <tr><td style="padding:20px 20px 0;">

          <!-- KPI cards (single column) -->
          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
            ${kpiRows}
          </table>

          <!-- By Package -->
          ${sectionLabel("By Package")}
          <table width="100%" cellpadding="0" cellspacing="0"
                 style="background:#0F0E0D;border-radius:8px;border:1px solid #2A2420;margin-bottom:16px;table-layout:fixed;">
            ${pkgRows || `<tr><td style="padding:12px;color:#5C5751;">No data</td></tr>`}
          </table>

          <!-- By Vehicle Type -->
          ${sectionLabel("By Vehicle Type")}
          <table width="100%" cellpadding="0" cellspacing="0"
                 style="background:#0F0E0D;border-radius:8px;border:1px solid #2A2420;margin-bottom:20px;table-layout:fixed;">
            ${typeRows || `<tr><td style="padding:12px;color:#5C5751;">No data</td></tr>`}
          </table>

          <!-- CTA -->
          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
            <tr><td align="center">
              <a href="https://wash.sindhole.com"
                 style="display:inline-block;padding:12px 28px;background:#C9952A;color:#0F0E0D;font-weight:700;font-size:13px;letter-spacing:0.5px;border-radius:8px;text-decoration:none;">
                View Full Dashboard &#8594;
              </a>
              <div style="margin-top:6px;font-size:11px;color:#5C5751;">wash.sindhole.com</div>
            </td></tr>
          </table>

        </td></tr>

        <!-- footer -->
        <tr><td style="padding:14px 20px;border-top:1px solid #2A2420;font-size:12px;color:#5C5751;">
          <div style="margin-bottom:3px;">Luxury Car Care · Auto-generated report</div>
          <div style="color:#C9952A;">Bidar, Karnataka</div>
        </td></tr>

      </table>
    </td></tr>
  </table>

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

  // Build CSV attachment from today's visits
  const snap = await db
    .collection("visits")
    .where("createdAt", ">=", Timestamp.fromDate(dayStart))
    .where("createdAt", "<", Timestamp.fromDate(dayEnd))
    .orderBy("createdAt")
    .get();

  const csvRows: string[][] = [
    ["Date", "Time", "Plate", "Vehicle", "Package", "Amount", "Paid", "Paid by"],
  ];
  snap.docs.forEach((d) => {
    const v = d.data() as Visit;
    if (v.voided) return;
    const dt = v.createdAt.toDate();
    csvRows.push([
      dt.toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" }),
      dt.toLocaleTimeString("en-IN", { timeZone: "Asia/Kolkata", hour: "2-digit", minute: "2-digit" }),
      v.plate,
      labelType(v.vehicleType),
      labelPkg(v.packageId),
      String(v.amount),
      v.paid ? "Yes" : "No",
      labelPaymentMethod(v.paid, v.paymentMethod),
    ]);
  });
  const csvContent = csvRows.map((row) => row.map((cell) => `"${cell.replace(/"/g, '""')}"`).join(",")).join("\n");
  const csvBase64 = Buffer.from(csvContent, "utf-8").toString("base64");
  const csvFilename = `lcc-report-${dayStart.toLocaleDateString("en-CA", { timeZone: "Asia/Kolkata" })}.csv`;

  const fromAddress = process.env.RESEND_FROM ?? "Luxury Car Care <wash@sindhole.com>";

  const resend = new Resend(apiKey);
  const { error } = await resend.emails.send({
    from: fromAddress,
    to: ownerEmails,
    subject: `Luxury Car Care — ${summary.total} washes · ${dateLabel}`,
    html: buildEmailHtml(summary, dateLabel),
    attachments: [
      {
        filename: csvFilename,
        content: csvBase64,
      },
    ],
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
