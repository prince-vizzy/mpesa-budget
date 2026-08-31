import { useState } from 'react';
import { Box, Button, Paper, Typography, useTheme } from '@mui/material';
import { tokens } from '../theme';

/**
 * A titled surface with an optional table view.
 *
 * Every chart can be read as numbers instead. That is the relief the palette
 * requires in light mode, where three categorical hues sit below 3:1 against
 * the surface, and it is the honest fallback for anyone the colours fail.
 */
export default function Panel({ title, subtitle, table, action, height, children }) {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);
  const [showTable, setShowTable] = useState(false);

  return (
    <Paper
      elevation={0}
      sx={{
        p: 2,
        height: height ?? '100%',
        border: `1px solid ${colors.border}`,
        display: 'flex',
        flexDirection: 'column',
        minWidth: 0,
      }}
    >
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'baseline',
          gap: 1,
        }}
      >
        <Typography variant="h5" color="text.primary">
          {title}
        </Typography>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flex: 'none' }}>
          {action}
          {table && (
            <Button size="small" onClick={() => setShowTable((v) => !v)}>
              {showTable ? 'Chart' : 'Table'}
            </Button>
          )}
        </Box>
      </Box>

      {subtitle && (
        <Typography variant="caption" sx={{ color: colors.textMuted, mb: 1.5 }}>
          {subtitle}
        </Typography>
      )}

      <Box sx={{ flex: '1 1 auto', minWidth: 0, mt: subtitle ? 0 : 1.5 }}>
        {showTable && table ? table : children}
      </Box>
    </Paper>
  );
}
