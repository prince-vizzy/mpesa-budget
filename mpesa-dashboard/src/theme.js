import { createContext, useState, useMemo, useEffect } from 'react';
import { createTheme } from '@mui/material/styles';

/**
 * Theme, following the reference admin dashboard's shape: a `tokens(mode)`
 * palette, a `ColorModeContext`, and a `useMode()` hook.
 *
 * The values are the validated data-viz palette rather than the template's, so
 * the chrome and the charts agree. Light and dark are separately stepped sets,
 * not an inversion of one another.
 *
 * The charts read CSS custom properties from `styles/tokens.css`, so the toggle
 * has to move both worlds at once — `useMode` stamps `data-theme` on the root as
 * well as switching the MUI palette.
 */

export const tokens = (mode) =>
  mode === 'dark'
    ? {
        surface: '#1a1a19',
        page: '#0d0d0d',
        raised: '#232321',
        textPrimary: '#ffffff',
        textSecondary: '#c3c2b7',
        textMuted: '#898781',
        border: 'rgba(255,255,255,0.10)',
        gridline: '#2c2c2a',
        accent: '#3987e5',
        good: '#0ca30c',
        warning: '#fab219',
        critical: '#d03b3b',
      }
    : {
        surface: '#fcfcfb',
        page: '#f9f9f7',
        raised: '#ffffff',
        textPrimary: '#0b0b0b',
        textSecondary: '#52514e',
        textMuted: '#898781',
        border: 'rgba(11,11,11,0.10)',
        gridline: '#e1e0d9',
        accent: '#2a78d6',
        good: '#0ca30c',
        warning: '#fab219',
        critical: '#d03b3b',
      };

export const themeSettings = (mode) => {
  const colors = tokens(mode);

  return {
    palette: {
      mode,
      primary: { main: colors.accent },
      success: { main: colors.good },
      warning: { main: colors.warning },
      error: { main: colors.critical },
      divider: colors.border,
      background: { default: colors.page, paper: colors.surface },
      text: { primary: colors.textPrimary, secondary: colors.textSecondary },
    },
    shape: { borderRadius: 12 },
    typography: {
      // One sans throughout, including the big figures — a display face there
      // reads as decoration rather than data.
      fontFamily: ['system-ui', '-apple-system', 'Segoe UI', 'sans-serif'].join(','),
      fontSize: 13,
      h1: { fontSize: 34, fontWeight: 600, letterSpacing: '-0.02em' },
      h2: { fontSize: 26, fontWeight: 600, letterSpacing: '-0.02em' },
      h3: { fontSize: 20, fontWeight: 600 },
      h4: { fontSize: 16, fontWeight: 600 },
      h5: { fontSize: 14, fontWeight: 600 },
      h6: { fontSize: 13, fontWeight: 600 },
    },
    components: {
      MuiPaper: {
        styleOverrides: {
          root: { backgroundImage: 'none' },
        },
      },
      MuiCssBaseline: {
        styleOverrides: {
          body: { backgroundColor: colors.page },
        },
      },
    },
  };
};

export const ColorModeContext = createContext({ toggleColorMode: () => {} });

const STORAGE_KEY = 'mpesa-dashboard-theme';

export const useMode = () => {
  const [mode, setMode] = useState(() => {
    try {
      return localStorage.getItem(STORAGE_KEY) ?? 'dark';
    } catch {
      return 'dark';
    }
  });

  // The chart layer is driven by CSS custom properties, so the attribute has to
  // move with the MUI palette or the two halves disagree.
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', mode);
    try {
      localStorage.setItem(STORAGE_KEY, mode);
    } catch {
      // A private window can refuse storage; the theme still applies this session.
    }
  }, [mode]);

  const colorMode = useMemo(
    () => ({
      mode,
      toggleColorMode: () => setMode((m) => (m === 'light' ? 'dark' : 'light')),
    }),
    [mode],
  );

  const theme = useMemo(() => createTheme(themeSettings(mode)), [mode]);

  return [theme, colorMode];
};
