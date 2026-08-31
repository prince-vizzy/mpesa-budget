import { Box, Typography, useTheme } from '@mui/material';
import { tokens } from '../theme';
import ProgressCircle from './ProgressCircle';

/**
 * The reference dashboard's stat box: a label, the value, an icon, and an
 * optional progress ring with a note beside it.
 *
 * The value uses the font's proportional figures — `tabular-nums` gives every
 * digit the width of a zero, which reads loose at display sizes. Columns of
 * numbers in the data grids use tabular instead.
 */
export default function StatBox({ title, subtitle, icon, progress, note, hero }) {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);

  return (
    <Box sx={{ width: '100%', p: 2 }}>
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'flex-start',
        }}
      >
        <Box>
          <Box sx={{ color: colors.textMuted, mb: 0.5, lineHeight: 1 }}>{icon}</Box>
          <Typography
            variant={hero ? 'h1' : 'h2'}
            sx={{ color: colors.textPrimary, lineHeight: 1.15 }}
          >
            {title}
          </Typography>
        </Box>
        {progress !== undefined && progress !== null && (
          <ProgressCircle progress={progress} size={44} />
        )}
      </Box>

      <Box
        sx={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          gap: 1,
          mt: 1,
        }}
      >
        <Typography variant="body2" sx={{ color: colors.textSecondary }}>
          {subtitle}
        </Typography>
        {note && (
          <Typography variant="caption" sx={{ color: colors.textMuted }}>
            {note}
          </Typography>
        )}
      </Box>
    </Box>
  );
}
