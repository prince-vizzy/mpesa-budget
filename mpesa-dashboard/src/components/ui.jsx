import { KES } from '../lib/selectors';

/** Identity never rests on colour alone, so this is always shown for 2+ series. */
export function Legend({ items }) {
  return (
    <div className="legend">
      {items.map((item) => (
        <span className="legend-item" key={item.name}>
          <span className="legend-swatch" style={{ background: item.color }} />
          {item.name}
        </span>
      ))}
    </div>
  );
}

export function ChartTooltip({ active, payload, label, labelKey }) {
  if (!active || !payload?.length) return null;

  const heading = label ?? payload[0]?.payload?.[labelKey];

  return (
    <div className="tooltip">
      {heading && <div className="tooltip-label">{heading}</div>}
      {payload.map((entry) => (
        <div className="tooltip-row" key={entry.dataKey ?? entry.name}>
          <span>{entry.name}</span>
          <span className="val">{KES.format(entry.value)}</span>
        </div>
      ))}
    </div>
  );
}

export function ValueTable({ columns, rows }) {
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            {columns.map((c) => (
              <th key={c.key} className={c.numeric ? 'num' : undefined}>
                {c.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr key={row.key ?? i}>
              {columns.map((c) => (
                <td
                  key={c.key}
                  className={c.numeric ? 'num' : c.wrap ? 'wrap' : undefined}
                >
                  {row[c.key]}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function Empty({ children }) {
  return <div className="empty">{children}</div>;
}
