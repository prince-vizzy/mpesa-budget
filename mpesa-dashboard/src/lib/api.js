import { io } from 'socket.io-client';

/**
 * Talks to mpesa-backend, which the Flutter app POSTs into via /api/sync.
 *
 * REST gives the state on load; the socket keeps it current afterwards. Vite
 * proxies both to :5000 in dev, so this stays same-origin.
 */

async function getJson(path) {
  const response = await fetch(path);
  if (!response.ok) {
    throw new Error(`${path} responded ${response.status}`);
  }
  return response.json();
}

export function fetchTransactions() {
  return getJson('/api/transactions');
}

export function fetchCategories() {
  return getJson('/api/categories');
}

/**
 * Opens the live connection.
 *
 * The backend emits `budget_categories_updated` from two places and only one of
 * them carries a payload, so the handler is given whatever arrived and decides
 * whether it needs to re-fetch.
 */
export function connect({ onTransactions, onTransaction, onCategories, onStatus }) {
  const socket = io({ transports: ['websocket', 'polling'] });

  socket.on('connect', () => onStatus('live'));
  socket.on('disconnect', () => onStatus('off'));
  socket.on('connect_error', () => onStatus('off'));

  socket.on('initial_data', (rows) => onTransactions(rows ?? []));
  socket.on('transactions_synced', (rows) => onTransactions(rows ?? []));
  socket.on('new_mpesa_tx', (row) => row && onTransaction(row));
  socket.on('budget_categories_updated', (rows) =>
    onCategories(Array.isArray(rows) ? rows : null),
  );

  return () => socket.close();
}
