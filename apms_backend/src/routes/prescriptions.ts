import { Router } from 'express';
import { query, pool } from '../db';
import { authenticateToken } from '../middleware/auth';
import { z } from 'zod';

const router = Router();

const CreatePrescriptionSchema = z.object({
  roshetta_code: z.string().optional().nullable(),
  patient_name: z.string().optional().nullable(),
  doctor_name: z.string().optional().nullable(),
  notes: z.string().optional().nullable(),
  items: z.array(
    z.object({
      medicine_id: z.coerce.number().int().optional().nullable(),
      quantity_prescribed: z.coerce.number().int().positive(),
      requested_name: z.string().optional().nullable(), // Captured from the app
    }),
  )
    .optional()
    .default([]),
});

const StatusSchema = z.object({
  status: z.enum(['PENDING', 'PARTIALLY_DISPENSED', 'COMPLETE', 'CANCELLED']),
});

// ── 1. PUBLIC ROUTE: Allowing mobile app to post prescriptions ──
router.post('/', async (req, res) => {
  const parsed = CreatePrescriptionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(422).json({ message: 'Validation error', issues: parsed.error.issues });
  }
  const data = parsed.data;
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');

    const created = await client.query(
      `INSERT INTO prescriptions (roshetta_code, patient_name, doctor_name, notes, status)
       VALUES ($1,$2,$3,$4,'PENDING')
       RETURNING *`,
      [data.roshetta_code ?? null, data.patient_name ?? null, data.doctor_name ?? null, data.notes ?? null],
    );

    const prescription = created.rows[0];

    for (const item of data.items) {
      const medId = item.medicine_id && Number(item.medicine_id) > 0 ? Number(item.medicine_id) : null;
      
      if (medId) {
        // Known medicine: Lock in the current cost and pay rate
        await client.query(
          `INSERT INTO prescription_items (
            prescription_id, medicine_id, quantity_prescribed, quantity_dispensed, status,
            pay_rate_at_sale, unit_cost_at_sale
          )
           SELECT $1, $2, $3, 0, 'PENDING', pay_rate, unit_cost
           FROM medicines_inventory WHERE medicine_id = $2`,
          [prescription.prescription_id, medId, item.quantity_prescribed],
        );
      } else {
        // ── 2. FIX: Save 'requested_name' so it doesn't show as Unknown ──
        await client.query(
          `INSERT INTO prescription_items (
            prescription_id, medicine_id, quantity_prescribed, quantity_dispensed, status,
            pay_rate_at_sale, unit_cost_at_sale, requested_name
          ) VALUES ($1, $2, $3, 0, 'PENDING', 0, 0, $4)`,
          [
            prescription.prescription_id, 
            medId, 
            item.quantity_prescribed, 
            item.requested_name // Inserts the manual text or OCR text here
          ],
        );
      }
    }

    await client.query('COMMIT');

    const full = await query(
      `SELECT p.*, COALESCE(json_agg(pi.* ORDER BY pi.pitem_id) FILTER (WHERE pi.pitem_id IS NOT NULL), '[]') as items
       FROM prescriptions p
       LEFT JOIN (
         SELECT pi.*, row_to_json(m.*) as medicine
         FROM prescription_items pi
         LEFT JOIN medicines_inventory m ON pi.medicine_id = m.medicine_id
       ) pi ON pi.prescription_id = p.prescription_id
       WHERE p.prescription_id = $1
       GROUP BY p.prescription_id`,
      [prescription.prescription_id],
    );

    res.status(201).json(full.rows[0]);
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error(error);
    const msg = typeof error?.message === 'string' ? error.message : 'Internal Server Error';
    if (msg.toLowerCase().includes('duplicate') || msg.toLowerCase().includes('unique')) {
      return res.status(409).json({ message: 'Duplicate roshetta_code' });
    }
    res.status(500).json({ message: 'Internal Server Error' });
  } finally {
    client.release();
  }
});


// ── 3. AUTHENTICATED ROUTES: Everything below requires a pharmacist token ──
router.use(authenticateToken);

