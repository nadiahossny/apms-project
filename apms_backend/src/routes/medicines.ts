import { Router } from 'express';
import { query, pool } from '../db';
import { authenticateToken } from '../middleware/auth';
import { z } from 'zod';
import multer from 'multer';
import * as xlsx from 'xlsx';

const upload = multer({ storage: multer.memoryStorage() });
const router = Router();
router.use(authenticateToken); // Protect all routes

const CreateMedicineSchema = z.object({
  barcode: z.string().min(1),
  serial_number: z.string().optional().nullable(),
  trade_name: z.string().min(1),
  active_substance: z.string().min(1),
  company_id: z.coerce.number().int().positive().optional().nullable(),
  company_name: z.string().optional().nullable(),
  quantity_on_hand: z.coerce.number().int().min(0).optional().default(0),
  reorder_level: z.coerce.number().int().min(0).optional().default(10),
  max_stock: z.coerce.number().int().min(0).optional().default(100),
  unit_cost: z.coerce.number().min(0).optional().default(0),
  pay_rate: z.coerce.number().min(0).optional().default(0),
  discount_pct: z.coerce.number().min(0).max(100).optional().default(0),
  expiration_date: z.string().min(1),
  storage_location: z.string().optional().nullable(),
  requires_refrigeration: z.boolean().optional().default(false),
});

// GET all medicines for the Inventory screen
router.get('/', async (req, res) => {
  try {
    const result = await query(`
      SELECT m.*, c.name as company_name 
      FROM medicines_inventory m
      LEFT JOIN companies c ON m.company_id = c.company_id
      WHERE m.is_archived = false
      ORDER BY m.trade_name ASC
    `);
    
    res.json({
      data: result.rows,
      total: result.rowCount
    });
  } catch (error) {
    console.error('Error fetching medicines:', error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// POST to create a new medicine
router.post('/', async (req, res) => {
  try {
    const data = CreateMedicineSchema.parse(req.body);

    let companyId = data.company_id;
    if (!companyId && data.company_name) {
      const existingComp = await query('SELECT company_id FROM companies WHERE name ILIKE $1', [data.company_name]);
      if (existingComp.rows.length > 0) {
        companyId = existingComp.rows[0].company_id;
      } else {
        const newComp = await query('INSERT INTO companies (name) VALUES ($1) RETURNING company_id', [data.company_name]);
        companyId = newComp.rows[0].company_id;
      }
    }

    const insertQuery = `
      INSERT INTO medicines_inventory (
        barcode, serial_number, trade_name, active_substance, 
        company_id, quantity_on_hand, reorder_level, max_stock, 
        unit_cost, pay_rate, discount_pct, expiration_date, 
        storage_location, requires_refrigeration
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
      RETURNING *
    `;
    
    const values = [
      data.barcode, data.serial_number, data.trade_name, data.active_substance,
      companyId, data.quantity_on_hand, data.reorder_level, data.max_stock,
      data.unit_cost, data.pay_rate, data.discount_pct, data.expiration_date,
      data.storage_location, data.requires_refrigeration
    ];

    const result = await query(insertQuery, values);

    const withCompany = await query(`
      SELECT m.*, c.name as company_name 
      FROM medicines_inventory m 
      LEFT JOIN companies c ON m.company_id = c.company_id 
      WHERE m.medicine_id = $1`, 
      [result.rows[0].medicine_id]
    );

    res.status(201).json(withCompany.rows[0]);

  } catch (error: any) {
    console.error('Error creating medicine:', error);
    if (error.code === '23505') { 
      return res.status(409).json({ message: 'A medicine with this barcode already exists.' });
    }
    res.status(400).json({ message: 'Invalid data format or internal error.' });
  }
});

// PATCH to update medicine
router.patch('/:id', async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return res.status(400).json({ message: 'Invalid medicine id' });
    }

    const data = CreateMedicineSchema.parse(req.body);
    let companyId = data.company_id;
    if (!companyId && data.company_name) {
      const existingComp = await query('SELECT company_id FROM companies WHERE name ILIKE $1', [data.company_name]);
      if (existingComp.rows.length > 0) {
        companyId = existingComp.rows[0].company_id;
      } else {
        const newComp = await query('INSERT INTO companies (name) VALUES ($1) RETURNING company_id', [data.company_name]);
        companyId = newComp.rows[0].company_id;
      }
    }

    const updateQuery = `
      UPDATE medicines_inventory
      SET
        barcode = $1, serial_number = $2, trade_name = $3, active_substance = $4,
        company_id = $5, quantity_on_hand = $6, reorder_level = $7, max_stock = $8,
        unit_cost = $9, pay_rate = $10, discount_pct = $11, expiration_date = $12,
        storage_location = $13, requires_refrigeration = $14
      WHERE medicine_id = $15
      RETURNING *
    `;

    const values = [
      data.barcode, data.serial_number, data.trade_name, data.active_substance,
      companyId, data.quantity_on_hand, data.reorder_level, data.max_stock,
      data.unit_cost, data.pay_rate, data.discount_pct, data.expiration_date,
      data.storage_location, data.requires_refrigeration, id,
    ];

    const result = await query(updateQuery, values);
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Medicine not found' });
    }

    const withCompany = await query(`
      SELECT m.*, c.name as company_name
      FROM medicines_inventory m
      LEFT JOIN companies c ON m.company_id = c.company_id
      WHERE m.medicine_id = $1
    `, [id]);

    res.json(withCompany.rows[0]);
  } catch (error: any) {
    console.error('Error updating medicine:', error);
    if (error.code === '23505') {
      return res.status(409).json({ message: 'A medicine with this barcode already exists.' });
    }
    res.status(400).json({ message: 'Invalid data format or internal error.' });
  }
});

