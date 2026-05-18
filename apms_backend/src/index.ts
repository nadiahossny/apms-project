import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import http from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { pool } from './db';

// Import routers
import authRouter from './routes/auth';
import medicinesRouter from './routes/medicines';
import invoicesRouter from './routes/invoices';
import prescriptionsRouter from './routes/prescriptions';
import robotRouter from './routes/robot';
import aiRouter from './routes/ai';
import reportsRouter from './routes/reports';
import publicRouter from './routes/public';
const app = express();
const port = process.env.PORT || 4000;
app.use(cors());
app.use(express.json());

app.use(publicRouter);

// Main API Routes
app.use('/api/auth', authRouter);
app.use('/api/medicines', medicinesRouter);
app.use('/api/invoices', invoicesRouter);
app.use('/api/prescriptions', prescriptionsRouter);
app.use('/api/robot', robotRouter);
app.use('/api/ai', aiRouter); // Cleaned up the duplicate!
app.use('/api/reports', reportsRouter);
app.get('/api/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'connected' });
  } catch {
    res.status(503).json({ status: 'error', db: 'disconnected' });
  }
});

import { initWebSocket, broadcastEvent } from './ws';

// Create HTTP server
const server = http.createServer(app);

// Setup WebSocket Server
initWebSocket(server);

// Order Tracking Endpoint
app.get('/api/track-order/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const rxRes = await pool.query('SELECT status, roshetta_code FROM prescriptions WHERE prescription_id = $1', [id]);
    if (rxRes.rows.length === 0) return res.status(404).json({ error: 'Order not found' });
    
    const itemsRes = await pool.query('SELECT medicine_id FROM prescription_items WHERE prescription_id = $1', [id]);
    
    const allLinked = itemsRes.rows.length > 0 && itemsRes.rows.every(item => item.medicine_id !== null);
    const isReady = allLinked || rxRes.rows[0].status === 'COMPLETE' || rxRes.rows[0].status === 'DISPENSED';

    res.json({
      prescription_id: id,
      roshetta_code: rxRes.rows[0].roshetta_code,
      status: rxRes.rows[0].status,
      is_ready: isReady
    });
  } catch (error) {
    console.error('Error fetching order status:', error);
    res.status(500).json({ error: 'Failed to fetch status' });
  }
});

// Order Communications Endpoints
app.get('/api/prescriptions/:id/chat', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      'SELECT * FROM order_communications WHERE prescription_id = $1 ORDER BY created_at ASC',
      [id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching chat messages:', error);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

app.post('/api/prescriptions/:id/chat', async (req, res) => {
  const { id } = req.params;
  const { sender_type, message } = req.body;
  
  if (!sender_type || !message) {
    return res.status(400).json({ error: 'sender_type and message are required' });
  }

  try {
    const result = await pool.query(
      'INSERT INTO order_communications (prescription_id, sender_type, message) VALUES ($1, $2, $3) RETURNING *',
      [id, sender_type, message]
    );
    const newMsg = result.rows[0];

    // Broadcast the new message via WebSockets
    broadcastEvent({
      type: 'chat_message',
      payload: newMsg,
    });

    res.status(201).json(newMsg);
  } catch (error) {
    console.error('Error saving chat message:', error);
    res.status(500).json({ error: 'Failed to save message' });
  }
});

server.listen(port, () => {
  console.log(`Backend Gateway running on port ${port}`);
});