import { Router } from 'express';
import { query, pool } from '../db';
import { authenticateToken } from '../middleware/auth';

const router = Router();
router.use(authenticateToken);

router.get('/dashboard', async (req: any, res) => {
  try {
    const userRole = req.user?.role || 'staff'; 

    const [stockResult, revenueResult, salesResult, activityResult, pendingRxResult, robotResult, lowStockResult, expiringResult, frequentResult] = await Promise.all([
      query(`
        SELECT 
          COUNT(*) as total_products,
          SUM(quantity_on_hand * pay_rate) as stock_value,
          SUM(CASE WHEN quantity_on_hand = 0 THEN 1 ELSE 0 END) as out_of_stock,
          SUM(CASE WHEN (expiration_date - CURRENT_DATE) <= 30 
                    AND (expiration_date - CURRENT_DATE) > 0 
                    AND quantity_on_hand > 0 THEN 1 ELSE 0 END) as expiring_soon
        FROM medicines_inventory
        WHERE is_archived = FALSE
      `),
      query(`
        SELECT DATE(pi.dispensed_at) as day, COALESCE(SUM(pi.quantity_dispensed * pi.pay_rate_at_sale), 0) as revenue
        FROM prescription_items pi
        WHERE pi.dispensed_at >= CURRENT_DATE - INTERVAL '6 days' AND pi.status = 'DISPENSED'
        GROUP BY DATE(pi.dispensed_at) ORDER BY day ASC
      `),
      query(`
        SELECT TO_CHAR(DATE_TRUNC('month', pi.dispensed_at), 'Mon YY') as label, COALESCE(SUM(pi.quantity_dispensed * pi.pay_rate_at_sale), 0) as value
        FROM prescription_items pi
        WHERE pi.dispensed_at >= CURRENT_DATE - INTERVAL '7 months' AND pi.status = 'DISPENSED'
        GROUP BY DATE_TRUNC('month', pi.dispensed_at) ORDER BY DATE_TRUNC('month', pi.dispensed_at) ASC
      `),
      query(`SELECT log_id, event_type, summary, created_at FROM activity_logs ORDER BY created_at DESC LIMIT 8`),
      query(`SELECT prescription_id, patient_name, created_at, status FROM prescriptions WHERE status = 'PENDING' ORDER BY created_at DESC LIMIT 5`),
      query(`SELECT COUNT(*) as issue_count FROM robot_jobs WHERE status IN ('PENDING', 'CANCELED', 'FAILED')`),
      query(`
        SELECT trade_name as name, quantity_on_hand as stock, reorder_level
        FROM medicines_inventory
        WHERE quantity_on_hand <= reorder_level AND is_archived = FALSE
        ORDER BY quantity_on_hand ASC LIMIT 3
      `),
      query(`
        SELECT trade_name as name, (expiration_date - CURRENT_DATE) as days_left, quantity_on_hand as stock
        FROM medicines_inventory
        WHERE expiration_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days' AND quantity_on_hand > 0 AND is_archived = FALSE
        ORDER BY expiration_date ASC LIMIT 3
      `),
      query(`
        SELECT COALESCE(m.trade_name, pi.requested_name, 'Unknown') as name, COUNT(*) as units
        FROM prescription_items pi
        LEFT JOIN medicines_inventory m ON pi.medicine_id = m.medicine_id
        GROUP BY name
        ORDER BY units DESC
        LIMIT 2
      `)
    ]);

    const kpiRow = stockResult.rows[0];

    const dailyRevenue: number[] = [];
    const revenueMap = new Map<string, number>();
    for (const row of revenueResult.rows) {
      revenueMap.set(row.day.toISOString().split('T')[0], parseFloat(row.revenue));
    }
    for (let i = 5; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const key = d.toISOString().split('T')[0];
      dailyRevenue.push(revenueMap.get(key) ?? 0);
    }

    const isManager = userRole === 'manager';

    res.json({
      kpis: {
        stock: isManager ? parseFloat(kpiRow.stock_value ?? '0') : null,
        outOfStock: parseInt(kpiRow.out_of_stock ?? '0'),
        expiringSoon: parseInt(kpiRow.expiring_soon ?? '0'),
        totalProducts: parseInt(kpiRow.total_products ?? '0'),
        robotIssues: parseInt(robotResult.rows[0]?.issue_count ?? '0'),
      },
      dailyRevenue: isManager ? dailyRevenue : [],
      salesData: isManager ? salesResult.rows : [],
      activityLogs: activityResult.rows || [],
      pendingPrescriptions: pendingRxResult.rows || [], 
      lowStockItems: lowStockResult.rows || [],
      expiringItems: expiringResult.rows || [],
      frequentItems: frequentResult.rows || [], 
      purchases: [],
    });
  } catch (error) {
    console.error('Dashboard error:', error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.get('/analytics', async (req: any, res) => {
  try {
    const userRole = req.user?.role || 'staff';
    if (userRole !== 'manager') {
      return res.status(403).json({ message: 'Forbidden: Managers only' });
    }

    const [revenueResult, wasteResult, topMedResult, topSupResult, expiryResult, mostPrescResult] = await Promise.all([
      query(`
        SELECT 
          COALESCE(SUM(pi.quantity_dispensed * pi.pay_rate_at_sale), 0) as total_revenue, 
          COALESCE(SUM(pi.line_profit), 0) as total_profit, 
          COALESCE(SUM(pi.quantity_dispensed), 0) as units_dispensed 
        FROM prescription_items pi 
        WHERE pi.status = 'DISPENSED' 
        AND pi.dispensed_at >= CURRENT_DATE - INTERVAL '365 days'
      `),
      query(`
        SELECT COALESCE(SUM(quantity_on_hand * pay_rate), 0) as waste_value 
        FROM medicines_inventory 
        WHERE expiration_date < CURRENT_DATE 
        AND quantity_on_hand > 0 
        AND is_archived = FALSE
      `),
      query(`
        SELECT m.trade_name as name, SUM(pi.quantity_dispensed) as units, SUM(pi.quantity_dispensed * pi.pay_rate_at_sale) as revenue 
        FROM prescription_items pi 
        JOIN medicines_inventory m ON pi.medicine_id = m.medicine_id 
        WHERE pi.status = 'DISPENSED' 
        AND pi.dispensed_at >= CURRENT_DATE - INTERVAL '365 days'
        GROUP BY m.trade_name ORDER BY revenue DESC LIMIT 10
      `),
      query(`
        SELECT c.name as name, SUM(ii.total_line_cost) as total_spend 
        FROM invoice_items ii 
        JOIN invoices_fawateer inv ON ii.invoice_id = inv.invoice_id 
        JOIN companies c ON inv.company_id = c.company_id 
        WHERE inv.invoice_date >= CURRENT_DATE - INTERVAL '365 days'
        GROUP BY c.name ORDER BY total_spend DESC LIMIT 5
      `),
      query(`
        SELECT trade_name as name, quantity_on_hand as qty, (quantity_on_hand * pay_rate) as value, expiration_date, (expiration_date - CURRENT_DATE) as days_remaining 
        FROM medicines_inventory 
        WHERE expiration_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '60 days' 
        AND quantity_on_hand > 0 AND is_archived = FALSE 
        ORDER BY expiration_date ASC LIMIT 10
      `),
      query(`
        SELECT COALESCE(m.trade_name, pi.requested_name, 'Unknown') as name, COUNT(*) as prescription_count 
        FROM prescription_items pi 
        LEFT JOIN medicines_inventory m ON pi.medicine_id = m.medicine_id 
        WHERE pi.dispensed_at >= CURRENT_DATE - INTERVAL '365 days'
        GROUP BY COALESCE(m.trade_name, pi.requested_name, 'Unknown') 
        ORDER BY prescription_count DESC LIMIT 5
      `)
    ]);

    const rev = revenueResult.rows[0];

    res.json({
      totalRevenue: parseFloat(rev.total_revenue),
      totalProfit: parseFloat(rev.total_profit),
      unitsDispensed: parseInt(rev.units_dispensed),
      wasteValue: parseFloat(wasteResult.rows[0].waste_value),
      topMedicines: topMedResult.rows.map(r => ({ name: r.name, units: parseInt(r.units), revenue: parseFloat(r.revenue).toFixed(2) })),
      topSuppliers: topSupResult.rows.map(r => ({ name: r.name, spend: parseFloat(r.total_spend).toFixed(2) })),
      expiryRisk: expiryResult.rows.map(r => ({ name: r.name, qty: parseInt(r.qty), value: parseFloat(r.value).toFixed(2), days: parseInt(r.days_remaining) })),
      mostPrescribed: mostPrescResult.rows.map(r => ({ name: r.name, prescription_count: parseInt(r.prescription_count) })),
    });
  } catch (error) {
    console.error('Analytics error:', error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.post('/generate-real-history', async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(`DELETE FROM prescription_items`);
    await client.query(`DELETE FROM prescriptions`);
    await client.query(`DELETE FROM invoice_items`);
    await client.query(`DELETE FROM invoices_fawateer`);

    await client.query(`UPDATE medicines_inventory SET unit_cost = pay_rate * 0.7 WHERE unit_cost = 0 OR unit_cost IS NULL`);
    
    const meds = await client.query(`
      SELECT medicine_id, pay_rate, unit_cost, trade_name 
      FROM medicines_inventory 
      WHERE quantity_on_hand > 0 LIMIT 50
    `);

    if (meds.rows.length === 0) throw new Error('Inventory empty! Upload Stock.xlsx first.');
    const now = new Date();

    const suppliers = ['Pharmaoverseas', 'IBN SINA LABOREX', 'UCP'];
    for (let i = 0; i < 24; i++) {
      const invDate = new Date();
      invDate.setDate(now.getDate() - Math.floor(Math.random() * 180));
      
      const compRes = await client.query(`
        INSERT INTO companies (name) VALUES ($1) ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name RETURNING company_id
      `, [suppliers[Math.floor(Math.random() * suppliers.length)]]);

      let calculatedTotal = 0;
      const invoiceItemsToInsert = [];
      
      for(let k=0; k<3; k++) {
        const m = meds.rows[Math.floor(Math.random() * meds.rows.length)];
        const qty = Math.floor(Math.random() * 15) + 5; 
        calculatedTotal += (m.unit_cost * qty);
        invoiceItemsToInsert.push({ medicine_id: m.medicine_id, unit_cost: m.unit_cost, quantity: qty });
      }

      const invoiceRes = await client.query(`
        INSERT INTO invoices_fawateer (fatoora_number, company_id, total_amount, payment_status, invoice_date)
        VALUES ($1, $2, $3, 'PAID', $4) RETURNING invoice_id
      `, [`INV-26-${Math.floor(Math.random()*9000)}`, compRes.rows[0].company_id, calculatedTotal, invDate]);

      const newInvoiceId = invoiceRes.rows[0].invoice_id;

      for(const item of invoiceItemsToInsert) {
        await client.query(`
          INSERT INTO invoice_items (invoice_id, medicine_id, quantity_received, unit_cost)
          VALUES ($1, $2, $3, $4)
        `, [newInvoiceId, item.medicine_id, item.quantity, item.unit_cost]);
      }
    }
      
    for (let i = 180; i >= 0; i--) {
      const targetDate = new Date();
      targetDate.setDate(now.getDate() - i);
      
      const salesCount = Math.floor(Math.random() * 5) + 5; 

      for (let j = 0; j < salesCount; j++) {
        const rxRes = await client.query(`
          INSERT INTO prescriptions (patient_name, status, created_at)
          VALUES ('Walk-in Customer', 'COMPLETE', $1) RETURNING prescription_id
        `, [targetDate]);

        const med = meds.rows[Math.floor(Math.random() * meds.rows.length)];
        const qty = Math.floor(Math.random() * 2) + 1;

        await client.query(`
          INSERT INTO prescription_items 
          (prescription_id, medicine_id, requested_name, quantity_prescribed, quantity_dispensed, pay_rate_at_sale, unit_cost_at_sale, status, dispensed_at)
          VALUES ($1, $2, $3, $4, $4, $5, $6, 'DISPENSED', $7)
        `, [rxRes.rows[0].prescription_id, med.medicine_id, med.trade_name, qty, med.pay_rate, med.unit_cost, targetDate]);
      }
    }

    await client.query('COMMIT');
    res.json({ message: "Success! Database cleaned, invoices filled, and real prescriptions created." });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: e instanceof Error ? e.message : 'Failed to generate history' });
  } finally {
    client.release();
  }
});

export default router;