import { KES } from '../lib/selectors';
import { Empty } from './ui';

const DATE = new Intl.DateTimeFormat('en-GB', {
  day: '2-digit',
  month: 'short',
  year: '2-digit',
});

function formatDate(value) {
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? '—' : DATE.format(date);
}

export function TransactionsTable({ transactions, limit = 40 }) {
  if (!transactions.length) return <Empty>No transactions in the selected months.</Empty>;

  const rows = [...transactions]
    .sort((a, b) => new Date(b.date) - new Date(a.date))
    .slice(0, limit);

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Date</th>
            <th>Payee</th>
            <th>Category</th>
            <th>Description</th>
            <th className="num">Amount</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((tx) => (
            <tr key={tx.id ?? tx.mpesa_ref}>
              <td>{formatDate(tx.date)}</td>
              <td>{tx.payee?.trim() || '—'}</td>
              <td>{tx.category || 'Uncategorized'}</td>
              <td className="wrap">{tx.description || '—'}</td>
              <td className="num">{KES.format(Math.abs(Number(tx.amount) || 0))}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
