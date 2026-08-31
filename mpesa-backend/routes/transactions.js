import express from 'express';
import {
  getAllTransactions,
  getTransactionsByCategory,
  getTransactionsByDateRange,
  addTransaction,
  getMonthlySummary,
  getCategorySummary,
  getDailySummary
} from '../db.js';

const router = express.Router();

// Get all transactions
router.get('/', async (req, res) => {
  try {
    const transactions = await getAllTransactions();
    res.json(transactions);
  } catch (error) {
    console.error('Error fetching transactions:', error);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

// Get transactions by category
router.get('/category/:category', async (req, res) => {
  try {
    const { category } = req.params;
    const transactions = await getTransactionsByCategory(category);
    res.json(transactions);
  } catch (error) {
    console.error('Error fetching category transactions:', error);
    res.status(500).json({ error: 'Failed to fetch category transactions' });
  }
});

// Get transactions by date range
router.get('/range/:startDate/:endDate', async (req, res) => {
  try {
    const { startDate, endDate } = req.params;
    const transactions = await getTransactionsByDateRange(startDate, endDate);
    res.json(transactions);
  } catch (error) {
    console.error('Error fetching range transactions:', error);
    res.status(500).json({ error: 'Failed to fetch transactions in date range' });
  }
});

// Add a new transaction
router.post('/', async (req, res) => {
  try {
    const { amount, category, description, phone_number, transaction_type, status, date, mpesa_ref } = req.body;

    if (!amount) {
      return res.status(400).json({ error: 'Amount is required' });
    }

    const newTransaction = await addTransaction({
      amount,
      category,
      description,
      phone_number,
      transaction_type,
      status,
      date,
      mpesa_ref
    });

    res.status(201).json(newTransaction);
  } catch (error) {
    console.error('Error adding transaction:', error);
    res.status(500).json({ error: 'Failed to add transaction' });
  }
});

// Get monthly summary
router.get('/summary/monthly', async (req, res) => {
  try {
    const summary = await getMonthlySummary();
    res.json(summary);
  } catch (error) {
    console.error('Error fetching monthly summary:', error);
    res.status(500).json({ error: 'Failed to fetch monthly summary' });
  }
});

// Get category summary
router.get('/summary/category', async (req, res) => {
  try {
    const summary = await getCategorySummary();
    res.json(summary);
  } catch (error) {
    console.error('Error fetching category summary:', error);
    res.status(500).json({ error: 'Failed to fetch category summary' });
  }
});

// Get daily summary
router.get('/summary/daily/:days', async (req, res) => {
  try {
    const { days } = req.params;
    const summary = await getDailySummary(parseInt(days) || 7);
    res.json(summary);
  } catch (error) {
    console.error('Error fetching daily summary:', error);
    res.status(500).json({ error: 'Failed to fetch daily summary' });
  }
});

export default router;
