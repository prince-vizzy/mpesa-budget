/**
 * Everything the panels read is derived here, so each chart takes a plain array
 * and holds no opinion about where the data came from.
 */

/** Categorical slot order. Assigned by fixed index, never cycled. */
export const SERIES_SLOTS = [
  'var(--series-1)',
  'var(--series-2)',
  'var(--series-3)',
  'var(--series-4)',
  'var(--series-5)',
  'var(--series-6)',
  'var(--series-7)',
  'var(--series-8)',
];

export const OTHER_COLOR = 'var(--series-other)';

/**
 * Past this many slices the tail folds into "Other".
 *
 * Six rather than the token ceiling of eight: a donut asks the reader to
 * compare non-adjacent arcs, and the fixed order only guarantees separation
 * between neighbours.
 */
const MAX_SLICES = 6;

export const KES = new Intl.NumberFormat('en-KE', {
  style: 'currency',
  currency: 'KES',
  maximumFractionDigits: 0,
});

export const KES_COMPACT = new Intl.NumberFormat('en-KE', {
  notation: 'compact',
  maximumFractionDigits: 1,
});

const MONTH_LABEL = new Intl.DateTimeFormat('en', {
  month: 'short',
  year: '2-digit',
});

export function monthKeyOf(dateish) {
  const date = new Date(dateish);
  if (Number.isNaN(date.valueOf())) return null;
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

export function monthLabel(key) {
  const [year, month] = key.split('-').map(Number);
  return MONTH_LABEL.format(new Date(year, month - 1, 1));
}

const amountOf = (tx) => Math.abs(Number(tx.amount) || 0);

/** Every month present in the data, oldest first. */
export function monthsIn(transactions) {
  const keys = new Set();
  for (const tx of transactions) {
    const key = monthKeyOf(tx.date);
    if (key) keys.add(key);
  }
  return [...keys].sort();
}

export function filterByMonths(transactions, months) {
  if (!months.length) return transactions;
  const wanted = new Set(months);
  return transactions.filter((tx) => wanted.has(monthKeyOf(tx.date)));
}

/** Groups spend by a key, largest first, with the tail folded into "Other". */
function rankByKey(transactions, keyOf, { limit = MAX_SLICES, fold = true } = {}) {
  const totals = new Map();
  for (const tx of transactions) {
    const key = keyOf(tx);
    if (!key) continue;
    totals.set(key, (totals.get(key) ?? 0) + amountOf(tx));
  }

  const ranked = [...totals.entries()]
    .map(([name, value]) => ({ name, value }))
    .sort((a, b) => b.value - a.value);

  if (!fold || ranked.length <= limit) {
    return ranked.map((row, i) => ({ ...row, color: SERIES_SLOTS[i] ?? OTHER_COLOR }));
  }

  const head = ranked.slice(0, limit).map((row, i) => ({ ...row, color: SERIES_SLOTS[i] }));
  const tail = ranked.slice(limit);
  head.push({
    // Deliberately not "Other": that is a category people actually create, and
    // two legend entries reading the same word tell the reader nothing.
    name: `${tail.length} smaller categor${tail.length === 1 ? 'y' : 'ies'}`,
    value: tail.reduce((sum, row) => sum + row.value, 0),
    color: OTHER_COLOR,
    foldedCount: tail.length,
  });
  return head;
}

export function spendByCategory(transactions) {
  return rankByKey(transactions, (tx) => tx.category || 'Uncategorized');
}

/**
 * Ranked payees. Transactions the app could not name (airtime top-ups, some
 * agent withdrawals) have no payee and are left out rather than lumped into a
 * misleading bucket.
 */
export function spendByPayee(transactions, limit = 8) {
  const named = transactions.filter((tx) => (tx.payee ?? '').trim());
  const ranked = rankByKey(named, (tx) => tx.payee.trim(), { fold: false });
  return {
    rows: ranked.slice(0, limit),
    unnamed: transactions.length - named.length,
  };
}

/** Total spend per month across the whole dataset, oldest first. */
export function monthlyTotals(transactions) {
  const totals = new Map();
  for (const tx of transactions) {
    const key = monthKeyOf(tx.date);
    if (!key) continue;
    totals.set(key, (totals.get(key) ?? 0) + amountOf(tx));
  }
  return [...totals.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => ({ key, label: monthLabel(key), value }));
}

/** The budget a category is measured against, scaled to the months in view. */
function budgetFor(category, monthCount) {
  const monthly =
    category.budget_type === 'monthly'
      ? Number(category.monthly_budget) || 0
      : (Number(category.daily_budget) || 0) * 30;
  return monthly * Math.max(monthCount, 1);
}

export function budgetComparison(transactions, categories, monthCount) {
  const spent = new Map();
  for (const tx of transactions) {
    const key = tx.category || 'Uncategorized';
    spent.set(key, (spent.get(key) ?? 0) + amountOf(tx));
  }

  return categories
    .map((category) => {
      const used = spent.get(category.name) ?? 0;
      const budget = budgetFor(category, monthCount);
      return {
        name: category.name,
        spent: used,
        budget,
        over: budget > 0 && used > budget,
        usage: budget > 0 ? used / budget : null,
      };
    })
    .filter((row) => row.spent > 0 || row.budget > 0)
    .sort((a, b) => b.spent - a.spent);
}

export function summarize(transactions, categories, monthCount) {
  const total = transactions.reduce((sum, tx) => sum + amountOf(tx), 0);
  const budget = categories.reduce((sum, c) => sum + budgetFor(c, monthCount), 0);
  const days = Math.max(monthCount, 1) * 30;

  return {
    total,
    budget,
    count: transactions.length,
    perDay: total / days,
    usage: budget > 0 ? total / budget : null,
    largest: transactions.reduce(
      (max, tx) => (amountOf(tx) > amountOf(max ?? { amount: 0 }) ? tx : max),
      null,
    ),
  };
}

/* ------------------------------------------------------------------ *
 * Extra shapes for the detail scenes
 * ------------------------------------------------------------------ */

/** Spend per calendar day, keyed `YYYY-MM-DD`. */
export function dailyTotals(transactions) {
  const totals = new Map();
  for (const tx of transactions) {
    const date = new Date(tx.date);
    if (Number.isNaN(date.valueOf())) continue;
    const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(
      date.getDate(),
    ).padStart(2, '0')}`;
    totals.set(key, (totals.get(key) ?? 0) + amountOf(tx));
  }
  return totals;
}

/**
 * Spend per month split by the leading categories, for the grouped bar scene.
 *
 * The split is capped at the adjacent-safe series count and the tail folded, so
 * the bars never need a ninth colour.
 */
export function monthlyByCategory(transactions, limit = 4) {
  const leaders = spendByCategory(transactions)
    .filter((row) => !row.foldedCount)
    .slice(0, limit)
    .map((row) => row.name);

  const byMonth = new Map();
  for (const tx of transactions) {
    const key = monthKeyOf(tx.date);
    if (!key) continue;
    const category = tx.category || 'Uncategorized';
    const bucket = leaders.includes(category) ? category : 'Other categories';

    if (!byMonth.has(key)) byMonth.set(key, { key, label: monthLabel(key) });
    const row = byMonth.get(key);
    row[bucket] = (row[bucket] ?? 0) + amountOf(tx);
  }

  const keys = [...leaders, 'Other categories'];
  const rows = [...byMonth.values()].sort((a, b) => a.key.localeCompare(b.key));
  // Recharts needs every key present on every row or the stack gaps.
  for (const row of rows) {
    for (const key of keys) row[key] ??= 0;
  }

  return {
    rows,
    series: keys.map((name, i) => ({
      name,
      color: name === 'Other categories' ? OTHER_COLOR : SERIES_SLOTS[i],
    })),
  };
}

/** Per-payee totals with transaction counts, for the payees grid. */
export function payeeRollup(transactions) {
  const rollup = new Map();
  for (const tx of transactions) {
    const name = (tx.payee ?? '').trim();
    if (!name) continue;
    const row = rollup.get(name) ?? {
      name,
      total: 0,
      count: 0,
      categories: new Set(),
      last: null,
    };
    row.total += amountOf(tx);
    row.count += 1;
    if (tx.category) row.categories.add(tx.category);
    const date = new Date(tx.date);
    if (!Number.isNaN(date.valueOf()) && (!row.last || date > row.last)) row.last = date;
    rollup.set(name, row);
  }

  return [...rollup.values()]
    .map((row) => ({
      ...row,
      average: row.total / row.count,
      categories: [...row.categories],
    }))
    .sort((a, b) => b.total - a.total);
}
