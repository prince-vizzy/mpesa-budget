import { Box, useTheme } from '@mui/material';
import { tokens } from '../theme';

/**
 * A ratio against a limit, drawn as a ring.
 *
 * Severity rides the fill and the unfilled track is a lighter step of the same
 * ramp, so the state reads across the whole ring rather than only where the
 * fill stops. Anything over 100% is additionally flagged with an icon and a
 * word wherever this is used — a status colour never carries meaning alone.
 */
export default function ProgressCircle({ progress = 0, size = 40 }) {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);

  const clamped = Math.min(Math.max(progress, 0), 1);
  const angle = clamped * 360;

  const fill =
    progress > 1
      ? colors.critical
      : progress >= 0.85
        ? colors.warning
        : colors.accent;

  const track = theme.palette.mode === 'dark' ? '#184f95' : '#86b6ef';

  return (
    <Box
      sx={{
        width: size,
        height: size,
        borderRadius: '50%',
        background: `conic-gradient(${fill} 0deg ${angle}deg, ${track} ${angle}deg 360deg)`,
        // The hole is the surface showing through, so the ring sits on any panel.
        '&::after': {
          content: '""',
          display: 'block',
          position: 'relative',
          top: '25%',
          left: '25%',
          width: '50%',
          height: '50%',
          borderRadius: '50%',
          background: colors.surface,
        },
      }}
      role="img"
      aria-label={`${Math.round(progress * 100)} percent of budget used`}
    />
  );
}
