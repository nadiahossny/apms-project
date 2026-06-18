import { WebSocketServer, WebSocket } from 'ws';
import http from 'http';

let wss: WebSocketServer;

export const initWebSocket = (server: http.Server) => {
  wss = new WebSocketServer({ server });

  wss.on('connection', (ws) => {
    console.log('Client connected to WebSocket feed');
    ws.on('close', () => console.log('Client disconnected'));
  });
};

export const broadcastEvent = (event: any) => {
  if (!wss) return;
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(event));
    }
  });
};
