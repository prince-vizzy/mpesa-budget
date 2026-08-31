import { Box, CssBaseline, ThemeProvider } from '@mui/material';
import { Route, Routes } from 'react-router-dom';

import { ColorModeContext, useMode } from './theme';
import { DataProvider, useData } from './lib/DataContext';
import AppSidebar from './scenes/global/Sidebar';
import Topbar from './scenes/global/Topbar';
import Dashboard from './scenes/dashboard';
import Transactions from './scenes/transactions';
import Payees from './scenes/payees';
import Budgets from './scenes/budgets';
import { Breakdown, Monthly, Trends } from './scenes/charts';
import CalendarScene from './scenes/calendar';
import Help from './scenes/help';

function Shell() {
  const { status, refresh, scope } = useData();

  return (
    <Box sx={{ display: 'flex', height: '100vh', overflow: 'hidden' }}>
      <AppSidebar />

      <Box
        sx={{
          flex: '1 1 auto',
          display: 'flex',
          flexDirection: 'column',
          minWidth: 0,
        }}
      >
        <Topbar status={status} onRefresh={refresh} scope={scope} />

        <Box sx={{ flex: '1 1 auto', overflow: 'auto', p: 3 }}>
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/transactions" element={<Transactions />} />
            <Route path="/payees" element={<Payees />} />
            <Route path="/budgets" element={<Budgets />} />
            <Route path="/trends" element={<Trends />} />
            <Route path="/breakdown" element={<Breakdown />} />
            <Route path="/monthly" element={<Monthly />} />
            <Route path="/calendar" element={<CalendarScene />} />
            <Route path="/help" element={<Help />} />
            <Route path="*" element={<Dashboard />} />
          </Routes>
        </Box>
      </Box>
    </Box>
  );
}

export default function App() {
  const [theme, colorMode] = useMode();

  return (
    <ColorModeContext.Provider value={colorMode}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <DataProvider>
          <Shell />
        </DataProvider>
      </ThemeProvider>
    </ColorModeContext.Provider>
  );
}
