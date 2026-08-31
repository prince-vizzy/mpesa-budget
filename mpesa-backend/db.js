import sqlite3 from 'sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbPath = path.join(__dirname, 'data', 'transactions.db');

const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Database connection error:', err);
  } else {
    console.log('✅ Connected to SQLite database');
  }
});

// Enable foreign keys
db.run('PRAGMA foreign_keys = ON');

// Create tables if they don't exist
const initializeDatabase = () => {
  return new Promise((resolve) => {
    let completed = 0;
    const total = 3;

    const checkCompletion = () => {
      completed++;
      if (completed === total) {
        // The Flutter app is the source of truth for categories — it syncs its
        // own, with the budgets the user actually set. Seeding a hardcoded list
        // here just leaves budget-less placeholders sitting beside the real
        // ones. Set SEED_DEFAULT_CATEGORIES=1 to restore the old behaviour.
        if (process.env.SEED_DEFAULT_CATEGORIES === '1') insertDefaultCategories();
        resolve();
      }
    };

    // Transactions table
    db.run(`
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date DATETIME DEFAULT CURRENT_TIMESTAMP,
        amount REAL NOT NULL,
        category TEXT,
        description TEXT,
        phone_number TEXT,
        transaction_type TEXT DEFAULT 'sent',
        status TEXT DEFAULT 'completed',
        mpesa_ref TEXT UNIQUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `, (err) => {
      if (err) console.error('Error creating transactions table:', err);
      checkCompletion();
    });

    // Categories table
    db.run(`
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        icon TEXT,
        color TEXT,
        budget_type TEXT DEFAULT 'daily',
        daily_budget REAL DEFAULT 0,
        weekly_budget REAL DEFAULT 0,
        monthly_budget REAL DEFAULT 0,
        spent_today REAL DEFAULT 0,
        spent_this_week REAL DEFAULT 0,
        spent_this_month REAL DEFAULT 0,
        spent_this_year REAL DEFAULT 0,
        app_id INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `, (err) => {
      if (err) console.error('Error creating categories table:', err);
      ensureCategoryBudgetColumns();
      ensureTransactionColumns();
      checkCompletion();
    });

    // Summary table (for caching aggregations)
    db.run(`
      CREATE TABLE IF NOT EXISTS daily_summary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date DATE UNIQUE,
        total_spent REAL,
        transaction_count INTEGER,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `, (err) => {
      if (err) console.error('Error creating daily_summary table:', err);
      checkCompletion();
    });
  });
};

// The Flutter app knows who each payment went to, and that is what the
// dashboard ranks payees by. Older databases predate the column.
const ensureTransactionColumns = () => {
  const columns = [['payee', 'TEXT']];

  columns.forEach(([name, definition]) => {
    db.run(`ALTER TABLE transactions ADD COLUMN ${name} ${definition}`, (err) => {
      if (err && !String(err.message).includes('duplicate column name')) {
        console.error(`Error adding transactions.${name}:`, err.message);
      }
    });
  });
};

const ensureCategoryBudgetColumns = () => {
  const columns = [
    ['budget_type', 'TEXT DEFAULT "daily"'],
    ['daily_budget', 'REAL DEFAULT 0'],
    ['weekly_budget', 'REAL DEFAULT 0'],
    ['monthly_budget', 'REAL DEFAULT 0'],
    ['spent_today', 'REAL DEFAULT 0'],
    ['spent_this_week', 'REAL DEFAULT 0'],
    ['spent_this_month', 'REAL DEFAULT 0'],
    ['spent_this_year', 'REAL DEFAULT 0'],
    ['app_id', 'INTEGER']
  ];

  columns.forEach(([name, definition]) => {
    db.run(`ALTER TABLE categories ADD COLUMN ${name} ${definition}`, (err) => {
      if (err && !String(err.message).includes('duplicate column name')) {
        console.error(`Error adding categories.${name}:`, err.message);
      }
    });
  });
};

