import { useContext } from 'react';
import { Box, IconButton, Tooltip, Typography, useTheme } from '@mui/material';
import LightModeOutlinedIcon from '@mui/icons-material/LightModeOutlined';
import DarkModeOutlinedIcon from '@mui/icons-material/DarkModeOutlined';
import RefreshOutlinedIcon from '@mui/icons-material/RefreshOutlined';
import { ColorModeContext, tokens } from '../../theme';

/**
 * Connection state is shown as a dot *and* a word — a viewer who cannot
 * separate the colours still reads the state.
 */
function ConnectionPill({ status }) {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);

  const label =
    status === 'live' ? 'Live' : status === 'off' ? 'Backend offline' : 'Connecting';
  const dot =
    status === 'live' ? colors.good : status === 'off' ? colors.critical : colors.warning;

  return (
    <Box
      sx={{
        display: 'flex',
        alignItems: 'center',
        gap: 0.75,
        px: 1.25,
        py: 0.5,
        borderRadius: 999,
        border: `1px solid ${colors.border}`,
        bgcolor: colors.surface,
      }}
    >
      <Box
        sx={{ width: 8, height: 8, borderRadius: '50%', bgcolor: dot, flex: 'none' }}
      />
      <Typography variant="caption" color="text.secondary">
        {label}
      </Typography>
    </Box>
  );
}

export default function Topbar({ status, onRefresh, scope }) {
  const theme = useTheme();
  const colorMode = useContext(ColorModeContext);
  const colors = tokens(theme.palette.mode);

  return (
    <Box
      sx={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        gap: 2,
        px: 3,
        py: 1.5,
        borderBottom: `1px solid ${colors.border}`,
        bgcolor: colors.surface,
        flex: 'none',
      }}
    >
      <Typography variant="body2" color="text.secondary">
        {scope}
      </Typography>

      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
        <ConnectionPill status={status} />

        <Tooltip title="Reload from the backend">
          <IconButton onClick={onRefresh} size="small">
            <RefreshOutlinedIcon fontSize="small" />
          </IconButton>
        </Tooltip>

        <Tooltip
          title={theme.palette.mode === 'dark' ? 'Switch to light' : 'Switch to dark'}
        >
          <IconButton onClick={colorMode.toggleColorMode} size="small">
            {theme.palette.mode === 'dark' ? (
              <LightModeOutlinedIcon fontSize="small" />
            ) : (
              <DarkModeOutlinedIcon fontSize="small" />
            )}
          </IconButton>
        </Tooltip>
      </Box>
    </Box>
  );
}
