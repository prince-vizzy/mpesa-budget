# M-Pesa spending dashboard

A React admin dashboard for the M-Pesa tracker — sidebar navigation, MUI Data
Grid, light/dark themes — built only on data the app actually has.

## Running it

Three processes, in this order:

```bash
# 1. the backend the app syncs into
cd mpesa-backend && npm start        # :5000

# 2. this dashboard
cd mpesa-dashboard && npm install && npm run dev   # :5173

# 3. the Flutter app — opening it triggers a sync
flutter run
```

Vite proxies `/api` and `/socket.io` to `:5000`, so the browser stays
same-origin and no CORS negotiation is needed. Point elsewhere with
`MPESA_BACKEND=http://host:port npm run dev`.

## Layout

```
src/
  theme.js                  MUI theme + ColorModeContext + useMode
  App.jsx                   router and shell
  lib/
    api.js                  REST + socket.io
    DataContext.jsx         one connection, one copy of the data
    selectors.js            every derived number
  components/               Header, StatBox, ProgressCircle, Panel,
                            DataTable, MonthStrip, charts, meters
  scenes/
    global/                 Sidebar, Topbar
    dashboard/  transactions/  payees/  budgets/
    charts/                 Trends, Breakdown, Monthly
    calendar/  help/
```

Scenes read from `DataContext`, so navigating never re-opens the socket or
re-fetches, and the month filter survives the move. Every derived number lives
in `selectors.js` — nothing is computed twice.

## How data arrives

`CategoryStore` in the Flutter app calls `DashboardSyncService` after every
change, which POSTs categories and transactions to `/api/sync`. The backend
stores them and broadcasts over socket.io; this dashboard loads the current
state over REST and stays current from those events. Nothing is entered here —
if a number is wrong, it is wrong in the app.

## What it shows, and what it deliberately does not

The app captures **expenses only** — its parser keeps `sent`/`paid`/`withdraw`/
`airtime` and drops money received. It has no income, investment or loan data at
all, so those panels do not exist rather than showing invented numbers.

| Scene | Form | Why that form |
|---|---|---|
| Dashboard | hero figure + stat boxes | one number to lead with; single values are not one-bar charts |
| Spending trend | area, one series | trend — no legend, the title names it |
| Category split | donut | part-to-whole |
| Month compare | stacked bars | distinct series, so categorical colour |
| Daily calendar | heatmap, one hue | magnitude, not identity |
| Budgets | meters + ring | a ratio against a limit |
| Payees | ranked bars + grid | magnitude, then the detail |
| Transactions | data grid | more classes than colour can carry |

Payee ranking uses the recipient name the app's parser extracts — the same key
its auto-categorization rules are stored under. Transactions it could not name
(airtime top-ups, some agent withdrawals) count towards totals but are excluded
from the ranking rather than lumped into a misleading bucket; each panel says
how many.

## Colour

`styles/tokens.css` holds a validated categorical palette in fixed slot order, a
one-hue sequential ramp for magnitude, and a reserved status set. `theme.js`
feeds MUI the same values, and the toggle stamps `data-theme` on the root so the
chrome and the charts switch together. Light and dark are separately stepped
sets, not an inversion.

Three light-mode hues sit below 3:1 against the surface. That is allowed only
with relief, so every chart carries direct labels **and** a table view behind the
"Table" toggle. Over-budget always ships an icon and the word, never colour
alone.

The calendar bins by **quantile**, not by an even split of the range: spending is
lopsided, and a linear scale puts nearly every day in the first step.

Re-run the palette checks after changing any colour — do not eyeball them.

## A note on MUI v9

MUI v9 removed the shorthand system props (`display`, `p`, `gap`, `gridColumn`)
from `Box`. They no longer throw — they silently pass through to the DOM and do
nothing, which collapses the layout. Everything here uses `sx` instead. If you
copy a snippet from an older MUI tutorial, convert it.