// Insert default categories if they don't exist
const insertDefaultCategories = () => {
  const categories = [
    { name: 'Food & Dining', icon: '🍔', color: '#FF6B6B' },
    { name: 'Transport', icon: '🚗', color: '#4ECDC4' },
    { name: 'Shopping', icon: '🛍️', color: '#FFE66D' },
    { name: 'Entertainment', icon: '🎬', color: '#95E1D3' },
    { name: 'Utilities', icon: '💡', color: '#C7CEEA' },
    { name: 'Healthcare', icon: '⚕️', color: '#FF9FF3' },
    { name: 'Other', icon: '📌', color: '#A8DADC' }
  ];

  categories.forEach(cat => {
    db.run(
      'INSERT OR IGNORE INTO categories (name, icon, color) VALUES (?, ?, ?)',
      [cat.name, cat.icon, cat.color],
      (err) => {
        if (err) console.error('Error inserting category:', err);
      }
    );
  });
};

// Get all transactions
export const getAllTransactions = () => {
  return new Promise((resolve, reject) => {
    db.all(
      'SELECT * FROM transactions ORDER BY date DESC LIMIT 1000',
      (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      }
    );
  });
};

// Get transactions by date range
export const getTransactionsByDateRange = (startDate, endDate) => {
  return new Promise((resolve, reject) => {
    db.all(
      'SELECT * FROM transactions WHERE date BETWEEN ? AND ? ORDER BY date DESC',
      [startDate, endDate],
      (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      }
    );
  });
};

// Get transactions by category
export const getTransactionsByCategory = (category) => {
  return new Promise((resolve, reject) => {
    db.all(
      'SELECT * FROM transactions WHERE category = ? ORDER BY date DESC',
      [category],
      (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      }
    );
  });
};

// Add a new transaction
export const addTransaction = (transactionData) => {
  return new Promise((resolve, reject) => {
    db.run(
      'INSERT INTO transactions (date, amount, category, description, phone_number, transaction_type, status, mpesa_ref, payee) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        transactionData.date || new Date().toISOString(),
        transactionData.amount,
        transactionData.category || 'Other',
        transactionData.description || '',
        transactionData.phone_number || '',
        transactionData.transaction_type || 'sent',
        transactionData.status || 'completed',
        transactionData.mpesa_ref || null,
        transactionData.payee || null
      ],
      function(err) {
        if (err) reject(err);
        else resolve({ id: this.lastID, ...transactionData });
      }
    );
  });
};

// Get monthly summary
export const getMonthlySummary = () => {
  return new Promise((resolve, reject) => {
    db.all(
      `SELECT
        strftime('%Y-%m', date) as month,
        COUNT(*) as count,
        SUM(amount) as total
      FROM transactions
      GROUP BY strftime('%Y-%m', date)
      ORDER BY month DESC
      LIMIT 12`,
      (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      }
    );
  });
};

// Get category summary
export const getCategorySummary = () => {
  return new Promise((resolve, reject) => {
    db.all(
      `SELECT
        category,
        COUNT(*) as count,
        SUM(amount) as total
      FROM transactions
      GROUP BY category
      ORDER BY total DESC`,
      (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      }
    );
  });
};

export const getAllCategories = () => {
  return new Promise((resolve, reject) => {
    db.all(
      `SELECT
        id,
        app_id,
        name,
        icon,
        color,
        budget_type,
        daily_budget,
        weekly_budget,
        monthly_budget,
        spent_today,
        spent_this_week,
        spent_this_month,
        spent_this_year,
        created_at
      FROM categories
      ORDER BY name ASC`,
      (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      }
    );
  });
};

export const upsertCategory = (categoryData) => {
  return new Promise((resolve, reject) => {
    db.run(
      `INSERT INTO categories (
        name, icon, color, budget_type, daily_budget, weekly_budget,
        monthly_budget, spent_today, spent_this_week, spent_this_month,
        spent_this_year, app_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(name) DO UPDATE SET
        icon = excluded.icon,
        color = excluded.color,
        budget_type = excluded.budget_type,
        daily_budget = excluded.daily_budget,
        weekly_budget = excluded.weekly_budget,
        monthly_budget = excluded.monthly_budget,
        spent_today = excluded.spent_today,
        spent_this_week = excluded.spent_this_week,
        spent_this_month = excluded.spent_this_month,
        spent_this_year = excluded.spent_this_year,
        app_id = excluded.app_id`,
      [
        categoryData.name,
        categoryData.icon || null,
        categoryData.color || null,
        categoryData.budget_type || categoryData.budgetType || 'daily',
        categoryData.daily_budget ?? categoryData.dailyBudget ?? 0,
        categoryData.weekly_budget ?? categoryData.weeklyBudget ?? 0,
        categoryData.monthly_budget ?? categoryData.monthlyBudget ?? 0,
        categoryData.spent_today ?? categoryData.spentToday ?? 0,
        categoryData.spent_this_week ?? categoryData.spentThisWeek ?? 0,
        categoryData.spent_this_month ?? categoryData.spentThisMonth ?? 0,
        categoryData.spent_this_year ?? categoryData.spentThisYear ?? 0,
        categoryData.app_id ?? categoryData.id ?? null
      ],
      function(err) {
        if (err) reject(err);
        else resolve({ id: this.lastID, ...categoryData });
      }
    );
  });
};

