import 'dotenv/config';

import { createServer } from 'node:http';

import app from './app.js';
import { startGuestSessionCleanup } from './services/guest-cleanup.service.js';
import { initializeSocketServer } from './services/socket.service.js';

const PORT = Number(process.env.PORT ?? 3000);

// Create one HTTP server for both Express and Socket.IO.
const httpServer = createServer(app);

// Attach Socket.IO to the HTTP server.
initializeSocketServer(httpServer);

// Start guest session cleanup.
startGuestSessionCleanup();

// Start the server.
httpServer.listen(PORT, '0.0.0.0', () => {
  console.log('================================');
  console.log('UserChat Backend Started!');
  console.log(`Server running on port ${PORT}`);
  console.log(`Local URL: http://localhost:${PORT}`);
  console.log(`Health URL: http://localhost:${PORT}/health`);
  console.log(`Socket.IO URL: http://localhost:${PORT}`);
  console.log('================================');
});