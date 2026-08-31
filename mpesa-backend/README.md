# M-Pesa Backend API

Express.js backend server with Socket.IO real-time support for M-Pesa transaction tracking.

## Features

- ✅ RESTful API for transaction management
- ✅ Real-time WebSocket support with Socket.IO
- ✅ SQLite database for persistent storage
- ✅ Transaction categories and summaries
- ✅ CORS enabled for frontend integration
- ✅ Comprehensive error handling

## Setup

### 1. Install Dependencies

```bash
cd mpesa-backend
npm install
```

### 2. Create Environment File

The `.env` file is already configured with default values. You can modify it if needed:

```env
PORT=5000
NODE_ENV=development
DATABASE_PATH=./data/transactions.db
```

### 3. Create Data Directory

```bash
mkdir data
```

### 4. Start the Server

**Development mode (with hot reload):**
```bash
npm run dev
```

**Production mode:**
```bash
npm start
```

The server will start on `http://localhost:5000`

## API Endpoints

### Transactions

- `GET /api/transactions` - Get all transactions
- `GET /api/transactions/category/:category` - Get transactions by category
- `GET /api/transactions/range/:startDate/:endDate` - Get transactions in date range
- `POST /api/transactions` - Add a new transaction
- `GET /api/transactions/summary/monthly` - Get monthly summary
- `GET /api/transactions/summary/category` - Get category summary
- `GET /api/transactions/summary/daily/:days` - Get daily summary for last N days

### Example: Add a Transaction

```bash
curl -X POST http://localhost:5000/api/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 1500,
    "category": "Food & Dining",
    "description": "Lunch at restaurant",
    "phone_number": "+254712345678",
    "transaction_type": "sent",
    "status": "completed",
    "mpesa_ref": "LKZ1234567"
  }'
```

## WebSocket Events

### Client Events

- `add_transaction` - Send new transaction data

```javascript
socket.emit('add_transaction', {
  amount: 500,
  category: 'Transport',
  description: 'Uber ride',
  phone_number: '+254712345678'
});
```

### Server Events

- `connection` - Client connected
- `initial_data` - Initial transactions list (sent on connection)
- `new_mpesa_tx` - New transaction broadcasted to all clients
- `disconnect` - Client disconnected

## Database Schema

### transactions table
- `id` - Transaction ID (Primary Key)
- `date` - Transaction date
- `amount` - Transaction amount
- `category` - Transaction category
- `description` - Transaction description
- `phone_number` - Phone number involved
- `transaction_type` - Type (sent/received)
- `status` - Status (completed/pending/failed)
- `mpesa_ref` - M-Pesa reference number
- `created_at` - Creation timestamp
- `updated_at` - Last update timestamp

### categories table
- `id` - Category ID
- `name` - Category name
- `icon` - Category emoji icon
- `color` - Category color code

## Connecting from Frontend

```javascript
import io from 'socket.io-client';

const socket = io('http://localhost:5000');

socket.on('connect', () => {
  console.log('Connected to server');
});

socket.on('initial_data', (transactions) => {
  console.log('Initial transactions:', transactions);
});

socket.on('new_mpesa_tx', (newTx) => {
  console.log('New transaction received:', newTx);
});

// Send new transaction
socket.emit('add_transaction', {
  amount: 250,
  category: 'Shopping',
  description: 'Groceries'
});
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| PORT | 5000 | Server port |
| NODE_ENV | development | Environment (development/production) |
| DATABASE_PATH | ./data/transactions.db | SQLite database location |

## Dependencies

- **express** - Web framework
- **socket.io** - Real-time communication
- **cors** - Cross-origin resource sharing
- **better-sqlite3** - SQLite database
- **dotenv** - Environment configuration
- **axios** - HTTP client (optional for external APIs)
- **nodemon** - Development auto-reload (dev only)

## Troubleshooting

### Port Already in Use
```bash
# Windows
netstat -ano | findstr :5000
taskkill /PID <PID> /F

# macOS/Linux
lsof -i :5000
kill -9 <PID>
```

### Database Errors
- Check if `data/` directory exists
- Verify write permissions on the `data/` directory
- Delete `data/transactions.db` to reset database

### CORS Issues
The server is configured to accept requests from any origin. For production, update the CORS configuration in `server.js`.

## License

MIT
