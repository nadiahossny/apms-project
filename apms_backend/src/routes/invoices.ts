import { Router } from 'express';
import { query, pool } from '../db';
import { authenticateToken } from '../middleware/auth';
import { z } from 'zod';
import multer from 'multer';
<<<<<<< HEAD
import * as xlsx from 'xlsx';
=======
>>>>>>> c4340b6b1d5f883c781339aeb4c4f42c3e15a927

// Use require instead of import to fix the TS(2349) signature error
const pdfParse = require('pdf-parse'); 

const upload = multer({ storage: multer.memoryStorage() });
const router = Router();

// Protect all routes below
router.use(authenticateToken);

const CreateInvoiceSchema = z.object({
  fatoora_number: z.string().min(1),
  company_id: z.coerce.number().int().positive().optional().nullable(),
  company_name: z.string().optional().nullable(),
  invoice_date: z.string().min(1),
  total_amount: z.coerce.number().min(0),
  total_discount: z.coerce.number().min(0).optional().default(0),
  payment_status: z
    .enum(['PENDING', 'PARTIAL', 'PAID'])
    .optional()
    .default('PENDING'),
  payment_due_date: z.string().optional().nullable(),
  notes: z.string().optional().nullable(),
  ocr_raw_json: z.any().optional(),
  items: z.array(z.object({
    medicine_id: z.coerce.number().int().positive().optional().nullable(),
    manual_name: z.string().optional().nullable(),
    quantity: z.coerce.number().int().positive(),
    unit_cost: z.coerce.number().min(0)
  })).optional().default([]),
});

const PaymentStatusSchema = z.object({
  payment_status: z.enum(['PENDING', 'PARTIAL', 'PAID']),
});

