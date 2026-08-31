import { useMemo } from 'react';
import { Box, Paper, Typography, useTheme } from '@mui/material';
import WarningAmberOutlinedIcon from '@mui/icons-material/WarningAmberOutlined';
import Header from '../../components/Header';
import Panel from '../../components/Panel';
import DataTable from '../../components/DataTable';
import ProgressCircle from '../../components/ProgressCircle';
import { MonthStrip } from '../../components/MonthStrip';
import { BudgetMeters, budgetTable } from '../../components/meters';
import { useData } from '../../lib/DataContext';
import { budgetComparison, KES, summarize } from '../../lib/selectors';
import { tokens } from '../../theme';

export default function Budgets() {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);
  const { inView, categories, months, monthCount, selectedMonths, setSelectedMonths } =
    useData();

  const rows = useMemo(
    () => budgetComparison(inView, categories, monthCount),
    [inView, categories, monthCount],
  );
  const stats = useMemo(
    () => summarize(inView, categories, monthCount),
    [inView, categories, monthCount],
  );
  const over = rows.filter((r) => r.over);

  const columns = [
    { field: 'name', headerName: 'Category', flex: 1, minWidth: 180 },
    {
      field: 'spent',
      headerName: 'Spent',
      width: 140,
      type: 'number',
      cellClassName: 'num',
      valueFormatter: (value) => KES.format(value ?? 0),
    },
    {
      field: 'budget',
      headerName: 'Budget',
      width: 140,
      type: 'number',
      cellClassName: 'num',
      valueFormatter: (value) => (value > 0 ? KES.format(value) : '—'),
    },
    {
      field: 'usage',
      headerName: 'Used',
      width: 110,
      type: 'number',
      cellClassName: 'num',
      valueFormatter: (value) =>
        value === null || value === undefined ? '—' : `${Math.round(value * 100)}%`,
    },
    {
      field: 'over',
      headerName: 'Status',
      width: 150,
      // Icon and word, never the colour on its own.
      renderCell: ({ value }) =>
        value ? (
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, color: colors.critical }}>
            <WarningAmberOutlinedIcon fontSize="inherit" />
            <span>Over budget</span>
          </Box>
        ) : (
          <Typography variant="caption" color="text.secondary">
            Within budget
          </Typography>
        ),
    },
  ];

  return (
    <Box>
      <Header
        title="Budgets"
        subtitle="Category budgets come from the app; spending is measured against them for the months in view"
      />
      <MonthStrip
        months={months}
        selected={selectedMonths}
        onChange={setSelectedMonths}
      />

      <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(12, 1fr)', gap: 2, '& > *': { minWidth: 0 } }}>
        <Box sx={{ gridColumn: { xs: 'span 12', md: 'span 4' } }}>
          <Paper
            elevation={0}
            sx={{ p: 2, border: `1px solid ${colors.border}`, height: '100%' }}
          >
            <Typography variant="h5">Overall</Typography>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mt: 2 }}>
              <ProgressCircle progress={stats.usage ?? 0} size={92} />
              <Box>
                <Typography variant="h2">
                  {stats.usage === null ? '—' : `${Math.round(stats.usage * 100)}%`}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  {KES.format(stats.total)}
                  {stats.budget > 0 ? ` of ${KES.format(stats.budget)}` : ''}
                </Typography>
                {over.length > 0 && (
                  <Box
                    sx={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 0.5,
                      mt: 0.5,
                      color: colors.critical,
                    }}
                  >
                    <WarningAmberOutlinedIcon fontSize="inherit" />
                    <Typography variant="caption" fontWeight={600}>
                      {over.length} categor{over.length === 1 ? 'y' : 'ies'} over
                    </Typography>
                  </Box>
                )}
              </Box>
            </Box>
          </Paper>
        </Box>

        <Box sx={{ gridColumn: { xs: 'span 12', md: 'span 8' } }}>
          <Panel
            title="By category"
            subtitle="Against each budget"
            table={budgetTable(rows)}
          >
            <BudgetMeters rows={rows} />
          </Panel>
        </Box>

        <Box sx={{ gridColumn: 'span 12' }}>
          <Panel title="All categories" subtitle={`${rows.length} tracked`}>
            <DataTable
              rows={rows}
              columns={columns}
              getRowId={(row) => row.name}
              height={460}
            />
          </Panel>
        </Box>
      </Box>
    </Box>
  );
}
