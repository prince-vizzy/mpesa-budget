import express from 'express';
import { getAllCategories, upsertCategory } from '../db.js';

const router = express.Router();

router.get('/', async (req, res) => {
  try {
    const categories = await getAllCategories();
    res.json(categories);
  } catch (error) {
    console.error('Error fetching categories:', error);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

router.post('/', async (req, res) => {
  try {
    const category = await upsertCategory(req.body);
    req.app.get('io')?.emit('budget_categories_updated');
    res.status(201).json(category);
  } catch (error) {
    console.error('Error saving category:', error);
    res.status(500).json({ error: 'Failed to save category' });
  }
});

export default router;
