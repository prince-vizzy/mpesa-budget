import { useMemo } from 'react';
import { Alert, Box, Chip } from '@mui/material';
import Header from '../../components/Header';
import Panel from '../../components/Panel';
import DataTable from '../../components/DataTable';
import { MonthStrip } from '../../components/MonthStrip';
import { TopPayees, payeeTable } from '../../components/charts';
import { useData } from '../../lib/DataContext';
import { KES, payeeRollup, spendByPayee } from '../../lib/selectors';

const DATE = new Intl.DateTimeFormat('en-GB', {
  day: '2-digit',
  month: 'short',
  year: 'numeric',
});

export default function Payees() {
  const { inView, months, selectedMonths, setSelectedMonths } = useData();

  const rollup = useMemo(() => payeeRollup(inView), [inView]);
  const ranked = useMemo(() => spendByPayee(inView), [inView]);

  const columns = [
    { field: 'name', headerName: 'Payee', flex: 1, minWidth: 220 },
    {
      field: 'categories',
      headerName: 'Filed under',
      width: 220,
      sortable: false,
      renderCell: ({ value }) => (
        <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'nowrap', overflow: 'hidden' }}>
          {(value ?? []).slice(0, 2).map((c) => (
            <Chip key={c} size="small" variant="outlined" label={c} />
          ))}
        </Box>
      ),
    },
    {
      field: 'count',
      headerName: 'Payments',
      width: 110,
      type: 'number',
      cellClassName: 'num',
    },
    {
      field: 'average',
      headerName: 'Average',
      width: 130,
      type: 'number',
      cellClassName: 'num',
      valueFormatter: (value) => KES.format(value ?? 0),
    },
    {
      field: 'last',
      headerName: 'Last payment',
      width: 150,
      type: 'dateTime',
      valueFormatter: (value) =>
        value && !Number.isNaN(value.valueOf()) ? DATE.format(value) : '—',
    },
    {
      field: 'total',
      headerName: 'Total spent',
      width: 140,
      type: 'number',
      cellClassName: 'num',
      valueFormatter: (value) => KES.format(value ?? 0),
    },
  ];

  return (
    <Box>
      <Header
        title="Payees"
        subtitle="Who the money goes to, from the recipient name the app extracts"
      />
      <MonthStrip
        months={months}
        selected={selectedMonths}
        onChange={setSelectedMonths}
      />

      {ranked.unnamed > 0 && (
        <Alert severity="info" sx={{ mb: 2 }}>
          {ranked.unnamed} transaction{ranked.unnamed === 1 ? '' : 's'} in this period had
          no payee name — airtime top-ups and some agent withdrawals carry none. They
          count towards totals but cannot be ranked here.
        </Alert>
      )}

      <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(12, 1fr)', gap: 2, '& > *': { minWidth: 0 } }}>
        <Box sx={{ gridColumn: { xs: 'span 12', lg: 'span 5' } }}>
          <Panel
            title="Top payees"
            subtitle="Ranked by total spend"
            table={payeeTable(ranked.rows)}
          >
            <TopPayees rows={ranked.rows} />
          </Panel>
        </Box>

        <Box sx={{ gridColumn: { xs: 'span 12', lg: 'span 7' } }}>
          <Panel title="All payees" subtitle={`${rollup.length} in this period`}>
            <DataTable
              rows={rollup}
              columns={columns}
              getRowId={(row) => row.name}
              height={520}
            />
          </Panel>
        </Box>
      </Box>
    </Box>
  );
}