router.get('/', async (req, res) => {
  try {
    const { status, page = '1', limit = '50' } = req.query;
    const offset = (Number(page) - 1) * Number(limit);
    
    let sql = `SELECT * FROM prescriptions WHERE 1=1`;
    const params: any[] = [];
    let paramIndex = 1;

    if (status) {
      sql += ` AND status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    }

    sql += ` ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(Number(limit), offset);

    const result = await query(sql, params);
    
    const prescriptions = [];
    for (const p of result.rows) {
      const itemsResult = await query(`
        SELECT pi.*, row_to_json(m.*) as medicine 
        FROM prescription_items pi
        LEFT JOIN medicines_inventory m ON pi.medicine_id = m.medicine_id
        WHERE pi.prescription_id = $1
      `, [p.prescription_id]);
      
      prescriptions.push({
        ...p,
        items: itemsResult.rows
      });
    }

    res.json({ data: prescriptions });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const pResult = await query(`SELECT * FROM prescriptions WHERE prescription_id = $1`, [id]);
    
    if (pResult.rows.length === 0) return res.status(404).json({ message: 'Not found' });
    
    const p = pResult.rows[0];
    const itemsResult = await query(`
      SELECT pi.*, row_to_json(m.*) as medicine 
      FROM prescription_items pi
      LEFT JOIN medicines_inventory m ON pi.medicine_id = m.medicine_id
      WHERE pi.prescription_id = $1
    `, [p.prescription_id]);

    res.json({
      ...p,
      items: itemsResult.rows
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.patch('/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const parsed = StatusSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(422).json({ message: 'Validation error', issues: parsed.error.issues });
    }
    const { status } = parsed.data;
    
    const result = await query(`
      UPDATE prescriptions
      SET status = $1
      WHERE prescription_id = $2
      RETURNING *
    `, [status, id]);

    if (result.rows.length === 0) return res.status(404).json({ message: 'Not found' });
    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

const LinkItemSchema = z.object({
  medicine_id: z.coerce.number().int().positive(),
});

// PATCH /api/prescriptions/items/:itemId/link
router.patch('/items/:itemId/link', async (req, res) => {
  try {
    const { itemId } = req.params;
    const parsed = LinkItemSchema.safeParse(req.body);
    
    if (!parsed.success) {
      return res.status(422).json({ message: 'Validation error', issues: parsed.error.issues });
    }
    const { medicine_id } = parsed.data;

    const medResult = await query(
      `SELECT unit_cost, pay_rate FROM medicines_inventory WHERE medicine_id = $1`,
      [medicine_id]
    );

    if (medResult.rows.length === 0) {
      return res.status(404).json({ message: 'Medicine not found in inventory' });
    }

    const { unit_cost, pay_rate } = medResult.rows[0];

    const updateResult = await query(`
      UPDATE prescription_items
      SET medicine_id = $1,
          unit_cost_at_sale = $2,
          pay_rate_at_sale = $3
      WHERE pitem_id = $4
      RETURNING *
    `, [medicine_id, unit_cost, pay_rate, itemId]);

    if (updateResult.rows.length === 0) {
      return res.status(404).json({ message: 'Prescription item not found' });
    }

    res.json(updateResult.rows[0]);
  } catch (error) {
    console.error('Error linking medicine:', error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await query(`DELETE FROM prescriptions WHERE prescription_id = $1`, [req.params.id]);
    res.json({ message: 'Prescription deleted' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.post('/:id/checkout', async (req, res) => {
  const { id } = req.params;
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');

    // FIX: Validate stock levels and expiry before progressing
    const checkRes = await client.query(`
      SELECT pi.quantity_prescribed, m.quantity_on_hand, m.expiration_date, m.trade_name
      FROM prescription_items pi
      JOIN medicines_inventory m ON pi.medicine_id = m.medicine_id
      WHERE pi.prescription_id = $1
    `, [id]);

    for (const item of checkRes.rows) {
      if (item.quantity_on_hand < item.quantity_prescribed) {
         throw new Error(`Insufficient stock for ${item.trade_name}. Needed: ${item.quantity_prescribed}, On hand: ${item.quantity_on_hand}.`);
      }
      if (new Date(item.expiration_date) < new Date()) {
         throw new Error(`Cannot checkout: ${item.trade_name} has expired.`);
      }
    }

    await client.query(`
      UPDATE prescriptions 
      SET status = 'COMPLETE' 
      WHERE prescription_id = $1 AND status != 'COMPLETE'
    `, [id]);

    await client.query(`
      UPDATE prescription_items
      SET quantity_dispensed = quantity_prescribed
      WHERE prescription_id = $1
    `, [id]);

    await client.query(`
      UPDATE medicines_inventory m
      SET quantity_on_hand = m.quantity_on_hand - pi.quantity_dispensed
      FROM prescription_items pi
      WHERE m.medicine_id = pi.medicine_id AND pi.prescription_id = $1
    `, [id]);

    await client.query('COMMIT');
    res.json({ message: 'Checkout successful, inventory updated.' });
    
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error(error);
    const msg = typeof error?.message === 'string' ? error.message : 'Internal Server Error during checkout';
    res.status(400).json({ message: msg });
  } finally {
    client.release();
  }
});
// 🌟 Fuzzy Search for Typo Correction
router.get('/fuzzy-search', async (req, res) => {
  try {
    const { term } = req.query;
    if (!term) return res.json([]);

    // This query calculates the similarity score (0 to 1) and returns the best matches
    const result = await query(`
      SELECT 
        medicine_id, 
        trade_name, 
        quantity_on_hand,
        similarity(trade_name, $1) as sml
      FROM medicines_inventory
      WHERE similarity(trade_name, $1) > 0.15 -- The threshold for how "fuzzy" you want it
      ORDER BY sml DESC
      LIMIT 5
    `, [term]);

    res.json(result.rows);
  } catch (error) {
    console.error("Fuzzy search error:", error);
    res.status(500).json({ error: 'Search failed' });
  }
});


// 🌟 THE FINAL HANDOVER: Robot finished -> Manager confirms
router.post('/:id/complete-handover', authenticateToken, async (req, res) => {
  const { id } = req.params;
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // 1. Update the prescription status to COMPLETE
    const rxRes = await client.query(`
      UPDATE prescriptions 
      SET status = 'COMPLETE', updated_at = NOW() 
      WHERE prescription_id = $1 
      RETURNING prescription_id
    `, [id]);

    if (rxRes.rowCount === 0) throw new Error("Prescription not found");

    // 2. Finalize the items (This is where your Revenue Reports grab the data)
    // We update the status to 'DISPENSED' which your reports.ts already filters for!
    await client.query(`
      UPDATE prescription_items 
      SET status = 'DISPENSED', dispensed_at = NOW() 
      WHERE prescription_id = $1
    `, [id]);

    await client.query('COMMIT');
    res.json({ message: 'Transaction finalized and revenue recorded!' });

  } catch (error) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: 'Handover failed' });
  } finally {
    client.release();
  }
});

// 🌟 Direct OTC Sale (Walk-in)
router.post('/otc-sale', authenticateToken, async (req, res) => {
  // FIX: Safely handle the data whether Flutter sends a raw array or an object!
  const items = Array.isArray(req.body) ? req.body : req.body.items; 
  
  if (!items || items.length === 0) {
      return res.status(400).json({ error: 'No items in cart' });
  }

  const client = await pool.connect();
  
  try {
    await client.query('BEGIN'); 

    for (const item of items) {
      const updateResult = await client.query(`
        UPDATE medicines_inventory 
        SET quantity_on_hand = quantity_on_hand - $1 
        WHERE medicine_id = $2 AND quantity_on_hand >= $1
        RETURNING pay_rate, trade_name
      `, [item.quantity, item.medicine_id]);

      if (updateResult.rowCount === 0) {
        throw new Error(`Item ${item.medicine_id} is out of stock or not found.`);
      }

      // 2. تسجيل العملية (🌟 ضفنا quantity_prescribed هنا عشان الإيرور يختفي)
      await client.query(`
        INSERT INTO prescription_items (medicine_id, requested_name, quantity_prescribed, quantity_dispensed, pay_rate_at_sale, status, dispensed_at)
        VALUES ($1, $2, $3, $3, $4, 'DISPENSED', NOW())
      `, [item.medicine_id, updateResult.rows[0].trade_name, item.quantity, updateResult.rows[0].pay_rate]);
    }

    await client.query('COMMIT');
    res.json({ message: 'Sale completed successfully!' });
  } catch (error: any) {
    await client.query('ROLLBACK');
    res.status(400).json({ error: error.message });
  } finally {
    client.release();
  }
});

export default router;