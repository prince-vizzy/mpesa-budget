import { monthLabel } from '../lib/selectors';

/**
 * The reference template's horizontal month menu: click to focus one month,
 * ctrl/cmd-click to compare several. Filters sit in one row above the charts.
 *
 * An empty selection means "all months" rather than "nothing", so the dashboard
 * is never blank.
 */
export function MonthStrip({ months, selected, onChange }) {
  if (!months.length) return null;

  function toggle(key, additive) {
    if (!additive) {
      onChange(selected.length === 1 && selected[0] === key ? [] : [key]);
      return;
    }
    onChange(
      selected.includes(key)
        ? selected.filter((m) => m !== key)
        : [...selected, key],
    );
  }

  return (
    <div className="month-strip" role="group" aria-label="Filter by month">
      <button
        type="button"
        className="month-chip"
        aria-pressed={selected.length === 0}
        onClick={() => onChange([])}
      >
        All
      </button>

      {months.map((key) => (
        <button
          key={key}
          type="button"
          className="month-chip"
          aria-pressed={selected.includes(key)}
          onClick={(e) => toggle(key, e.ctrlKey || e.metaKey)}
        >
          {monthLabel(key)}
        </button>
      ))}

      <span className="hint">Ctrl/⌘-click to compare months</span>
    </div>
  );
}