export const syncAppData = async ({ categories = [], transactions = [] }) => {
  const syncedCategories = [];
  const syncedTransactions = [];

  for (const category of categories) {
    if (!category?.name) continue;
    syncedCategories.push(await upsertCategory(category));
  }

  for (const tx of transactions) {
    if (!tx || !tx.amount) continue;
    const appId = tx.app_id ?? tx.id;
    try {
      syncedTransactions.push(await addTransaction({
        amount: tx.amount,
        category: tx.category || tx.category_name || tx.categoryName || 'Other',
        description: tx.description || '',
        phone_number: tx.phone_number || '',
        transaction_type: tx.transaction_type || 'sent',
        status: tx.status || 'completed',
        date: tx.date || tx.timestamp || new Date().toISOString(),
        mpesa_ref: tx.mpesa_ref || (appId ? `app-${appId}` : null),
        payee: tx.payee || tx.name || null
      }));
    } catch (error) {
      if (!String(error.message).includes('UNIQUE constraint failed')) {
        throw error;
      }
    }
  }

  return {
    categories: syncedCategories.length,
    transactions: syncedTransactions.length
  };
};

// Get daily summary
export const getDailySummary = (days = 7) => {
  return new Promise((resolve, reject) => {
    db.all(
      `SELECT
        DATE(date) as day,
        COUNT(*) as count,
        SUM(amount) as total
      FROM transactions
      WHERE date >= datetime('now', '-' || ? || ' days')
      GROUP BY DATE(date)
      ORDER BY day DESC`,
      [days],
      (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      }
    );
  });
};

// ============================================
// Goals Management Functions
// ============================================

// Get all goals
export const getAllGoals = () => {
  return new Promise((resolve, reject) => {
    db.all(
      'SELECT * FROM goals WHERE status != "completed" ORDER BY created_at DESC',
      (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      }
    );
  });
};

// Get goal with progress
export const getGoalProgress = (goalId) => {
  return new Promise((resolve, reject) => {
    db.get(
      'SELECT * FROM goals WHERE id = ?',
      [goalId],
      (err, row) => {
        if (err) reject(err);
        else resolve(row);
      }
    );
  });
};

// Add a new goal
export const addGoal = (goalData) => {
  return new Promise((resolve, reject) => {
    db.run(
      'INSERT INTO goals (name, target_amount, current_amount, target_date, description, status) VALUES (?, ?, ?, ?, ?, ?)',
      [
        goalData.name,
        goalData.target_amount,
        0,
        goalData.target_date || null,
        goalData.description || '',
        'active'
      ],
      function(err) {
        if (err) reject(err);
        else resolve({ id: this.lastID, ...goalData, current_amount: 0, status: 'active' });
      }
    );
  });
};

// Update goal
export const updateGoal = (goalId, goalData) => {
  return new Promise((resolve, reject) => {
    const updates = [];
    const values = [];
    
    if (goalData.name !== undefined) {
      updates.push('name = ?');
      values.push(goalData.name);
    }
    if (goalData.target_amount !== undefined) {
      updates.push('target_amount = ?');
      values.push(goalData.target_amount);
    }
    if (goalData.target_date !== undefined) {
      updates.push('target_date = ?');
      values.push(goalData.target_date);
    }
    if (goalData.description !== undefined) {
      updates.push('description = ?');
      values.push(goalData.description);
    }
    if (goalData.current_amount !== undefined) {
      updates.push('current_amount = ?');
      values.push(goalData.current_amount);
    }
    if (goalData.status !== undefined) {
      updates.push('status = ?');
      values.push(goalData.status);
    }
    
    updates.push('updated_at = CURRENT_TIMESTAMP');
    values.push(goalId);
    
    if (updates.length === 1) {
      resolve(null);
      return;
    }
    
    const query = `UPDATE goals SET ${updates.join(', ')} WHERE id = ?`;
    
    db.run(query, values, function(err) {
      if (err) reject(err);
      else {
        getGoalProgress(goalId).then(resolve).catch(reject);
      }
    });
  });
};

