import { Router } from 'express';
import { query } from '../db';
import { authenticateToken } from '../middleware/auth';
import { broadcastEvent } from '../ws';

const router = Router();
// router.use(authenticateToken);

// 1. DISPATCH: Creates the job and tells the app the robot is moving (NO FAKE DELAY)
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

    // Instantly tell Flutter App the robot started moving
    broadcastEvent({ type: 'ROBOT_ACK', jobId, status: 'DISPATCHED', message: 'Robot is moving to grab the medicine...' });

    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// 2. RETRY: Resets job status to DISPATCHED (NO FAKE DELAY)
router.post('/retry/:jobId', async (req, res) => {
  try {
    const { jobId } = req.params;
    const jobRes = await query(`SELECT prescription_id, pick_sequence FROM robot_jobs WHERE job_id = $1`, [jobId]);
    
    if(jobRes.rows.length === 0) return res.status(404).json({message: 'Job not found'});
    
    const pickSeq = typeof jobRes.rows[0].pick_sequence === 'string' ? JSON.parse(jobRes.rows[0].pick_sequence) : jobRes.rows[0].pick_sequence;
    const resetSeq = pickSeq.map((p: any) => ({ ...p, status: 'PENDING' }));

    const result = await query(`
      UPDATE robot_jobs
      SET status = 'DISPATCHED', pick_sequence = $2, started_at = CURRENT_TIMESTAMP, completed_at = NULL
      WHERE job_id = $1 RETURNING *
    `, [jobId, JSON.stringify(resetSeq)]);

    broadcastEvent({ type: 'ROBOT_ACK', jobId, status: 'DISPATCHED', message: 'Robot is retrying job...' });

    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// 3. AD-HOC DISPATCH: (NO FAKE DELAY)
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

    broadcastEvent({ type: 'ROBOT_ACK', jobId, status: 'DISPATCHED', message: 'Robot is moving for ad-hoc pick...' });

    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// 4. NEW: WAITS FOR AHMED'S PYTHON SCRIPT TO SEND SUCCESS/FAILURE
router.post('/dispense-success', async (req, res) => {
  try {
    const { job_id, drug_found, status } = req.body;

    const jobRes = await query(`SELECT prescription_id, pick_sequence FROM robot_jobs WHERE job_id = $1`, [job_id]);
    if (jobRes.rows.length === 0) return res.status(404).json({ message: 'Job not found' });
    
    const pId = jobRes.rows[0].prescription_id;
    let pickSeq = typeof jobRes.rows[0].pick_sequence === 'string' ? JSON.parse(jobRes.rows[0].pick_sequence) : jobRes.rows[0].pick_sequence;

    // Mark items as DONE
    pickSeq = pickSeq.map((item: any) => ({ ...item, status: status === 'COMPLETED' ? 'DONE' : 'FAILED' }));

    // Update job status in DB
    await query(`
      UPDATE robot_jobs 
      SET status = $1, pick_sequence = $2, completed_at = CURRENT_TIMESTAMP 
      WHERE job_id = $3
    `, [status, JSON.stringify(pickSeq), job_id]);

    // Auto-checkout and deduct inventory if successful
    if (status === 'COMPLETED' && pId) {
      await query(`UPDATE prescriptions SET status = 'COMPLETE' WHERE prescription_id = $1 AND status != 'COMPLETE'`, [pId]);
      await query(`UPDATE prescription_items SET quantity_dispensed = quantity_prescribed WHERE prescription_id = $1`, [pId]);
      await query(`
        UPDATE medicines_inventory m
        SET quantity_on_hand = m.quantity_on_hand - pi.quantity_dispensed
        FROM prescription_items pi
        WHERE m.medicine_id = pi.medicine_id AND pi.prescription_id = $1
      `, [pId]);
    }

    // Tell the Flutter App it's done!
    broadcastEvent({ 
      type: 'ROBOT_ACK', 
      jobId: job_id, 
      status: status, 
      message: status === 'COMPLETED' ? `${drug_found} was successfully dispensed by the arm` : `Robot failed to dispense`
    });

    res.json({ success: true });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// --- EXISTING ABORT, DELETE, AND GET ROUTES REMAIN THE SAME ---
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