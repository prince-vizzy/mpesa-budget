import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
  CartesianGrid,
} from 'recharts';
import { ChartTooltip, Empty, Legend, ValueTable } from './ui';
import { KES, KES_COMPACT } from '../lib/selectors';

const AXIS = { fill: 'var(--text-muted)', fontSize: 11 };
const SURFACE = 'var(--surface-1)';

/** Single-line axis tick: the default one wraps on spaces. */
function EllipsisTick({ x, y, payload, max = 22 }) {
  const name = String(payload.value ?? '');
  return (
    <text
      x={x}
      y={y}
      dy={4}
      textAnchor="end"
      fill="var(--text-muted)"
      fontSize={11}
    >
      {name.length > max ? `${name.slice(0, max - 1)}…` : name}
    </text>
  );
}

/* ------------------------------------------------------------------ *
 * Where the money went — part-to-whole, so a donut.
 * ------------------------------------------------------------------ */

export function CategoryDonut({ data, height = 230 }) {
  if (!data.length) return <Empty>No spending in the selected months.</Empty>;

  const total = data.reduce((sum, d) => sum + d.value, 0);

  return (
    <>
      <ResponsiveContainer width="100%" height={height}>
        <PieChart>
          <Pie
            data={data}
            dataKey="value"
            nameKey="name"
            innerRadius={height * 0.27}
            outerRadius={height * 0.41}
            // The 2px separation is surface colour doing the work, not a border.
            paddingAngle={1.5}
            stroke={SURFACE}
            strokeWidth={2}
            isAnimationActive={false}
          >
            {data.map((slice) => (
              <Cell key={slice.name} fill={slice.color} />
            ))}
          </Pie>
          <Tooltip content={<ChartTooltip />} />
        </PieChart>
      </ResponsiveContainer>

      {/* Direct labels supplement the legend; both are required relief for the
          light-mode hues that fall below 3:1. */}
      <Legend
        items={data.map((d) => ({
          ...d,
          name: `${d.name} · ${Math.round((d.value / total) * 100)}%`,
        }))}
      />
    </>
  );
}

export function categoryTable(data) {
  const total = data.reduce((sum, d) => sum + d.value, 0);
  return (
    <ValueTable
      columns={[
        { key: 'name', label: 'Category' },
        { key: 'amount', label: 'Spent', numeric: true },
        { key: 'share', label: 'Share', numeric: true },
      ]}
      rows={data.map((d) => ({
        key: d.name,
        name: d.name,
        amount: KES.format(d.value),
        share: `${Math.round((d.value / total) * 100)}%`,
      }))}
    />
  );
}

/* ------------------------------------------------------------------ *
 * Spend over time — one series, so no legend box: the title names it.
 * ------------------------------------------------------------------ */

export function MonthlyTrend({ data, height = 210 }) {
  if (data.length < 2) {
    return <Empty>At least two months of data are needed for a trend.</Empty>;
  }

  const peak = data.reduce((max, d) => (d.value > max.value ? d : max), data[0]);

  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={data} margin={{ top: 8, right: 16, bottom: 0, left: -10 }}>
        <CartesianGrid stroke="var(--gridline)" vertical={false} />
        <XAxis
          dataKey="label"
          tick={AXIS}
          tickLine={false}
          axisLine={{ stroke: 'var(--baseline)' }}
        />
        <YAxis
          tick={AXIS}
          tickLine={false}
          axisLine={false}
          width={56}
          tickFormatter={(v) => KES_COMPACT.format(v)}
        />
        <Tooltip content={<ChartTooltip />} cursor={{ stroke: 'var(--baseline)' }} />
        <Area
          type="monotone"
          dataKey="value"
          name="Spent"
          stroke="var(--series-1)"
          strokeWidth={2}
          strokeLinejoin="round"
          strokeLinecap="round"
          fill="var(--series-1)"
          fillOpacity={0.1}
          isAnimationActive={false}
          // The ring keeps the marker legible where it crosses the line, and
          // makes the hover target bigger than the dot.
          activeDot={{ r: 5, stroke: SURFACE, strokeWidth: 2 }}
          dot={(props) =>
            props.payload.key === peak.key ? (
              <circle
                key={props.payload.key}
                cx={props.cx}
                cy={props.cy}
                r={4}
                fill="var(--series-1)"
                stroke={SURFACE}
                strokeWidth={2}
              />
            ) : null
          }
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}

