import { KES } from '../lib/selectors';
import { Empty, ValueTable } from './ui';

/**
 * A ratio against a limit is a meter, not a chart.
 *
 * Severity rides the fill; the unfilled track is a lighter step of the same
 * ramp so state reads across the whole bar. Over-budget is additionally called
 * out with an icon and the word, because a status colour never carries meaning
 * on its own.
 */

function severityOf(usage) {
  if (usage === null) return 'normal';
  if (usage > 1) return 'critical';
  if (usage >= 0.85) return 'warning';
  return 'normal';
}

export function BudgetMeters({ rows }) {
  if (!rows.length) return <Empty>No categories with a budget or spending yet.</Empty>;

  return (
    <div>
      {rows.map((row) => {
        const state = severityOf(row.usage);
        const pct = row.usage === null ? null : Math.round(row.usage * 100);

        return (
          <div className="meter-row" key={row.name}>
            <span className="meter-name">{row.name}</span>
            <span className="meter-value">
              {pct === null ? 'No budget' : `${pct}%`}
            </span>

            <div className="meter-track">
              <div
                className="meter-fill"
                data-state={state}
                style={{ width: `${Math.min(row.usage ?? 0, 1) * 100}%` }}
              />
            </div>

            <div className="meter-foot">
              <span>{KES.format(row.spent)} spent</span>
              {row.over ? (
                <span className="flag">
                  <span aria-hidden="true">▲</span> Over by{' '}
                  {KES.format(row.spent - row.budget)}
                </span>
              ) : (
                <span>{row.budget > 0 ? `of ${KES.format(row.budget)}` : '—'}</span>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}

export function budgetTable(rows) {
  return (
    <ValueTable
      columns={[
        { key: 'name', label: 'Category' },
        { key: 'spent', label: 'Spent', numeric: true },
        { key: 'budget', label: 'Budget', numeric: true },
        { key: 'usage', label: 'Used', numeric: true },
      ]}
      rows={rows.map((r) => ({
        key: r.name,
        name: r.name,
        spent: KES.format(r.spent),
        budget: r.budget > 0 ? KES.format(r.budget) : '—',
        usage: r.usage === null ? '—' : `${Math.round(r.usage * 100)}%`,
      }))}
    />
  );
}
