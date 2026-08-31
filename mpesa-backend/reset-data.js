/**
 * Empties the dashboard database so it holds only what the Flutter app syncs.
 *
 * The backend ships with `generate-data.js`, which fills the database with
 * invented transactions for demoing the UI. Once you are tracking real spending
 * that fake data is worse than nothing — it inflates every total and every
 * chart. Run this to clear it out.
 *
 *   node reset-data.js            # asks first, then clears
 *   node reset-data.js --yes      # no prompt (for scripts)
 *
 * This does not touch the phone. The app keeps its own database and re-syncs
 * everything the next time you open it, so nothing real is lost.
 */

import readline from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import sqlite3 from 'sqlite3';

const DB_PATH = './data/transactions.db';

const db = new sqlite3.Database(DB_PATH);

const run = (sql) =>
  new Promise((resolve, reject) =>
    db.run(sql, function (err) {
      if (err) reject(err);
      else resolve(this.changes);
    }),
  );

const get = (sql) =>
  new Promise((resolve, reject) =>
    db.get(sql, (err, row) => (err ? reject(err) : resolve(row))),
  );

async function main() {
  const before = await get(
    `SELECT
       (SELECT COUNT(*) FROM transactions) AS transactions,
       (SELECT COUNT(*) FROM categories)   AS categories`,
  );

  if (before.transactions === 0 && before.categories === 0) {
    console.log('Already empty — nothing to do.');
    return;
  }

  console.log(
    `About to delete ${before.transactions} transaction(s) and ` +
      `${before.categories} category/categories from ${DB_PATH}.`,
  );

  if (!process.argv.includes('--yes')) {
    const rl = readline.createInterface({ input: stdin, output: stdout });
    const answer = await rl.question('Type "yes" to continue: ');
    rl.close();
    if (answer.trim().toLowerCase() !== 'yes') {
      console.log('Cancelled. Nothing was changed.');
      return;
    }
  }

  await run('DELETE FROM transactions');
  await run('DELETE FROM categories');
  // Restart the id counters so real data starts from 1.
  await run("DELETE FROM sqlite_sequence WHERE name IN ('transactions','categories')");
  await run('VACUUM');

  const after = await get(
    `SELECT
       (SELECT COUNT(*) FROM transactions) AS transactions,
       (SELECT COUNT(*) FROM categories)   AS categories`,
  );

  console.log(
    `Done. transactions=${after.transactions}, categories=${after.categories}.`,
  );
  console.log('Open the app with the backend running to sync your real spending.');
}

main()
  .catch((error) => {
    console.error('Reset failed:', error.message);
    process.exitCode = 1;
  })
  .finally(() => db.close());
