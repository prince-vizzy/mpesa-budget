import { useMemo } from 'react';
import { Alert, Box, Paper, useTheme } from '@mui/material';
import PaymentsOutlinedIcon from '@mui/icons-material/PaymentsOutlined';
import TodayOutlinedIcon from '@mui/icons-material/TodayOutlined';
import TrendingUpOutlinedIcon from '@mui/icons-material/TrendingUpOutlined';
import SavingsOutlinedIcon from '@mui/icons-material/SavingsOutlined';

import Header from '../../components/Header';
import Panel from '../../components/Panel';
import StatBox from '../../components/StatBox';
import { MonthStrip } from '../../components/MonthStrip';
import { TransactionsTable } from '../../components/TransactionsTable';
import {
  CategoryDonut,
  categoryTable,
  MonthlyTrend,
  payeeTable,
  TopPayees,
  trendTable,
} from '../../components/charts';
import { BudgetMeters, budgetTable } from '../../components/meters';
import { useData } from '../../lib/DataContext';
import {
  budgetComparison,
  KES,
  monthlyTotals,
  spendByCategory,
  spendByPayee,
  summarize,
} from '../../lib/selectors';
import { tokens } from '../../theme';

/** 12-column grid; each child says how many columns it takes at each breakpoint. */
const GRID = {
  display: 'grid',
  gridTemplateColumns: 'repeat(12, 1fr)',
  gap: 2,
  '& > *': { minWidth: 0 },
};

const span = (xs, md, lg) => ({
  gridColumn: { xs: `span ${xs}`, md: `span ${md}`, lg: `span ${lg}` },
});

export default function Dashboard() {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);
  const {
    transactions,
    categories,
    inView,
    months,
    monthCount,
    selectedMonths,
    setSelectedMonths,
    error,
    loading,
  } = useData();

  const stats = useMemo(
    () => summarize(inView, categories, monthCount),
    [inView, categories, monthCount],
  );
  const byCategory = useMemo(() => spendByCategory(inView), [inView]);
  const payees = useMemo(() => spendByPayee(inView), [inView]);
  const trend = useMemo(() => monthlyTotals(transactions), [transactions]);
  const budgets = useMemo(
    () => budgetComparison(inView, categories, monthCount),
    [inView, categories, monthCount],
  );

  const tile = { border: `1px solid ${colors.border}`, height: '100%' };

  return (
    <Box>
      <Header title="Dashboard" subtitle="Every M-Pesa payment the app has captured" />

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          Could not reach the backend ({error}). Start it with <code>npm start</code> in{' '}
          <code>mpesa-backend</code>, then open the app so it syncs.
        </Alert>
      )}

      {/* First run: the panels each say "nothing here", but none of them says
          what to do about it. */}
      {!error && !loading && transactions.length === 0 && (
        <Alert severity="info" sx={{ mb: 2 }}>
          No spending synced yet. Start <code>mpesa-backend</code>, then open the app —
          it pushes its transactions on every change. On a physical phone run it with{' '}
          <code>--dart-define=DASHBOARD_HOST=&lt;your computer LAN IP&gt;</code>, since the
          handset cannot reach your machine on localhost.
        </Alert>
      )}

      <MonthStrip months={months} selected={selectedMonths} onChange={setSelectedMonths} />

      <Box sx={GRID}>
        {/* Hero figure — exactly one per view. */}
        <Box sx={span(12, 6, 3)}>
          <Paper elevation={0} sx={tile}>
            <StatBox
              hero
              title={KES.format(stats.total)}
              subtitle="Total spent"
              icon={<PaymentsOutlinedIcon />}
            />
          </Paper>
        </Box>

        <Box sx={span(12, 6, 3)}>
          <Paper elevation={0} sx={tile}>
            <StatBox
              title={KES.format(stats.perDay)}
              subtitle="Average per day"
              note={`${monthCount} month${monthCount === 1 ? '' : 's'}`}
              icon={<TodayOutlinedIcon />}
            />
          </Paper>
        </Box>

        <Box sx={span(12, 6, 3)}>
          <Paper elevation={0} sx={tile}>
            <StatBox
              title={
                stats.largest
                  ? KES.format(Math.abs(Number(stats.largest.amount) || 0))
                  : '—'
              }
              subtitle="Largest payment"
              note={stats.largest?.payee?.trim() || stats.largest?.category || '—'}
              icon={<TrendingUpOutlinedIcon />}
            />
          </Paper>
        </Box>

        <Box sx={span(12, 6, 3)}>
          <Paper elevation={0} sx={tile}>
            <StatBox
              title={stats.usage === null ? '—' : `${Math.round(stats.usage * 100)}%`}
              subtitle="Budget used"
              note={stats.budget > 0 ? `of ${KES.format(stats.budget)}` : 'No budgets set'}
              icon={<SavingsOutlinedIcon />}
              progress={stats.usage}
            />
          </Paper>
        </Box>

        <Box sx={span(12, 12, 8)}>
          <Panel
            title="Spending over time"
            subtitle="Total per month, across all data"
            table={trendTable(trend)}
          >
            <MonthlyTrend data={trend} />
          </Panel>
        </Box>

        <Box sx={span(12, 12, 4)}>
          <Panel
            title="Where the money went"
            subtitle="Share of spending by category"
            table={categoryTable(byCategory)}
          >
            <CategoryDonut data={byCategory} />
          </Panel>
        </Box>

        <Box sx={span(12, 12, 5)}>
          <Panel
            title="Top payees"
            subtitle={
              payees.unnamed > 0
                ? `${payees.unnamed} transaction${payees.unnamed === 1 ? '' : 's'} had no payee name`
                : 'Ranked by total spend'
            }
            table={payeeTable(payees.rows)}
          >
            <TopPayees rows={payees.rows} />
          </Panel>
        </Box>

        <Box sx={span(12, 12, 7)}>
          <Panel
            title="Budgets by category"
            subtitle="Spending against the budgets set in the app"
            table={budgetTable(budgets)}
          >
            <BudgetMeters rows={budgets.slice(0, 7)} />
          </Panel>
        </Box>

        <Box sx={{ gridColumn: 'span 12' }}>
          <Panel title="Recent transactions" subtitle="Most recent first">
            <TransactionsTable transactions={inView} limit={12} />
          </Panel>
        </Box>
      </Box>
    </Box>
  );
}