// ── PDF EXTRACTION ROUTE ──
router.post('/extract-pdf', upload.single('invoice_pdf'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'No PDF uploaded' });

    const pdfData = await pdfParse(req.file.buffer);
    const rawText = pdfData.text;

    // Smart Regex to hunt for common Egyptian supplier invoice formats
    const fatooraMatch = rawText.match(/(?:fatoora|invoice|inv|رقم الفاتورة)[\s:#-]*([A-Z0-9-]+)/i);
    const totalMatch = rawText.match(/(?:total|amount|net|الاجمالي|الصافي)[\s:#-]*([\d,]+(\.\d{1,2})?)/i);

    const extractedFatoora = fatooraMatch ? fatooraMatch[1].trim() : `AUTO-${Date.now().toString().slice(-6)}`;
    const extractedTotal = totalMatch ? parseFloat(totalMatch[1].replace(/,/g, '')) : 0.0;

    res.json({
       extractedText: rawText,
       suggestedData: {
         fatoora_number: extractedFatoora, 
         total_amount: extractedTotal
       }
    });
  } catch (error) {
    console.error('PDF Parse Error:', error);
    res.status(500).json({ message: 'Failed to parse PDF' });
  }
});

// ── STANDARD CRUD ROUTES ──
router.patch('/:id/payment-status', async (req, res) => {
  const { id } = req.params;
  const parsed = PaymentStatusSchema.safeParse(req.body);
  
  if (!parsed.success) {
    return res.status(422).json({ message: 'Validation error', issues: parsed.error.issues });
  }
  
  const { payment_status } = parsed.data;
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // 1. Get current status so we don't double-add if it was already PAID
    const currentInvRes = await client.query(`SELECT payment_status FROM invoices_fawateer WHERE invoice_id = $1`, [id]);
    if (currentInvRes.rows.length === 0) {
      throw new Error('Invoice not found');
    }
    const oldStatus = currentInvRes.rows[0].payment_status;

    // 2. Update the invoice status
    const result = await client.query(
      `UPDATE invoices_fawateer 
       SET payment_status = $1 
       WHERE invoice_id = $2 
       RETURNING *`, 
      [payment_status, id]
    );

    // 3. 🌟 The Magic: Only add to inventory if changing TO PAID from something else
    if (payment_status === 'PAID' && oldStatus !== 'PAID') {
      const itemsRes = await client.query(`SELECT medicine_id, quantity_received, unit_cost FROM invoice_items WHERE invoice_id = $1`, [id]);
      
      for (const item of itemsRes.rows) {
        // Updates quantity AND exactly overwrites the unit_cost 
        await client.query(
          `UPDATE medicines_inventory
           SET quantity_on_hand = quantity_on_hand + $1, unit_cost = $2
           WHERE medicine_id = $3`,
          [item.quantity_received, item.unit_cost, item.medicine_id]
        );
      }
    }

    await client.query('COMMIT');
    res.json(result.rows[0]);
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Error updating payment status:', error);
    res.status(500).json({ message: error.message || 'Internal Server Error' });
  } finally {
    client.release();
  }
});
router.get('/', async (req, res) => {
  try {
    const { status, page = '1', limit = '50' } = req.query;
    const offset = (Number(page) - 1) * Number(limit);

    let sql = `
      SELECT i.*, row_to_json(c.*) as company
      FROM invoices_fawateer i
      LEFT JOIN companies c ON i.company_id = c.company_id
      WHERE 1=1
    `;
    const params: any[] = [];
    let paramIndex = 1;

    if (status) {
      sql += ` AND i.payment_status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    }

    sql += ` ORDER BY i.created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(Number(limit), offset);

    const result = await query(sql, params);
    res.json({ data: result.rows });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await query(
      `SELECT i.*, row_to_json(c.*) as company,
        COALESCE(
          (SELECT json_agg(
            json_build_object(
              'item_id', ii.item_id,
              'quantity', ii.quantity_received,
              'cost', ii.unit_cost,
              'name', m.trade_name
            )
          ) 
          FROM invoice_items ii 
          JOIN medicines_inventory m ON ii.medicine_id = m.medicine_id
          WHERE ii.invoice_id = i.invoice_id), '[]'
        ) as items
       FROM invoices_fawateer i
       LEFT JOIN companies c ON i.company_id = c.company_id
       WHERE i.invoice_id = $1`,
      [id]
    );

    if (result.rows.length === 0) return res.status(404).json({ message: 'Invoice not found' });
    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await query(`DELETE FROM invoices_fawateer WHERE invoice_id = $1`, [req.params.id]);
    res.json({ message: 'Invoice deleted successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.post('/', async (req, res) => {
  const client = await pool.connect();
  try {
    const data = CreateInvoiceSchema.parse(req.body);
    await client.query('BEGIN');

    let finalCompanyId = data.company_id;
    if (!finalCompanyId && data.company_name) {
      const companyRes = await client.query(
        `INSERT INTO companies (name) VALUES ($1)
         ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
         RETURNING company_id`,
        [data.company_name]
      );
      finalCompanyId = companyRes.rows[0].company_id;
    }

    const invResult = await client.query(
      `INSERT INTO invoices_fawateer (
        fatoora_number, company_id, invoice_date, total_amount,
        total_discount, payment_status, payment_due_date, notes
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING invoice_id`,
      [
        data.fatoora_number,
        finalCompanyId,
        data.invoice_date,
        data.total_amount,
        data.total_discount,
        data.payment_status,
        data.payment_due_date,
        data.notes,
      ]
    );

    const newInvoiceId = invResult.rows[0].invoice_id;

    if (data.items && data.items.length > 0) {
      for (const item of data.items) {
        
        let finalMedicineId = item.medicine_id;

        // 🌟 If medicine doesn't exist, create a draft entry instantly!
        if (!finalMedicineId && item.manual_name) {
            const newMed = await client.query(`
                INSERT INTO medicines_inventory 
                (barcode, trade_name, active_substance, quantity_on_hand, unit_cost, pay_rate, expiration_date) 
                VALUES ($1, $2, 'TBD', 0, $3, $3 * 1.2, CURRENT_DATE + INTERVAL '1 year') 
                RETURNING medicine_id
            `, [`INV-${Date.now()}-${Math.floor(Math.random()*1000)}`, item.manual_name, item.unit_cost]);
            
            finalMedicineId = newMed.rows[0].medicine_id;
        }

       await client.query(
          `INSERT INTO invoice_items (invoice_id, medicine_id, quantity_received, unit_cost)
           VALUES ($1, $2, $3, $4)`,
          [newInvoiceId, finalMedicineId, item.quantity, item.unit_cost]
        );

        // 🌟 ONLY update stock and unit_cost if the invoice is created as PAID
        if (data.payment_status === 'PAID') {
          await client.query(
            `UPDATE medicines_inventory
             SET quantity_on_hand = quantity_on_hand + $1, unit_cost = $2
             WHERE medicine_id = $3`,
            [item.quantity, item.unit_cost, finalMedicineId]
          );
        }
<<<<<<< HEAD
=======

        // Update stock
        await client.query(
          `UPDATE medicines_inventory
           SET quantity_on_hand = quantity_on_hand + $1, unit_cost = $2
           WHERE medicine_id = $3`,
          [item.quantity, item.unit_cost, finalMedicineId]
        );
>>>>>>> c4340b6b1d5f883c781339aeb4c4f42c3e15a927
      }
    }

    await client.query('COMMIT');

    const full = await query(
      `SELECT i.*, row_to_json(c.*) as company
       FROM invoices_fawateer i
       LEFT JOIN companies c ON i.company_id = c.company_id
       WHERE i.invoice_id = $1`,
      [newInvoiceId],
    );

    res.status(201).json(full.rows[0]);
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error(error);
    const msg = typeof error?.message === 'string' ? error.message : 'Internal Server Error';
    if (msg.toLowerCase().includes('duplicate') || msg.toLowerCase().includes('unique')) {
        return res.status(409).json({ message: 'An invoice with this Fatoora number already exists.' });
    }
    res.status(400).json({ message: msg });
  } finally {
    client.release();
  }
});

// in invoices.ts
router.post('/generate-invoices', async (req, res) => {
    // Generate dummy companies first if they don't exist
    const suppliers = ['Pharmaoverseas', 'IBN SINA LABOREX PHARMA', 'UCP', 'AMOUN'];
    
    for (let i = 0; i < suppliers.length; i++) {
        // Ensure company exists and get its ID
        const compRes = await query(`
            INSERT INTO companies (name) VALUES ($1) 
            ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name 
            RETURNING company_id
        `, [suppliers[i]]);
        
        const companyId = compRes.rows[0].company_id;
        const invDate = new Date();
        invDate.setDate(invDate.getDate() - Math.floor(Math.random() * 30));

        // Insert using company_id, not company_name!
        await query(`
          INSERT INTO invoices_fawateer (fatoora_number, company_id, total_amount, payment_status, invoice_date)
          VALUES ($1, $2, $3, 'PAID', $4)
        `, [`INV-26-${Math.floor(Math.random()*9000)}`, companyId, Math.floor(Math.random()*5000) + 1000, invDate]);
    }
    res.json({ message: 'Invoices generated successfully using company_id!' });
});
<<<<<<< HEAD

// ── EXCEL INVOICE IMPORT ──
// Upload an Excel file with medicine rows → creates invoice + items + updates stock
router.post('/import-excel', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ message: 'No Excel file provided' });

  const client = await pool.connect();
  try {
    const workbook = xlsx.read(req.file.buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName]) as any[];

    if (!rows || rows.length === 0) {
      return res.status(400).json({ message: 'Excel file is empty' });
    }

    const findVal = (row: any, keywords: string[]) => {
      const key = Object.keys(row).find(k => keywords.some(word => k.toLowerCase().includes(word)));
      return key && row[key] !== undefined && row[key] !== null ? String(row[key]).trim() : null;
    };

    const parseExcelDate = (excelDate: any) => {
      try {
        if (!excelDate) return new Date(new Date().setFullYear(new Date().getFullYear() + 1));
        if (typeof excelDate === 'number' || !isNaN(Number(excelDate))) {
          return new Date(Math.round((Number(excelDate) - 25569) * 86400 * 1000));
        }
        const d = new Date(excelDate);
        return isNaN(d.getTime()) ? new Date(new Date().setFullYear(new Date().getFullYear() + 1)) : d;
      } catch {
        return new Date(new Date().setFullYear(new Date().getFullYear() + 1));
      }
    };

    await client.query('BEGIN');

    // Read invoice metadata from first row or form body
    const bodyCompanyName = req.body?.company_name as string | undefined;
    const bodyFatoora = req.body?.fatoora_number as string | undefined;
    const firstRow = rows[0];

    const companyName = findVal(firstRow, ['company', 'supplier', 'vendor', 'مورد', 'شركة']) || bodyCompanyName || 'Unknown Supplier';
    const fatooraNumber = bodyFatoora || `EXC-INV-${Date.now().toString().slice(-8)}`;
    const invoiceDate = new Date();

    // Upsert company
    const companyRes = await client.query(
      `INSERT INTO companies (name) VALUES ($1)
       ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
       RETURNING company_id`,
      [companyName]
    );
    const companyId = companyRes.rows[0].company_id;

    // Create invoice
    const invResult = await client.query(
      `INSERT INTO invoices_fawateer (fatoora_number, company_id, invoice_date, total_amount, payment_status)
       VALUES ($1, $2, $3, 0, 'PENDING') RETURNING invoice_id`,
      [fatooraNumber, companyId, invoiceDate.toISOString().split('T')[0]]
    );
    const newInvoiceId = invResult.rows[0].invoice_id;
    let totalAmount = 0;
    let importedCount = 0;

    for (const row of rows) {
      const tradeName = findVal(row, ['name', 'trade', 'medicine', 'صنف', 'دواء', 'اسم']);
      if (!tradeName || tradeName === '') continue;

      const qtyRaw = findVal(row, ['qty', 'quantity', 'packs', 'كمية', 'عدد']);
      const quantity = Math.max(1, parseInt(qtyRaw || '1') || 1);

      const costRaw = findVal(row, ['cost', 'unit_cost', 'unit cost', 'price', 'سعر', 'تكلفة']);
      const unitCost = Math.max(0, parseFloat(costRaw || '0') || 0);

      const payRateRaw = findVal(row, ['selling', 'pay_rate', 'pay rate', 'بيع']);
      const payRate = payRateRaw ? Math.max(0, parseFloat(payRateRaw) || 0) : unitCost * 1.2;

      const expRaw = findVal(row, ['expiry', 'expiration', 'تاريخ', 'صلاحية']);
      const expiry = parseExcelDate(expRaw);

      const activeSubstance = findVal(row, ['substance', 'active', 'generic', 'فعالة', 'نوع']) || tradeName;

      // Check if medicine exists by trade_name
      const existing = await client.query(
        'SELECT medicine_id, unit_cost FROM medicines_inventory WHERE trade_name = $1 AND is_archived = false',
        [tradeName]
      );

      let medicineId: number;
      if (existing.rows.length > 0) {
        medicineId = existing.rows[0].medicine_id;
      } else {
        // Create new medicine
        const barcode = `INV-${Date.now()}-${Math.floor(Math.random() * 10000)}`;
        const newMed = await client.query(
          `INSERT INTO medicines_inventory
           (barcode, trade_name, active_substance, quantity_on_hand, unit_cost, pay_rate, expiration_date, reorder_level, max_stock)
           VALUES ($1, $2, $3, 0, $4, $5, $6, 10, 100)
           RETURNING medicine_id`,
          [barcode, tradeName, activeSubstance, unitCost, payRate, expiry.toISOString().split('T')[0]]
        );
        medicineId = newMed.rows[0].medicine_id;
      }

      // Create invoice item
      await client.query(
        `INSERT INTO invoice_items (invoice_id, medicine_id, quantity_received, unit_cost)
         VALUES ($1, $2, $3, $4)`,
        [newInvoiceId, medicineId, quantity, unitCost]
      );

      // Update stock and cost
      await client.query(
        `UPDATE medicines_inventory
         SET quantity_on_hand = quantity_on_hand + $1,
             unit_cost = $2,
             pay_rate = GREATEST(pay_rate, $3)
         WHERE medicine_id = $4`,
        [quantity, unitCost, payRate, medicineId]
      );

      totalAmount += quantity * unitCost;
      importedCount++;
    }

    // Update invoice total
    await client.query(
      `UPDATE invoices_fawateer SET total_amount = $1, net_payable = $1 WHERE invoice_id = $2`,
      [totalAmount, newInvoiceId]
    );

    await client.query('COMMIT');

    const full = await query(
      `SELECT i.*, row_to_json(c.*) as company
       FROM invoices_fawateer i
       LEFT JOIN companies c ON i.company_id = c.company_id
       WHERE i.invoice_id = $1`,
      [newInvoiceId]
    );

    res.status(201).json({
      ...full.rows[0],
      items_count: importedCount,
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Excel Invoice Import Error:', error);
    res.status(500).json({ message: error.message || 'Failed to import Excel invoice' });
  } finally {
    client.release();
  }
});

// ── IMAGE INVOICE UPLOAD ──
// Upload invoice image → forward to OCR service → return structured line items
router.post('/upload-image', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'No image uploaded' });

    const http = require('http');
    const ocrHost = process.env.OCR_SERVICE_HOST || '127.0.0.1';
    const ocrPort = parseInt(process.env.OCR_SERVICE_PORT || '5001', 10);

    const postData = req.file.buffer;
    const options = {
      hostname: ocrHost,
      port: ocrPort,
      path: '/invoice/upload',
      method: 'POST',
      headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Length': Buffer.byteLength(postData),
      },
      timeout: 30000,
    };

    const proxyReq = http.request(options, (proxyRes: any) => {
      let body = '';
      proxyRes.on('data', (chunk: string) => { body += chunk; });
      proxyRes.on('end', () => {
        try {
          res.status(proxyRes.statusCode || 200).json(JSON.parse(body));
        } catch {
          res.status(proxyRes.statusCode || 200).send(body);
        }
      });
    });

    proxyReq.on('error', (err: Error) => {
      console.error('OCR proxy error:', err);
      res.status(502).json({ message: 'OCR service unreachable', detail: err.message });
    });

    proxyReq.write(postData);
    proxyReq.end();
  } catch (error: any) {
    console.error('Image Invoice Upload Error:', error);
    res.status(502).json({ message: 'Failed to process image via OCR service' });
  }
});

=======
>>>>>>> c4340b6b1d5f883c781339aeb4c4f42c3e15a927
export default router;