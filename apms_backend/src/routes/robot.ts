import { Router } from 'express';
import { query } from '../db';
import { authenticateToken } from '../middleware/auth';
import { broadcastEvent } from '../index';

const router = Router();
router.use(authenticateToken);

router.post('/dispatch', async (req, res) => {
  try {
    const { prescription_id } = req.body;
    const jobId = `JOB-${Date.now()}`;
    
    const itemsRes = await query(`
        SELECT pi.medicine_id, m.trade_name, pi.quantity_prescribed, m.storage_location
        FROM prescription_items pi
        JOIN medicines_inventory m ON pi.medicine_id = m.medicine_id
        WHERE pi.prescription_id = $1
    `, [prescription_id]);

    const pickSeq = itemsRes.rows.map(row => ({
        medicine_id: row.medicine_id,
        medicine_name: row.trade_name,
        qty: row.quantity_prescribed,
        bin: row.storage_location || 'A-01-A',
        status: 'PENDING'
    }));

    const result = await query(`
      INSERT INTO robot_jobs (job_id, prescription_id, status, pick_sequence, started_at)
      VALUES ($1, $2, 'DISPATCHED', $3, CURRENT_TIMESTAMP)
      RETURNING *
    `, [jobId, prescription_id, JSON.stringify(pickSeq)]);

    setTimeout(() => {
      broadcastEvent({ type: 'ROBOT_ACK', jobId, status: 'DISPATCHED', message: 'Robot has acknowledged job' });
      
      setTimeout(async () => {
        let allSuccess = true;
        const updatedPickSeq: any[] = [];

        // --- NEW: VERIFY STOCK AND EXPIRY BEFORE DISPENSING ---
        for (const item of pickSeq) {
          try {
            const checkRes = await query(`SELECT quantity_on_hand, expiration_date FROM medicines_inventory WHERE medicine_id = $1`, [item.medicine_id]);
            
            if (checkRes.rows.length === 0) {
              updatedPickSeq.push({ ...item, status: 'FAILED' });
              allSuccess = false;
              continue;
            }
            
            const med = checkRes.rows[0];
            const isExpired = new Date(med.expiration_date) < new Date();
            const notEnough = med.quantity_on_hand < item.qty;

            if (isExpired || notEnough) {
              updatedPickSeq.push({ ...item, status: 'FAILED' });
              allSuccess = false;
            } else {
              updatedPickSeq.push({ ...item, status: 'DONE' });
            }
          } catch (err) {
            updatedPickSeq.push({ ...item, status: 'FAILED' });
            allSuccess = false;
          }
        }
        // ------------------------------------------------------

        const finalStatus = allSuccess ? 'COMPLETED' : 'FAILED';
        await query(`UPDATE robot_jobs SET status = $1, pick_sequence = $2, completed_at = CURRENT_TIMESTAMP WHERE job_id = $3`, [finalStatus, JSON.stringify(updatedPickSeq), jobId]);
        
        // --- AUTO-CHECKOUT PRESCRIPTION (ONLY IF ALL ITEMS SUCCEEDED) ---
        if (allSuccess) {
          try {
            // 1. Mark prescription COMPLETE
            await query(`UPDATE prescriptions SET status = 'COMPLETE' WHERE prescription_id = $1 AND status != 'COMPLETE'`, [prescription_id]);
            // 2. Sync dispensed quantities
            await query(`UPDATE prescription_items SET quantity_dispensed = quantity_prescribed WHERE prescription_id = $1`, [prescription_id]);
            // 3. Deduct from physical inventory
            await query(`
              UPDATE medicines_inventory m
              SET quantity_on_hand = m.quantity_on_hand - pi.quantity_dispensed
              FROM prescription_items pi
              WHERE m.medicine_id = pi.medicine_id AND pi.prescription_id = $1
            `, [prescription_id]);
          } catch(err) {
            console.error("Auto-checkout failed:", err);
          }
        }
        // ---------------------------------------

        broadcastEvent({ 
          type: 'ROBOT_ACK', 
          jobId, 
          status: finalStatus, 
          message: allSuccess ? 'Job completed successfully' : 'Job failed: Expiry or stock error' 
        });
      }, 5000);
    }, 1000);

    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.post('/retry/:jobId', async (req, res) => {
  try {
    const { jobId } = req.params;
    const jobRes = await query(`SELECT prescription_id, pick_sequence FROM robot_jobs WHERE job_id = $1`, [jobId]);
    
    if(jobRes.rows.length === 0) return res.status(404).json({message: 'Job not found'});
    
    const pId = jobRes.rows[0].prescription_id;
    const pickSeq = typeof jobRes.rows[0].pick_sequence === 'string' ? JSON.parse(jobRes.rows[0].pick_sequence) : jobRes.rows[0].pick_sequence;
    const resetSeq = pickSeq.map((p: any) => ({ ...p, status: 'PENDING' }));

    const result = await query(`
      UPDATE robot_jobs
      SET status = 'DISPATCHED', pick_sequence = $2, started_at = CURRENT_TIMESTAMP, completed_at = NULL
      WHERE job_id = $1 RETURNING *
    `, [jobId, JSON.stringify(resetSeq)]);

    setTimeout(() => {
      broadcastEvent({ type: 'ROBOT_ACK', jobId, status: 'DISPATCHED', message: 'Robot retrying job' });
      
      setTimeout(async () => {
        let allSuccess = true;
        const updatedPickSeq: any[] = [];

        // --- NEW: VERIFY RETRY STOCK AND EXPIRY ---
        for (const item of resetSeq) {
          try {
            const checkRes = await query(`SELECT quantity_on_hand, expiration_date FROM medicines_inventory WHERE medicine_id = $1`, [item.medicine_id]);
            if (checkRes.rows.length === 0) {
              updatedPickSeq.push({ ...item, status: 'FAILED' });
              allSuccess = false;
              continue;
            }
            
            const med = checkRes.rows[0];
            const isExpired = new Date(med.expiration_date) < new Date();
            const notEnough = med.quantity_on_hand < item.qty;

            if (isExpired || notEnough) {
              updatedPickSeq.push({ ...item, status: 'FAILED' });
              allSuccess = false;
            } else {
              updatedPickSeq.push({ ...item, status: 'DONE' });
            }
          } catch (err) {
            updatedPickSeq.push({ ...item, status: 'FAILED' });
            allSuccess = false;
          }
        }
        // ------------------------------------------

        const finalStatus = allSuccess ? 'COMPLETED' : 'FAILED';
        await query(`UPDATE robot_jobs SET status = $1, pick_sequence = $2, completed_at = CURRENT_TIMESTAMP WHERE job_id = $3`, [finalStatus, JSON.stringify(updatedPickSeq), jobId]);
        
        // --- AUTO-CHECKOUT RETRY (ONLY IF SUCCESSFUL) ---
        if (allSuccess && pId) {
          try {
            await query(`UPDATE prescriptions SET status = 'COMPLETE' WHERE prescription_id = $1 AND status != 'COMPLETE'`, [pId]);
            await query(`UPDATE prescription_items SET quantity_dispensed = quantity_prescribed WHERE prescription_id = $1`, [pId]);
            await query(`
              UPDATE medicines_inventory m
              SET quantity_on_hand = m.quantity_on_hand - pi.quantity_dispensed
              FROM prescription_items pi
              WHERE m.medicine_id = pi.medicine_id AND pi.prescription_id = $1
            `, [pId]);
          } catch(err) {
            console.error("Auto-checkout retry failed:", err);
          }
        }
        // --------------------------------

        broadcastEvent({ 
          type: 'ROBOT_ACK', 
          jobId, 
          status: finalStatus, 
          message: allSuccess ? 'Retry completed successfully' : 'Retry failed: Expiry or stock error' 
        });
      }, 5000);
    }, 1000);

    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.post('/dispatch-adhoc', async (req, res) => {
  try {
    const { medicine_id, name, qty, bin } = req.body;
    const jobId = `ADHOC-${Date.now()}`;
    const pickSeq = [{ medicine_id, medicine_name: name, qty, bin, status: 'PENDING' }];
    
    const result = await query(`
      INSERT INTO robot_jobs (job_id, prescription_id, status, pick_sequence, started_at)
      VALUES ($1, NULL, 'DISPATCHED', $2, CURRENT_TIMESTAMP)
      RETURNING *
    `, [jobId, JSON.stringify(pickSeq)]);

    setTimeout(() => {
      broadcastEvent({ type: 'ROBOT_ACK', jobId, status: 'DISPATCHED', message: 'Robot acknowledged ad-hoc job' });
      
      setTimeout(async () => {
        let allSuccess = true;
        const updatedPickSeq: any[] = [];

        // --- NEW: VERIFY AD-HOC STOCK AND EXPIRY ---
        for (const item of pickSeq) {
          try {
            const checkRes = await query(`SELECT quantity_on_hand, expiration_date FROM medicines_inventory WHERE medicine_id = $1`, [item.medicine_id]);
            if (checkRes.rows.length === 0) {
              updatedPickSeq.push({ ...item, status: 'FAILED' });
              allSuccess = false;
              continue;
            }
            
            const med = checkRes.rows[0];
            const isExpired = new Date(med.expiration_date) < new Date();
            const notEnough = med.quantity_on_hand < item.qty;

            if (isExpired || notEnough) {
              updatedPickSeq.push({ ...item, status: 'FAILED' });
              allSuccess = false;
            } else {
              updatedPickSeq.push({ ...item, status: 'DONE' });
            }
          } catch (err) {
            updatedPickSeq.push({ ...item, status: 'FAILED' });
            allSuccess = false;
          }
        }
        // -------------------------------------------

        const finalStatus = allSuccess ? 'COMPLETED' : 'FAILED';
        await query(`UPDATE robot_jobs SET status = $1, pick_sequence = $2, completed_at = CURRENT_TIMESTAMP WHERE job_id = $3`, [finalStatus, JSON.stringify(updatedPickSeq), jobId]);
        
        broadcastEvent({ 
          type: 'ROBOT_ACK', 
          jobId, 
          status: finalStatus, 
          message: allSuccess ? 'Ad-hoc pick completed' : 'Ad-hoc pick failed: Check stock' 
        });
      }, 5000);
    }, 1000);

    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.post('/abort/:jobId', async (req, res) => {
  try {
    const { jobId } = req.params;
    await query(`UPDATE robot_jobs SET status = 'ABORTED' WHERE job_id = $1`, [jobId]);
    broadcastEvent({ type: 'ROBOT_ACK', jobId, status: 'ABORTED', message: 'Manual abort requested' });
    res.json({ message: 'Job aborted' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.delete('/jobs/:jobId', async (req, res) => {
  try {
    await query(`DELETE FROM robot_jobs WHERE job_id = $1`, [req.params.jobId]);
    res.json({ message: 'Job deleted' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.get('/jobs', async (req, res) => {
  try {
    const { status, limit = '20' } = req.query;
    let sql = `SELECT * FROM robot_jobs`;
    const params: any[] = [];
    if (status) {
      sql += ` WHERE status = $1 ORDER BY started_at DESC LIMIT $2`;
      params.push(status, Number(limit));
    } else {
      sql += ` ORDER BY started_at DESC LIMIT $1`;
      params.push(Number(limit));
    }
    
    const result = await query(sql, params);
    res.json(result.rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

export default router;