// 🌟 BULLETPROOF EXCEL IMPORT
router.post('/import', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ message: 'No Excel file provided' });

  const client = await pool.connect();
  try {
    const workbook = xlsx.read(req.file.buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName]) as any[];

    if (!rows || rows.length === 0) {
      return res.status(400).json({ message: 'Excel file is empty' });
    }

    await client.query('BEGIN');

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

    let importedCount = 0;

    for (const row of rows) {
      const tradeName = findVal(row, ['name', 'trade', 'اسم', 'صنف', 'دواء']);
      // Skip completely broken/empty rows
      if (!tradeName || tradeName === '') continue;

      const qtyRaw = findVal(row, ['qty', 'quantity', 'packs', 'كمية', 'رصيد']);
      // Math.max guarantees the quantity never drops below 0
      const qty = Math.max(0, parseInt(qtyRaw || '0') || 0);

      const payRateRaw = findVal(row, ['price', 'selling', 'سعر', 'rate']);
      // Same protection for prices
      const payRate = Math.max(0, parseFloat(payRateRaw || '0.0') || 0.0);

      
      const category = findVal(row, ['category', 'type', 'فئة', 'نوع', 'substance']) || 'General';
      const expRaw = findVal(row, ['expiry', 'date', 'تاريخ', 'صلاحية']);
      const expiry = parseExcelDate(expRaw);

      const existing = await client.query('SELECT medicine_id FROM medicines_inventory WHERE trade_name = $1', [tradeName]);

      if (existing.rows.length > 0) {
        await client.query(`
          UPDATE medicines_inventory 
          SET quantity_on_hand = quantity_on_hand + $1
          WHERE medicine_id = $2
        `, [qty, existing.rows[0].medicine_id]);
      } else {
        const barcode = `EXC-${Date.now()}-${Math.floor(Math.random() * 10000)}`;
        await client.query(`
          INSERT INTO medicines_inventory 
          (barcode, trade_name, active_substance, quantity_on_hand, pay_rate, expiration_date, reorder_level, max_stock)
          VALUES ($1, $2, $3, $4, $5, $6, 10, 100)
        `, [barcode, tradeName, category, qty, payRate, expiry.toISOString()]);
      }
      importedCount++;
    }

    await client.query('COMMIT');
    res.json({ message: `Successfully imported ${importedCount} medicines!` });

  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error("Excel Import Crash Protected:", error);
    res.status(500).json({ message: 'Failed to process Excel file' });
  } finally {
    client.release();
  }
});

// Delete All Unknowns Route
router.delete('/bulk/unknown', async (req, res) => {
  try {
    const result = await query("DELETE FROM medicines_inventory WHERE trade_name = 'Unknown Medicine' OR trade_name IS NULL");
    res.json({ message: `Cleaned up ${result.rowCount} unknown items.` });
  } catch (error) {
    res.status(500).json({ message: 'Failed to clean database' });
  }
});

// Delete Single Item Route
router.delete('/:id', async (req, res) => {
  try {
    await query('DELETE FROM medicines_inventory WHERE medicine_id = $1', [req.params.id]);
    res.json({ message: 'Deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Failed to delete medicine' });
  }
});

export default router;