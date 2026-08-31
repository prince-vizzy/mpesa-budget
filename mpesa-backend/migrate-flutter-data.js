#!/usr/bin/env node

/**
 * Flutter to Dashboard Data Migration Tool
 * Reads real data from Flutter app database and imports to dashboard backend
 * 
 * Usage:
 * node migrate-flutter-data.js <path-to-flutter-database.db>
 * 
 * On Android devices/emulators:
 * adb pull /data/data/com.example.mpesa_tracker/databases/mpesa_tracker.db ./mpesa_tracker.db
 */

import sqlite3 from 'sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';
import { 
  addTransaction, 
  getAllTransactions, 
  getAllCategories, 
  upsertCategory 
} from './db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

if (process.argv.length < 3) {
  console.log(`
╔════════════════════════════════════════════════════════════╗
║  Flutter M-Pesa Data Migration Tool                        ║
║  Imports real data from Flutter app to dashboard backend   ║
╚════════════════════════════════════════════════════════════╝

USAGE:
  node migrate-flutter-data.js <path-to-database.db>

EXAMPLE (Android emulator):
  1. First pull the database from device:
     adb pull /data/data/com.example.mpesa_tracker/databases/mpesa_tracker.db .
  
  2. Then run migration:
     node migrate-flutter-data.js ./mpesa_tracker.db

EXAMPLE (Development):
  node migrate-flutter-data.js /path/to/your/flutter/app/database.db
  `);
  process.exit(1);
}

const flutterDbPath = process.argv[2];

console.log('╔════════════════════════════════════════════════════════════╗');
console.log('║ Starting Flutter Data Migration...                         ║');
console.log('╚════════════════════════════════════════════════════════════╝\n');

// Open Flutter database (read-only)
const flutterDb = new sqlite3.Database(flutterDbPath, sqlite3.OPEN_READONLY, (err) => {
  if (err) {
    console.error('❌ Failed to open Flutter database:', err.message);
    process.exit(1);
  }
  console.log('✅ Connected to Flutter database:', flutterDbPath);
  migrateData();
});

async function migrateData() {
  try {
    // 1. Migrate categories
    console.log('\n📂 Reading categories...');
    const categories = await readFlutterCategories();
    console.log(`   Found ${categories.length} categories`);
    
    const categoryResults = await migrateCategories(categories);
    console.log(`   ✅ Imported ${categoryResults.imported} new categories\n`);

    // 2. Migrate transactions
    console.log('💰 Reading transactions...');
    const transactions = await readFlutterTransactions();
    console.log(`   Found ${transactions.length} transactions`);
    
    const txResults = await migrateTransactions(transactions);
    console.log(`   ✅ Imported ${txResults.imported} new transactions`);
    console.log(`   ⏭️  Skipped ${txResults.skipped} existing transactions\n`);

    // 3. Summary
    console.log('╔════════════════════════════════════════════════════════════╗');
    console.log('║ Migration Complete                                        ║');
    console.log('╚════════════════════════════════════════════════════════════╝');
    console.log(`
📊 Summary:
   • Categories: ${categoryResults.imported} imported
   • Transactions: ${txResults.imported} imported, ${txResults.skipped} skipped
   
🎯 Next Steps:
   1. Refresh your dashboard at http://localhost:3000
   2. Your real data should now appear on all charts
   3. The sync service will keep data updated automatically
    `);

    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    process.exit(1);
  } finally {
    flutterDb.close();
  }
}

function readFlutterCategories() {
  return new Promise((resolve, reject) => {
    flutterDb.all(
      `SELECT 
        id, name, budget_type, daily_budget, weekly_budget, 
        monthly_budget, spent_today, spent_this_week, 
        spent_this_month, spent_this_year
      FROM categories
      WHERE name IS NOT NULL`,
      (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      }
    );
  });
}

function readFlutterTransactions() {
  return new Promise((resolve, reject) => {
    flutterDb.all(
      `SELECT 
        id, description, amount, date, category_id, category_name, 
        status, name, user_first_name, raw_message
      FROM transactions
      WHERE amount > 0
      ORDER BY date DESC`,
      (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      }
    );
  });
}

async function migrateCategories(flutterCategories) {
  let imported = 0;
  const existing = await getAllCategories();
  const existingNames = new Set(existing.map(c => c.name));

  for (const category of flutterCategories) {
    if (existingNames.has(category.name)) {
      continue; // Skip if already exists
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
      console.warn(`   ⚠️  Failed to import category "${category.name}":`, error.message);
    }
  }

  return { imported };
}

async function migrateTransactions(flutterTransactions) {
  let imported = 0;
  let skipped = 0;
  const existing = await getAllTransactions();
  const existingRefs = new Set(existing.map(t => t.mpesa_ref).filter(Boolean));

  for (const tx of flutterTransactions) {
    if (!tx.amount || tx.amount <= 0) {
      skipped++;
      continue;
    }

    const mpesaRef = tx.id ? `app-${tx.id}` : null;
    
    // Skip if already imported
    if (mpesaRef && existingRefs.has(mpesaRef)) {
      skipped++;
      continue;
    }

    try {
      // Convert Flutter timestamp (milliseconds) to ISO string if needed
      let date = tx.date;
      if (typeof tx.date === 'number' && tx.date > 1000000000000) {
        // It's a millisecond timestamp
        date = new Date(tx.date).toISOString();
      } else if (typeof tx.date === 'number') {
        // It's a second timestamp
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
        console.warn(
          `   ⚠️  Failed to import transaction "${tx.description}" (${tx.amount}):`,
          error.message
        );
      }
      skipped++;
    }
  }

  return { imported, skipped };
}
