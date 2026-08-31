import { Box, useTheme } from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import { tokens } from '../theme';

/**
 * Shared grid styling, so every data scene looks like one table rather than
 * three. Gridlines are hairline and one step off the surface; the numbers are
 * the only thing allowed to be loud.
 */
export default function DataTable({ rows, columns, getRowId, height = 620, ...rest }) {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);

  return (
    <Box
      sx={{
        height,
        width: '100%',
        '& .MuiDataGrid-root': { border: 'none', fontSize: 13 },
        '& .MuiDataGrid-cell': { borderColor: colors.gridline },
        '& .MuiDataGrid-columnHeaders': {
          borderColor: colors.gridline,
          color: colors.textMuted,
        },
        '& .MuiDataGrid-columnHeaderTitle': { fontWeight: 500, fontSize: 12 },
        '& .MuiDataGrid-footerContainer': { borderColor: colors.gridline },
        // Columns of figures have to line up, so tabular here (never on the
        // large standalone values in the stat boxes).
        '& .num': { fontVariantNumeric: 'tabular-nums' },
      }}
    >
      <DataGrid
        rows={rows}
        columns={columns}
        getRowId={getRowId}
        density="compact"
        disableRowSelectionOnClick
        initialState={{ pagination: { paginationModel: { pageSize: 25 } } }}
        pageSizeOptions={[25, 50, 100]}
        {...rest}
      />
    </Box>
  );
}
