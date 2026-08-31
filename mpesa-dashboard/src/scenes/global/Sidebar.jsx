import { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Sidebar, Menu, MenuItem, sidebarClasses } from 'react-pro-sidebar';
import { Box, IconButton, Typography, useTheme } from '@mui/material';
import MenuOutlinedIcon from '@mui/icons-material/MenuOutlined';
import SpaceDashboardOutlinedIcon from '@mui/icons-material/SpaceDashboardOutlined';
import ReceiptLongOutlinedIcon from '@mui/icons-material/ReceiptLongOutlined';
import StorefrontOutlinedIcon from '@mui/icons-material/StorefrontOutlined';
import AccountBalanceWalletOutlinedIcon from '@mui/icons-material/AccountBalanceWalletOutlined';
import ShowChartOutlinedIcon from '@mui/icons-material/ShowChartOutlined';
import DonutLargeOutlinedIcon from '@mui/icons-material/DonutLargeOutlined';
import BarChartOutlinedIcon from '@mui/icons-material/BarChartOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import HelpOutlineOutlinedIcon from '@mui/icons-material/HelpOutlineOutlined';
import { tokens } from '../../theme';

const SECTIONS = [
  {
    heading: null,
    items: [{ to: '/', label: 'Dashboard', icon: <SpaceDashboardOutlinedIcon /> }],
  },
  {
    heading: 'Data',
    items: [
      { to: '/transactions', label: 'Transactions', icon: <ReceiptLongOutlinedIcon /> },
      { to: '/payees', label: 'Payees', icon: <StorefrontOutlinedIcon /> },
      { to: '/budgets', label: 'Budgets', icon: <AccountBalanceWalletOutlinedIcon /> },
    ],
  },
  {
    heading: 'Charts',
    items: [
      { to: '/trends', label: 'Spending trend', icon: <ShowChartOutlinedIcon /> },
      { to: '/breakdown', label: 'Category split', icon: <DonutLargeOutlinedIcon /> },
      { to: '/monthly', label: 'Month compare', icon: <BarChartOutlinedIcon /> },
      { to: '/calendar', label: 'Daily calendar', icon: <CalendarMonthOutlinedIcon /> },
    ],
  },
  {
    heading: 'About',
    items: [
      { to: '/help', label: 'How capture works', icon: <HelpOutlineOutlinedIcon /> },
    ],
  },
];

export default function AppSidebar() {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);
  const { pathname } = useLocation();
  const [collapsed, setCollapsed] = useState(false);

  return (
    <Sidebar
      collapsed={collapsed}
      rootStyles={{
        border: 'none',
        height: '100%',
        [`.${sidebarClasses.container}`]: {
          background: colors.surface,
          borderRight: `1px solid ${colors.border}`,
          overflowY: 'auto',
        },
      }}
    >
      <Box
        sx={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 1,
          p: 1.5,
        }}
      >
        {!collapsed && (
          <Box sx={{ pl: 1, minWidth: 0 }}>
            <Typography variant="h4" color="text.primary" noWrap>
              M-Pesa
            </Typography>
            <Typography variant="caption" color="text.secondary" noWrap>
              Spending tracker
            </Typography>
          </Box>
        )}
        <IconButton onClick={() => setCollapsed((v) => !v)} size="small">
          <MenuOutlinedIcon fontSize="small" />
        </IconButton>
      </Box>

      {SECTIONS.map((section, i) => (
        <Box key={section.heading ?? `section-${i}`} sx={{ mb: 1 }}>
          {section.heading && !collapsed && (
            <Typography
              variant="caption"
              sx={{
                display: 'block',
                color: colors.textMuted,
                pl: 2.5,
                letterSpacing: '0.04em',
              }}
            >
              {section.heading.toUpperCase()}
            </Typography>
          )}
          <Menu
            menuItemStyles={{
              button: ({ active }) => ({
                height: 40,
                color: active ? colors.textPrimary : colors.textSecondary,
                backgroundColor: active ? colors.page : 'transparent',
                fontWeight: active ? 600 : 400,
                fontSize: 14,
                '&:hover': { backgroundColor: colors.page },
              }),
              icon: ({ active }) => ({
                color: active ? colors.accent : colors.textMuted,
              }),
            }}
          >
            {section.items.map((item) => (
              <MenuItem
                key={item.to}
                icon={item.icon}
                active={pathname === item.to}
                component={<Link to={item.to} />}
              >
                {item.label}
              </MenuItem>
            ))}
          </Menu>
        </Box>
      ))}
    </Sidebar>
  );
}
