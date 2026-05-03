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

// Create HTTP server
const server = http.createServer(app);

// Setup WebSocket Server for Robot ACK feed
const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  console.log('Client connected to WebSocket feed');
  ws.on('close', () => console.log('Client disconnected'));
});

// Broadcast helper for emitting ACK events to connected Flutter clients
export const broadcastEvent = (event: any) => {
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(event));
    }
  });
};

server.listen(port, () => {
  console.log(`Backend Gateway running on port ${port}`);
});