import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { connect, fetchCategories, fetchTransactions } from './api';
import { filterByMonths, monthsIn } from './selectors';

/**
 * One connection and one copy of the data for the whole app.
 *
 * Every scene reads from here, so switching pages never re-opens the socket or
 * re-fetches, and the month filter stays put as you navigate.
 */
const DataContext = createContext(null);

export function DataProvider({ children }) {
  const [transactions, setTransactions] = useState([]);
  const [categories, setCategories] = useState([]);
  const [status, setStatus] = useState('wait');
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selectedMonths, setSelectedMonths] = useState([]);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const [tx, cats] = await Promise.all([fetchTransactions(), fetchCategories()]);
      setTransactions(tx ?? []);
      setCategories(cats ?? []);
      setError(null);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();

    const disconnect = connect({
      onStatus: setStatus,
      onTransactions: (rows) => setTransactions(rows),
      onTransaction: (row) =>
        setTransactions((prev) =>
          // The backend broadcasts every insert, including ones we already hold.
          prev.some((t) => t.id === row.id) ? prev : [row, ...prev],
        ),
      onCategories: (rows) => {
        if (rows) setCategories(rows);
        else fetchCategories().then(setCategories).catch(() => {});
      },
    });

    return disconnect;
  }, [refresh]);

  const months = useMemo(() => monthsIn(transactions), [transactions]);
  const inView = useMemo(
    () => filterByMonths(transactions, selectedMonths),
    [transactions, selectedMonths],
  );
  const monthCount = selectedMonths.length || months.length || 1;

  const scope = useMemo(() => {
    const label =
      selectedMonths.length === 0
        ? 'All months'
        : selectedMonths.length === 1
          ? '1 month'
          : `${selectedMonths.length} months`;
    return `${label} · ${inView.length} transaction${inView.length === 1 ? '' : 's'}`;
  }, [selectedMonths, inView.length]);

  const value = useMemo(
    () => ({
      transactions,
      categories,
      inView,
      months,
      monthCount,
      selectedMonths,
      setSelectedMonths,
      status,
      error,
      loading,
      refresh,
      scope,
    }),
    [
      transactions,
      categories,
      inView,
      months,
      monthCount,
      selectedMonths,
      status,
      error,
      loading,
      refresh,
      scope,
    ],
  );

  return <DataContext.Provider value={value}>{children}</DataContext.Provider>;
}

export function useData() {
  const value = useContext(DataContext);
  if (!value) throw new Error('useData must be used inside a DataProvider');
  return value;
}
