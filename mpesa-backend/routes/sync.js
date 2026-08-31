import express from 'express';
import { getAllCategories, getAllTransactions, syncAppData } from '../db.js';

const router = express.Router();

router.post('/', async (req, res) => {
  try {
    const result = await syncAppData(req.body || {});
    const io = req.app.get('io');

    if (io) {
      io.emit('budget_categories_updated', await getAllCategories());
      io.emit('transactions_synced', await getAllTransactions());
    }

    res.json({ ok: true, ...result });
  } catch (error) {
    console.error('Error syncing app data:', error);
    res.status(500).json({ error: 'Failed to sync app data' });
  }
});

export default router;
