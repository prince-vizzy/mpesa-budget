import express from 'express';
import { 
  getAllGoals, 
  addGoal, 
  updateGoal, 
  deleteGoal,
  getGoalProgress,
  calculateGoalMetrics
} from '../db.js';

const router = express.Router();

// Get all goals
router.get('/', async (req, res) => {
  try {
    const goals = await getAllGoals();
    
    // Calculate metrics for each goal
    const goalsWithMetrics = await Promise.all(
      goals.map(async (goal) => {
        const metrics = await calculateGoalMetrics(goal.id);
        return { ...goal, ...metrics };
      })
    );
    
    res.json(goalsWithMetrics);
  } catch (error) {
    console.error('Error fetching goals:', error);
    res.status(500).json({ error: 'Failed to fetch goals' });
  }
});

// Get specific goal with progress
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const goal = await getGoalProgress(id);
    
    if (!goal) {
      return res.status(404).json({ error: 'Goal not found' });
    }
    
    res.json(goal);
  } catch (error) {
    console.error('Error fetching goal:', error);
    res.status(500).json({ error: 'Failed to fetch goal' });
  }
});

// Create a new goal
router.post('/', async (req, res) => {
  try {
    const { name, target_amount, target_date, description } = req.body;

    if (!name || !target_amount) {
      return res.status(400).json({ error: 'Name and target amount are required' });
    }

    const newGoal = await addGoal({
      name,
      target_amount,
      target_date,
      description
    });

    // Calculate metrics for the new goal
    const metrics = await calculateGoalMetrics(newGoal.id);
    
    res.status(201).json({ ...newGoal, ...metrics });
  } catch (error) {
    console.error('Error creating goal:', error);
    res.status(500).json({ error: 'Failed to create goal' });
  }
});

// Update goal
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, target_amount, target_date, description, current_amount, status } = req.body;

    const updatedGoal = await updateGoal(id, {
      name,
      target_amount,
      target_date,
      description,
      current_amount,
      status
    });

    if (!updatedGoal) {
      return res.status(404).json({ error: 'Goal not found' });
    }

    // Calculate metrics for the updated goal
    const metrics = await calculateGoalMetrics(id);
    
    res.json({ ...updatedGoal, ...metrics });
  } catch (error) {
    console.error('Error updating goal:', error);
    res.status(500).json({ error: 'Failed to update goal' });
  }
});

// Delete goal
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await deleteGoal(id);
    
    if (!result) {
      return res.status(404).json({ error: 'Goal not found' });
    }
    
    res.json({ success: true, message: 'Goal deleted' });
  } catch (error) {
    console.error('Error deleting goal:', error);
    res.status(500).json({ error: 'Failed to delete goal' });
  }
});

export default router;
