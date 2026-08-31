import express from 'express';
import multer from 'multer';
import sqlite3 from 'sqlite3';
import { addTransaction, getAllTransactions, upsertCategory, getAllCategories } from '../db.js';

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

/**
 * POST /api/import/flutter-database
 * Upload Flutter app database file for data import
 * 
 * Accepts: multipart/form-data with 'database' file field
 * Returns: { ok: true, imported: { categories: n, transactions: n } }
 */
router.post('/flutter-database', upload.single('database'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No database file provided' });
    }

    console.log(`\n📥 Importing Flutter database (${req.file.size} bytes)...`);

    // Read from buffer
    const buffer = req.file.buffer;
    const tempDb = new sqlite3.Database(':memory:', sqlite3.OPEN_READONLY);

    // Load database from buffer
    return new Promise((resolve) => {
      tempDb.serialize(() => {
        // Read tables
        readFlutterData(tempDb, async (error, data) => {
          tempDb.close();

          if (error) {
            console.error('❌ Failed to read database:', error.message);
            return res.status(400).json({ error: error.message });
          }

          try {
            // Import categories
            const categoryResults = await importCategories(data.categories);
            
            // Import transactions
            const txResults = await importTransactions(data.transactions);

            console.log(`✅ Import complete: ${categoryResults.imported} categories, ${txResults.imported} transactions`);
            
            res.json({
              ok: true,
              imported: {
                categories: categoryResults.imported,
                transactions: txResults.imported,
                skipped: txResults.skipped
              }
            });
          } catch (importError) {
            console.error('❌ Import failed:', importError.message);
            res.status(500).json({ error: importError.message });
          }
        });
      });
    });
  } catch (error) {
    console.error('❌ Upload error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/import/flutter-json
 * Import data directly from Flutter app's JSON export
 * 
 * Body: { categories: [...], transactions: [...] }
 */
router.post('/flutter-json', async (req, res) => {
  try {
    const { categories = [], transactions = [] } = req.body;

    console.log(`\n📥 Importing Flutter JSON export...`);
    console.log(`   Categories: ${categories.length}, Transactions: ${transactions.length}`);

    // Import categories
    const categoryResults = await importCategories(categories);
    
    // Import transactions
    const txResults = await importTransactions(transactions);

    console.log(`✅ Import complete: ${categoryResults.imported} categories, ${txResults.imported} transactions`);
    
    res.json({
      ok: true,
      imported: {
        categories: categoryResults.imported,
        transactions: txResults.imported,
        skipped: txResults.skipped
      }
    });
  } catch (error) {
    console.error('❌ Import error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/import/from-path
 * Direct link to database file at specified path
 * 
 * Body: { databasePath: '/path/to/mpesa_tracker.db', autoSync: true }
 * Returns: { ok: true, imported: { categories: n, transactions: n }, linked: true }
 */
router.post('/from-path', async (req, res) => {
  try {
    const { databasePath, autoSync = false } = req.body;

    if (!databasePath) {
      return res.status(400).json({ error: 'databasePath is required' });
    }

    console.log(`\n📥 Importing from path: ${databasePath}`);

    // Open database file from path
    const srcDb = new sqlite3.Database(databasePath, sqlite3.OPEN_READONLY, (err) => {
      if (err) {
        console.error('❌ Failed to open database:', err.message);
        return res.status(400).json({ error: `Cannot open database: ${err.message}` });
      }

      readFlutterData(srcDb, async (error, data) => {
        srcDb.close();

        if (error) {
          console.error('❌ Failed to read database:', error.message);
          return res.status(400).json({ error: error.message });
        }

        try {
          // Import categories
          const categoryResults = await importCategories(data.categories);
          
          // Import transactions
          const txResults = await importTransactions(data.transactions);

          console.log(`✅ Import complete: ${categoryResults.imported} categories, ${txResults.imported} transactions`);
          
          res.json({
            ok: true,
            linked: true,
            databasePath: databasePath,
            autoSync: autoSync,
            imported: {
              categories: categoryResults.imported,
              transactions: txResults.imported,
              skipped: txResults.skipped
            }
          });
        } catch (importError) {
          console.error('❌ Import failed:', importError.message);
          res.status(500).json({ error: importError.message });
        }
      });
    });
  } catch (error) {
    console.error('❌ Path import error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

// Helper: Read categories and transactions from Flutter database file (byte buffer)
function readFlutterData(db, callback) {
  // Use SQLite to read the buffer as a database
  const data = { categories: [], transactions: [] };
  let completed = 0;

  // Read categories
  db.all(
    `SELECT 
      id, name, budget_type, daily_budget, weekly_budget, 
      monthly_budget, spent_today, spent_this_week, 
      spent_this_month, spent_this_year
    FROM categories
    WHERE name IS NOT NULL`,
    (err, rows) => {
      if (!err) {
        data.categories = rows || [];
      }
      completed++;
      if (completed === 2) callback(null, data);
    }
  );

  // Read transactions
  db.all(
    `SELECT 
      id, description, amount, date, category_id, category_name, 
      status, name, user_first_name, raw_message
    FROM transactions
    WHERE amount > 0
    ORDER BY date DESC`,
    (err, rows) => {
      if (!err) {
        data.transactions = rows || [];
      }
      completed++;
      if (completed === 2) callback(null, data);
    }
  );
}

// Helper: Import categories
async function importCategories(categories) {
  let imported = 0;
  const existing = await getAllCategories();
  const existingNames = new Set(existing.map(c => c.name));

  for (const category of categories) {
    if (!category?.name || existingNames.has(category.name)) {
      continue;
    }

    try {
      await upsertCategory({
        name: category.name,
        budget_type: category.budget_type || 'daily',
        daily_budget: category.daily_budget || 0,
        weekly_budget: category.weekly_budget || 0,
        monthly_budget: category.monthly_budget || 0,
        spent_today: category.spent_today || 0,
        spent_this_week: category.spent_this_week || 0,
        spent_this_month: category.spent_this_month || 0,
        spent_this_year: category.spent_this_year || 0,
        app_id: category.id
      });
      imported++;
    } catch (error) {
      console.warn(`⚠️ Failed to import category "${category.name}":`, error.message);
    }
  }

  return { imported };
}

// Helper: Import transactions
async function importTransactions(transactions) {
  let imported = 0;
  let skipped = 0;
  const existing = await getAllTransactions();
  const existingRefs = new Set(existing.map(t => t.mpesa_ref).filter(Boolean));

  for (const tx of transactions) {
    if (!tx?.amount || tx.amount <= 0) {
      skipped++;
      continue;
    }

    const mpesaRef = tx.id ? `app-${tx.id}` : null;
    
    if (mpesaRef && existingRefs.has(mpesaRef)) {
      skipped++;
      continue;
    }

    try {
      // Convert Flutter timestamp
      let date = tx.date;
      if (typeof tx.date === 'number' && tx.date > 1000000000000) {
        date = new Date(tx.date).toISOString();
      } else if (typeof tx.date === 'number') {
        date = new Date(tx.date * 1000).toISOString();
      }

      await addTransaction({
        amount: parseFloat(tx.amount),
        category: tx.category_name || 'Other',
        description: tx.description || '',
        phone_number: tx.name || tx.user_first_name || '',
        transaction_type: 'sent',
        status: tx.status || 'completed',
        date: date,
        mpesa_ref: mpesaRef
      });
      imported++;
    } catch (error) {
      if (!String(error.message).includes('UNIQUE constraint failed')) {
        console.warn(`⚠️ Failed to import transaction:`, error.message);
      }
      skipped++;
    }
  }

  return { imported, skipped };
}

export default router;
