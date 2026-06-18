import { Router, Request } from "express";
import { z } from "zod";
import { query } from "../db";

const router = Router();

const WINDOW_MS = 60_000;
const MAX_REQ = 30;
const ipHits = new Map<string, number[]>();

function clientIp(req: Request): string {
  const xf = req.headers["x-forwarded-for"];
  if (typeof xf === "string" && xf.length > 0) return xf.split(",")[0].trim();
  return req.socket.remoteAddress ?? "unknown";
}

function allowRateLimit(ip: string): boolean {
  const now = Date.now();
  const arr = (ipHits.get(ip) ?? []).filter((t) => now - t < WINDOW_MS);
  if (arr.length >= MAX_REQ) return false;
  arr.push(now);
  ipHits.set(ip, arr);
  return true;
}

const BodySchema = z.object({
  medicines: z.array(
    z.object({
      name: z.string().min(1),
      quantity: z.coerce.number().int().positive(),
    }),
  ),
  roshetta_code: z.string().optional(),
});

router.post("/public/check-prescription", async (req, res) => {
  const ip = clientIp(req);
  if (!allowRateLimit(ip)) {
    return res.status(429).json({ message: "Too many requests" });
  }

  const parsed = BodySchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Invalid request body" });
  }

  const { medicines: requested, roshetta_code } = parsed.data;
  const medicinesOut: Record<string, unknown>[] = [];

  try {
    for (const med of requested) {
      const r = await query(
        `SELECT medicine_id, trade_name, quantity_on_hand, pay_rate, discount_pct
         FROM medicines_inventory
         WHERE is_archived = false AND trade_name ILIKE $1
         ORDER BY LENGTH(trade_name) ASC
         LIMIT 1`,
        [`%${med.name.trim()}%`],
      );

      if (r.rows.length === 0) {
        medicinesOut.push({
          trade_name: med.name.trim(),
          requested: med.name.trim(),
          status: "NOT_FOUND",
          available: false,
          quantity_on_hand: 0,
          pay_rate: null,
          discount_pct: 0,
        });
        continue;
      }

      const row = r.rows[0] as {
        trade_name: string;
        quantity_on_hand: string | number;
        pay_rate: string | number;
        discount_pct: string | number;
      };

      const qty = Number(row.quantity_on_hand);
      const reqQ = med.quantity;
      let status: string;
      if (qty <= 0) status = "OUT_OF_STOCK";
      else if (qty < reqQ) status = "LOW_STOCK";
      else status = "AVAILABLE";

      medicinesOut.push({
        trade_name: row.trade_name,
        requested: med.name.trim(),
        status,
        available: status === "AVAILABLE",
        quantity_on_hand: qty,
        pay_rate: Number(row.pay_rate),
        discount_pct: Number(row.discount_pct),
      });
    }

    const all_available = medicinesOut.every((m) => m.status === "AVAILABLE");

    res.json({
      medicines: medicinesOut,
      all_available,
      roshetta_code: roshetta_code ?? null,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Server error" });
  }
});

export default router;