// Delete goal
export const deleteGoal = (goalId) => {
  return new Promise((resolve, reject) => {
    db.run(
      'DELETE FROM goals WHERE id = ?',
      [goalId],
      function(err) {
        if (err) reject(err);
        else resolve({ id: goalId, success: true });
      }
    );
  });
};

// Calculate goal metrics (savings rate, time to goal, etc.)
export const calculateGoalMetrics = async (goalId) => {
  try {
    const goal = await getGoalProgress(goalId);
    
    if (!goal) {
      return { remaining: 0, dailySavings: 0, daysRemaining: 0, monthsRemaining: 0 };
    }

    // Get daily average spending from last 30 days
    const dailyAverage = await new Promise((resolve, reject) => {
      db.get(
        `SELECT AVG(daily_total) as avg_daily FROM (
          SELECT SUM(amount) as daily_total
          FROM transactions
          WHERE date >= datetime('now', '-30 days')
          GROUP BY DATE(date)
        )`,
        (err, row) => {
          if (err) reject(err);
          else resolve(row?.avg_daily || 100);
        }
      );
    });

    const remaining = goal.target_amount - (goal.current_amount || 0);
    const daysToGoal = goal.target_date 
      ? Math.ceil((new Date(goal.target_date) - new Date()) / (1000 * 60 * 60 * 24))
      : null;

    // Calculate recommended daily savings
    let dailySavings = 0;
    let daysRemaining = 0;
    let monthsRemaining = 0;

    if (daysToGoal && daysToGoal > 0) {
      dailySavings = remaining / daysToGoal;
      daysRemaining = daysToGoal;
      monthsRemaining = Math.ceil(daysToGoal / 30);
    } else if (dailyAverage > 0) {
      // If no target date, estimate based on spending patterns (save 20% of daily)
      const savingsRate = dailyAverage * 0.2;
      daysRemaining = Math.ceil(remaining / savingsRate);
      dailySavings = savingsRate;
      monthsRemaining = Math.ceil(daysRemaining / 30);
    }

    const progress = goal.target_amount > 0 
      ? Math.min(100, (goal.current_amount / goal.target_amount) * 100)
      : 0;

    return {
      remaining: Math.max(0, remaining),
      dailySavings: Math.ceil(dailySavings),
      weekSavings: Math.ceil(dailySavings * 7),
      monthSavings: Math.ceil(dailySavings * 30),
      daysRemaining: Math.max(0, daysRemaining),
      monthsRemaining: Math.max(0, monthsRemaining),
      progress: progress.toFixed(1),
      isCompleted: remaining <= 0,
      avgDailySpending: Math.ceil(dailyAverage)
    };
  } catch (error) {
    console.error('Error calculating metrics:', error);
    return {
      remaining: 0,
      dailySavings: 0,
      weekSavings: 0,
      monthSavings: 0,
      daysRemaining: 0,
      monthsRemaining: 0,
      progress: 0,
      isCompleted: false,
      avgDailySpending: 0
    };
  }
};

export const createGoalAdvice = async (goalId) => {
  try {
    const metrics = await calculateGoalMetrics(goalId);
    
    return {
      advice: `To achieve your goal, save KES ${metrics.dailySavings} daily, KES ${metrics.weekSavings} weekly, or KES ${metrics.monthSavings} monthly. You'll reach your goal in approximately ${metrics.monthsRemaining} months.`,
      metrics
    };
  } catch (error) {
    console.error('Error creating advice:', error);
    return { advice: 'Unable to generate advice', metrics: {} };
  }
};

// Initialize goals table
const initializeGoalsTable = () => {
  return new Promise((resolve) => {
    db.run(`
      CREATE TABLE IF NOT EXISTS goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL DEFAULT 0,
        target_date DATETIME,
        description TEXT,
        status TEXT DEFAULT 'active',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `, (err) => {
      if (err) console.error('Error creating goals table:', err);
      else console.log('✅ Goals table ready');
      resolve();
    });
  });
};
initializeDatabase().then(() => {
  initializeGoalsTable().then(() => {
    console.log('✅ All tables initialized');
  });
});

export default db;
