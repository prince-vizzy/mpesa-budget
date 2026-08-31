import express from 'express';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import cors from 'cors';
import dotenv from 'dotenv';
import transactionRoutes from './routes/transactions.js';
import goalsRoutes from './routes/goals.js';
import categoryRoutes from './routes/categories.js';
import syncRoutes from './routes/sync.js';
import importRoutes from './routes/import.js';
import { addTransaction, getAllTransactions } from './db.js';

dotenv.config();

const app = express();
const httpServer = createServer(app);
const io = new SocketIOServer(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

const PORT = process.env.PORT || 5000;
const NODE_ENV = process.env.NODE_ENV || 'development';
app.set('io', io);

// Middleware
app.use(cors());
app.use(express.json());

// Logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// API Routes
app.use('/api/transactions', transactionRoutes);
app.use('/api/goals', goalsRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/sync', syncRoutes);
app.use('/api/import', importRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'Server is running', environment: NODE_ENV });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'M-Pesa Backend API',
    version: '1.0.0',
    endpoints: {
      transactions: '/api/transactions',
      categories: '/api/categories',
      sync: '/api/sync',
      health: '/health'
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Socket.IO Connection Handling
io.on('connection', (socket) => {
  console.log(`✅ Client connected: ${socket.id}`);

  // Send initial transactions
  (async () => {
    try {
      const transactions = await getAllTransactions();
      socket.emit('initial_data', transactions);
    } catch (error) {
      console.error('Error sending initial data:', error);
    }
  })();

  // Listen for new transactions from client
  socket.on('add_transaction', async (transactionData) => {
    try {
      const newTransaction = await addTransaction(transactionData);
      console.log('📝 New transaction added:', newTransaction);

      // Broadcast to all connected clients
      io.emit('new_mpesa_tx', newTransaction);
    } catch (error) {
      console.error('Error adding transaction:', error);
      socket.emit('error', { message: 'Failed to add transaction' });
    }
  });

  socket.on('disconnect', () => {
    console.log(`❌ Client disconnected: ${socket.id}`);
  });

  socket.on('error', (error) => {
    console.error(`⚠️ Socket error from ${socket.id}:`, error);
  });
});

// Start Server
httpServer.listen(PORT, () => {
  console.log(`
╔════════════════════════════════════════╗
║   M-Pesa Backend Server Started        ║
║   ======================================║
║   Environment: ${NODE_ENV.padEnd(28)}║
║   Port: ${PORT.toString().padEnd(33)}║
║   API: http://localhost:${PORT}/api        ║
║   WebSocket: ws://localhost:${PORT}        ║
╚════════════════════════════════════════╝
  `);
});

// Error handling
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});
