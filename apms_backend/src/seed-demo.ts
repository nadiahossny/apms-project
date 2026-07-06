import 'dotenv/config';
import * as xlsx from 'xlsx';
import { join } from 'path';
import { pool } from './db';

async function seed() {
  console.log('Starting Database Seeding for Demo...');
  
  try {
    const csvPath = join(__dirname, '../../database/staging_medicines.csv');
    const workbook = xlsx.readFile(csvPath);
    const data: any[] = xlsx.utils.sheet_to_json(workbook.Sheets[workbook.SheetNames[0]]);
    
    console.log(`Found ${data.length} medicines in CSV.`);

    for (const row of data) {
      const companyName = row['company_name'] || 'Unknown Company';
      
      // Insert or get Company
      let companyRes = await pool.query('SELECT company_id FROM companies WHERE name = $1', [companyName]);
      if (companyRes.rows.length === 0) {
        companyRes = await pool.query('INSERT INTO companies (name) VALUES ($1) RETURNING company_id', [companyName]);
      }
      const companyId = companyRes.rows[0].company_id;

      const barcode = row['barcode'] ? row['barcode'].toString() : `DUMMY-${Date.now()}-${Math.random()}`;
      const trade_name = row['trade_name'] || 'Unknown Medicine';
      const active_substance = row['active_substance'] || 'Unknown';
      const quantity_on_hand = row['quantity_on_hand'] || 50;
      const reorder_level = row['reorder_level'] || 10;
      const unit_cost = row['unit_cost'] || 15.5;
      const pay_rate = row['pay_rate'] || 20.0;
      const exp_date = row['expiration_date'] || '2027-12-31';
      
      await pool.query(`
        INSERT INTO medicines_inventory 
        (barcode, trade_name, active_substance, company_id, quantity_on_hand, reorder_level, unit_cost, pay_rate, expiration_date)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (barcode) DO NOTHING
      `, [barcode, trade_name, active_substance, companyId, quantity_on_hand, reorder_level, unit_cost, pay_rate, exp_date]);
    }

    console.log('✅ Seeding completed successfully!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Error during seeding:', err);
    process.exit(1);
  }
}

seed();