export function trendTable(data) {
  return (
    <ValueTable
      columns={[
        { key: 'label', label: 'Month' },
        { key: 'amount', label: 'Spent', numeric: true },
      ]}
      rows={data.map((d) => ({ key: d.key, label: d.label, amount: KES.format(d.value) }))}
    />
  );
}

/* ------------------------------------------------------------------ *
 * Top payees — magnitude, so one hue rather than eight.
 * ------------------------------------------------------------------ */

export function TopPayees({ rows }) {
  if (!rows.length) {
    return <Empty>No named payees in the selected months.</Empty>;
  }

  return (
    <ResponsiveContainer width="100%" height={Math.max(rows.length * 34, 120)}>
      <BarChart
        data={rows}
        layout="vertical"
        margin={{ top: 0, right: 56, bottom: 0, left: 0 }}
        barCategoryGap={8}
      >
        <XAxis type="number" hide />
        <YAxis
          type="category"
          dataKey="name"
          tick={<EllipsisTick />}
          tickLine={false}
          axisLine={false}
          width={150}
          interval={0}
        />
        <Tooltip content={<ChartTooltip />} cursor={{ fill: 'var(--gridline)' }} />
        <Bar
          dataKey="value"
          name="Spent"
          fill="var(--seq-450)"
          // Rounded at the data end, square at the baseline.
          radius={[0, 4, 4, 0]}
          barSize={16}
          isAnimationActive={false}
          label={{
            position: 'right',
            fill: 'var(--text-secondary)',
            fontSize: 11,
            formatter: (v) => KES_COMPACT.format(v),
          }}
        />
      </BarChart>
    </ResponsiveContainer>
  );
}

export function payeeTable(rows) {
  return (
    <ValueTable
      columns={[
        { key: 'name', label: 'Payee' },
        { key: 'amount', label: 'Spent', numeric: true },
      ]}
      rows={rows.map((r) => ({ key: r.name, name: r.name, amount: KES.format(r.value) }))}
    />
  );
}

/* ------------------------------------------------------------------ *
 * Month comparison — distinct series, so categorical colour.
 * ------------------------------------------------------------------ */

export function MonthlyByCategory({ rows, series, height = 380 }) {
  if (!rows.length) return <Empty>No spending to compare yet.</Empty>;

  return (
    <>
      <ResponsiveContainer width="100%" height={height}>
        <BarChart data={rows} margin={{ top: 8, right: 16, bottom: 0, left: -10 }}>
          <CartesianGrid stroke="var(--gridline)" vertical={false} />
          <XAxis
            dataKey="label"
            tick={AXIS}
            tickLine={false}
            axisLine={{ stroke: 'var(--baseline)' }}
          />
          <YAxis
            tick={AXIS}
            tickLine={false}
            axisLine={false}
            width={56}
            tickFormatter={(v) => KES_COMPACT.format(v)}
          />
          <Tooltip content={<ChartTooltip />} cursor={{ fill: 'var(--gridline)' }} />
          {series.map((s, i) => (
            <Bar
              key={s.name}
              dataKey={s.name}
              stackId="spend"
              fill={s.color}
              isAnimationActive={false}
              // A 2px gap in the surface colour separates the segments; the
              // rounded cap belongs only to the topmost one.
              stroke="var(--surface-1)"
              strokeWidth={2}
              radius={i === series.length - 1 ? [4, 4, 0, 0] : 0}
            />
          ))}
        </BarChart>
      </ResponsiveContainer>

      <Legend items={series} />
    </>
  );
}

export function monthlyByCategoryTable(rows, series) {
  return (
    <ValueTable
      columns={[
        { key: 'label', label: 'Month' },
        ...series.map((s) => ({ key: s.name, label: s.name, numeric: true })),
      ]}
      rows={rows.map((row) => {
        const out = { key: row.key, label: row.label };
        for (const s of series) out[s.name] = KES.format(row[s.name] ?? 0);
        return out;
      })}
    />
  );
}
