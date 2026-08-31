import { useMemo } from 'react';
import { Box } from '@mui/material';
import Header from '../../components/Header';
import Panel from '../../components/Panel';
import { MonthStrip } from '../../components/MonthStrip';
import {
  CategoryDonut,
  categoryTable,
  MonthlyByCategory,
  monthlyByCategoryTable,
  MonthlyTrend,
  trendTable,
} from '../../components/charts';
import { useData } from '../../lib/DataContext';
import { monthlyByCategory, monthlyTotals, spendByCategory } from '../../lib/selectors';

/** Full-width trend, so the shape of the year is readable. */
export function Trends() {
  const { transactions } = useData();
  const trend = useMemo(() => monthlyTotals(transactions), [transactions]);

  return (
    <Box>
      <Header
        title="Spending trend"
        subtitle="Total spent per month. Not filtered by the month selector — the point is the whole run."
      />
      <Panel
        title="Total per month"
        subtitle="One series, so the title names it and no legend is needed"
        table={trendTable(trend)}
      >
        <Box sx={{ height: 460 }}>
          <MonthlyTrend data={trend} height={460} />
        </Box>
      </Panel>
    </Box>
  );
}

export function Breakdown() {
  const { inView, months, selectedMonths, setSelectedMonths } = useData();
  const byCategory = useMemo(() => spendByCategory(inView), [inView]);

  return (
    <Box>
      <Header
        title="Category split"
        subtitle="Where the money goes, as a share of the selected months"
      />
      <MonthStrip
        months={months}
        selected={selectedMonths}
        onChange={setSelectedMonths}
      />
      <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(12, 1fr)', gap: 2, '& > *': { minWidth: 0 } }}>
        <Box sx={{ gridColumn: { xs: 'span 12', md: 'span 7' } }}>
          <Panel
            title="Share of spending"
            subtitle="Beyond six categories the tail folds together — a donut asks you to compare arcs that are not neighbours"
            table={categoryTable(byCategory)}
          >
            <Box sx={{ display: 'flex', justifyContent: 'center' }}>
              <Box sx={{ width: '100%', maxWidth: 520 }}>
                <CategoryDonut data={byCategory} height={380} />
              </Box>
            </Box>
          </Panel>
        </Box>
        <Box sx={{ gridColumn: { xs: 'span 12', md: 'span 5' } }}>
          <Panel title="The numbers" subtitle="Same data, read as figures">
            {categoryTable(byCategory)}
          </Panel>
        </Box>
      </Box>
    </Box>
  );
}

export function Monthly() {
  const { transactions } = useData();
  const { rows, series } = useMemo(() => monthlyByCategory(transactions), [transactions]);

  return (
    <Box>
      <Header
        title="Month compare"
        subtitle="Each month stacked by its leading categories, so months can be read against one another"
      />
      <Panel
        title="Spend by month and category"
        subtitle="The tail folds into one bucket rather than reaching for a ninth colour"
        table={monthlyByCategoryTable(rows, series)}
      >
        <MonthlyByCategory rows={rows} series={series} height={440} />
      </Panel>
    </Box>
  );
}
