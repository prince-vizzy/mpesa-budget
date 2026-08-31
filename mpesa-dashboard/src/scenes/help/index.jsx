import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Box,
  Typography,
} from '@mui/material';
import ExpandMoreOutlinedIcon from '@mui/icons-material/ExpandMoreOutlined';
import Header from '../../components/Header';

const ENTRIES = [
  {
    q: 'Where does this data come from?',
    a: `The Flutter app is the source of truth. After every change it POSTs its
        categories and transactions to the backend at /api/sync. The backend stores
        them and broadcasts over socket.io; this dashboard loads the current state
        over REST and stays current from those events. Nothing is typed in here —
        if a number looks wrong, it is wrong in the app.`,
  },
  {
    q: 'How does the app capture M-Pesa messages?',
    a: `Three sources feed one durable queue. An SMS broadcast receiver fires for
        every incoming message whether or not a notification is posted. An inbox
        sweep runs on launch, resume, boot and listener reconnect, recovering
        anything that arrived while the app had no process. A notification listener
        covers what never arrives as SMS — the M-PESA app itself and bank alerts.
        All three de-duplicate on the M-Pesa transaction code.`,
  },
  {
    q: 'Why is there no income, and no investments or loans?',
    a: `The app's parser deliberately keeps only expense-like events — sent, paid,
        withdraw, airtime, transfer — and drops money received. It has no source of
        investment or loan data at all. Rather than fill those panels with invented
        numbers, this dashboard shows only what the data supports.`,
  },
  {
    q: 'Why do some transactions have no payee?',
    a: `The payee is the recipient name the app's parser extracts from the message.
        Airtime top-ups have no recipient, and some agent withdrawals are worded so
        that no name can be read. Those transactions still count towards every total
        — they are only left out of the payee ranking, which says how many.`,
  },
  {
    q: 'How does auto-categorization work?',
    a: `Categorizing a transaction in the app records a rule for that payee, keyed on
        a normalized form of the name so one rule covers the spellings the parser
        produces. The next payment to that payee is filed on arrival instead of
        queueing. Re-categorizing corrects the rule; rules can be removed in the
        app's settings.`,
  },
  {
    q: 'What do the budget percentages mean here?',
    a: `Category budgets are set in the app as daily or monthly amounts. This
        dashboard scales them to the months you have selected, so choosing three
        months compares your spending against three months of budget. Over-budget is
        always marked with an icon and the word, never colour alone.`,
  },
  {
    q: 'Why does a chart fold categories into one bucket?',
    a: `Colour stops being a reliable way to tell series apart past a handful, and
        generating more hues makes it worse rather than better — a new hue is
        indistinguishable from an existing one for a colourblind reader. Past the
        cap the tail folds into a single labelled bucket, and the full numbers stay
        available behind each panel's Table toggle.`,
  },
];

export default function Help() {
  return (
    <Box>
      <Header
        title="How capture works"
        subtitle="What this dashboard shows, and what it deliberately does not"
      />

      <Box sx={{ maxWidth: 900 }}>
        {ENTRIES.map((entry) => (
          <Accordion key={entry.q} disableGutters elevation={0} sx={{ mb: 1 }}>
            <AccordionSummary expandIcon={<ExpandMoreOutlinedIcon />}>
              <Typography variant="h5">{entry.q}</Typography>
            </AccordionSummary>
            <AccordionDetails>
              <Typography variant="body2" color="text.secondary">
                {entry.a}
              </Typography>
            </AccordionDetails>
          </Accordion>
        ))}
      </Box>
    </Box>
  );
}
