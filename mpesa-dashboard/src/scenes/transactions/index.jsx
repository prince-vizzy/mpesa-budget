import { useMemo } from 'react';
import { Box, Chip } from '@mui/material';
import Header from '../../components/Header';
import DataTable from '../../components/DataTable';
import { MonthStrip } from '../../components/MonthStrip';
import { useData } from '../../lib/DataContext';
import { KES } from '../../lib/selectors';

const DATE = new Intl.DateTimeFormat('en-GB', {
  day: '2-digit',
  month: 'short',
  year: 'numeric',
});

export default function Transactions() {
  const { inView, months, selectedMonths, setSelectedMonths } = useData();

  const rows = useMemo(
    () =>
      [...inView]
        .sort((a, b) => new Date(b.date) - new Date(a.date))
        .map((tx) => ({
          ...tx,
          _amount: Math.abs(Number(tx.amount) || 0),
          _date: new Date(tx.date),
        })),
    [inView],
  );

  const columns = [
    {
      field: '_date',
      headerName: 'Date',
      width: 130,
      type: 'dateTime',
      valueFormatter: (value) =>
        value && !Number.isNaN(value.valueOf()) ? DATE.format(value) : '—',
    },
    {
      field: 'payee',
      headerName: 'Payee',
      width: 220,
      // Airtime top-ups and some agent withdrawals have no name to extract.
      renderCell: ({ value }) => value?.trim() || '—',
    },
    {
      field: 'category',
      headerName: 'Category',
      width: 160,
      renderCell: ({ value }) => (
        <Chip size="small" variant="outlined" label={value || 'Uncategorized'} />
      ),
    },
    { field: 'description', headerName: 'Description', flex: 1, minWidth: 260 },
    {
      field: 'mpesa_ref',
      headerName: 'Reference',
      width: 140,
      cellClassName: 'num',
    },
    {
      field: '_amount',
      headerName: 'Amount',
      width: 130,
      type: 'number',
      cellClassName: 'num',
      valueFormatter: (value) => KES.format(value ?? 0),
    },
  ];

  return (
    <Box>
      <Header
        title="Transactions"
        subtitle="Everything synced from the app, newest first"
      />
      <MonthStrip
        months={months}
        selected={selectedMonths}
        onChange={setSelectedMonths}
      />
      <DataTable
        rows={rows}
        columns={columns}
        getRowId={(row) => row.id ?? row.mpesa_ref}
      />
    </Box>
  );
}
