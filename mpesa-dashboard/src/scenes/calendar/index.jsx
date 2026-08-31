import { useMemo, useState } from 'react';
import { Box, Paper, Tooltip, Typography, useTheme } from '@mui/material';
import Header from '../../components/Header';
import Panel from '../../components/Panel';
import { useData } from '../../lib/DataContext';
import { dailyTotals, KES, monthLabel, monthsIn } from '../../lib/selectors';
import { tokens } from '../../theme';

const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/**
 * Spend per day, as a calendar heatmap.
 *
 * Magnitude, so one hue light-to-dark rather than a categorical set. The
 * lightest step means "near zero" and is allowed to recede toward the surface;
 * a day with no spending gets the surface itself plus a hairline, so "nothing"
 * and "a little" never look the same.
 */
const RAMP = [
  'var(--seq-250)',
  'var(--seq-350)',
  'var(--seq-450)',
  'var(--seq-550)',
  'var(--seq-600)',
];

/**
 * Quantile edges rather than an even split of the range.
 *
 * Spending is lopsided — one big day dwarfs the rest — and a linear scale puts
 * almost every day in the first step, wasting the ramp. Cutting at quantiles
 * gives each step roughly a fifth of the days that had any spending, so the
 * calendar actually separates a quiet day from a busy one.
 */
function thresholdsFrom(values) {
  const sorted = [...values].filter((v) => v > 0).sort((a, b) => a - b);
  if (!sorted.length) return [];
  return [0.2, 0.4, 0.6, 0.8].map((q) => sorted[Math.floor(q * (sorted.length - 1))]);
}

function stepIndex(value, thresholds) {
  if (!value) return null;
  let index = 0;
  while (index < thresholds.length && value > thresholds[index]) index += 1;
  return Math.min(index, RAMP.length - 1);
}

function MonthGrid({ monthKey, totals, thresholds }) {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);
  const dark = theme.palette.mode === 'dark';

  const [year, month] = monthKey.split('-').map(Number);
  const first = new Date(year, month - 1, 1);
  const daysInMonth = new Date(year, month, 0).getDate();
  // Monday-first, matching the weekday header.
  const leading = (first.getDay() + 6) % 7;

  const cells = [
    ...Array.from({ length: leading }, () => null),
    ...Array.from({ length: daysInMonth }, (_, i) => i + 1),
  ];

  return (
    <Box>
      <Typography variant="h5" sx={{ mb: 1 }}>
        {monthLabel(monthKey)}
      </Typography>

      <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 0.5 }}>
        {WEEKDAYS.map((day) => (
          <Typography
            key={day}
            variant="caption"
            align="center"
            sx={{ color: colors.textMuted }}
          >
            {day[0]}
          </Typography>
        ))}

        {cells.map((day, i) => {
          if (day === null) return <Box key={`pad-${i}`} />;

          const key = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
          const value = totals.get(key) ?? 0;
          const index = stepIndex(value, thresholds);
          const fill = index === null ? null : RAMP[index];
          // Pale fills need ink, dark fills need white — and which end is pale
          // flips with the mode, because the ramp is stepped for its surface.
          const onFill = index === null
            ? colors.textMuted
            : (dark ? index <= 1 : index >= 2)
              ? '#ffffff'
              : '#0b0b0b';

          return (
            <Tooltip
              key={key}
              title={
                value
                  ? `${day} ${monthLabel(monthKey)} · ${KES.format(value)}`
                  : `${day} ${monthLabel(monthKey)} · nothing spent`
              }
            >
              <Box
                sx={{
                  aspectRatio: '1',
                  borderRadius: 1,
                  display: 'grid',
                  placeItems: 'center',
                  fontSize: 11,
                  // No spending is the surface plus a hairline, so it never
                  // reads as a small amount.
                  background: fill ?? 'transparent',
                  border: fill ? 'none' : `1px solid ${colors.gridline}`,
                  color: onFill,
                  fontVariantNumeric: 'tabular-nums',
                }}
              >
                {day}
              </Box>
            </Tooltip>
          );
        })}
      </Box>
    </Box>
  );
}

export default function CalendarScene() {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);
  const { transactions } = useData();

  const totals = useMemo(() => dailyTotals(transactions), [transactions]);
  const thresholds = useMemo(() => thresholdsFrom([...totals.values()]), [totals]);
  const allMonths = useMemo(() => monthsIn(transactions), [transactions]);

  const [count, setCount] = useState(6);
  const shown = allMonths.slice(-count);

  const busiest = useMemo(() => {
    let best = null;
    for (const [key, value] of totals) {
      if (!best || value > best.value) best = { key, value };
    }
    return best;
  }, [totals]);

  return (
    <Box>
      <Header
        title="Daily calendar"
        subtitle="Spend per day. Darker is more — one hue, because this is magnitude rather than identity."
      />

      <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(12, 1fr)', gap: 2, '& > *': { minWidth: 0 } }}>
        <Box sx={{ gridColumn: { xs: 'span 12', md: 'span 4' } }}>
          <Paper elevation={0} sx={{ p: 2, border: `1px solid ${colors.border}` }}>
            <Typography variant="h5">Busiest day</Typography>
            <Typography variant="h2" sx={{ mt: 1 }}>
              {busiest ? KES.format(busiest.value) : '—'}
            </Typography>
            <Typography variant="body2" color="text.secondary">
              {busiest
                ? new Date(busiest.key).toLocaleDateString('en-GB', {
                    day: 'numeric',
                    month: 'long',
                    year: 'numeric',
                  })
                : 'No spending recorded'}
            </Typography>

            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mt: 2, flexWrap: 'wrap' }}>
              <Typography variant="caption" color="text.secondary">
                Less
              </Typography>
              {RAMP.map((step) => (
                <Box
                  key={step}
                  sx={{ width: 16, height: 16, borderRadius: 0.75, background: step }}
                />
              ))}
              <Typography variant="caption" color="text.secondary">
                More
              </Typography>
            </Box>

            <Box sx={{ mt: 2 }}>
              {[3, 6, 12].map((n) => (
                <Typography
                  key={n}
                  component="button"
                  variant="caption"
                  onClick={() => setCount(n)}
                  sx={{
                    mr: 1,
                    px: 1,
                    py: 0.5,
                    border: `1px solid ${count === n ? colors.textMuted : colors.border}`,
                    borderRadius: 1,
                    background: count === n ? colors.page : 'transparent',
                    color: colors.textSecondary,
                    cursor: 'pointer',
                    font: 'inherit',
                  }}
                >
                  Last {n}
                </Typography>
              ))}
            </Box>
          </Paper>
        </Box>

        <Box sx={{ gridColumn: { xs: 'span 12', md: 'span 8' } }}>
          <Panel title="By day" subtitle={`Last ${shown.length} month${shown.length === 1 ? '' : 's'}`}>
            <Box
              sx={{
                display: 'grid',
                gridTemplateColumns: {
                  xs: '1fr',
                  sm: 'repeat(2, 1fr)',
                  lg: 'repeat(3, 1fr)',
                },
                gap: 3,
              }}
            >
              {shown.map((monthKey) => (
                <MonthGrid
                  key={monthKey}
                  monthKey={monthKey}
                  totals={totals}
                  thresholds={thresholds}
                />
              ))}
            </Box>
          </Panel>
        </Box>
      </Box>
    </Box>
  );
}
