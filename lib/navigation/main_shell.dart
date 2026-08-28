import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../pages/home_page.dart';
import '../pages/history_page.dart';
import '../pages/profile_page.dart';
import '../state/category_store.dart';
import '../theme/app_colors.dart';
import '../widgets/frequency_loader.dart';
import '../services/notification_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _booting = true;
  String? _bootError;
  bool _navVisible = true;
  bool _isCategorizeDialogOpen = false;
  StreamSubscription<NotificationEvent>? _notificationSub;

  final List<Widget> _pages = const [
    HomePage(),
    HistoryPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await context
            .read<CategoryStore>()
            .loadAllData()
            .timeout(const Duration(seconds: 8));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      } catch (_) {
        _bootError = 'Opening with cached data';
      }
      if (mounted) {
        setState(() {
          _booting = false;
        });
      }
    });
    
    // Set up notification listener at the MainShell level
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    _notificationSub = NotificationService.stream.listen((event) async {
      if (event.payload == 'refresh') {
        await _refreshAfterAutoCategorize();
        return;
      }
      if (event.payload != 'categorize') return;
      await _offerToCategorize();
    }, onError: (error) {
      debugPrint('Notification listener error: $error');
    });

    // A cold start from a notification tap, or a queue drained during startup,
    // raises its event before this listener exists. Collect it now.
    final pending = NotificationService.takePendingEvent();
    if (pending?.payload == 'categorize') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerToCategorize());
    } else if (pending?.payload == 'refresh') {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _refreshAfterAutoCategorize());
    }
  }

  /// A saved rule already filed the transaction, so there is nothing to ask the
  /// user — the UI just has to pick up the new spending.
  Future<void> _refreshAfterAutoCategorize() async {
    if (!mounted) return;
    await context.read<CategoryStore>().loadAllData();
  }

  Future<void> _offerToCategorize() async {
    if (!mounted || _isCategorizeDialogOpen) return;

    final store = context.read<CategoryStore>();
    await store.loadUncategorizedTransactions();
    if (!mounted || _isCategorizeDialogOpen) return;

    if (store.uncategorizedTransactions.isNotEmpty) {
      _showCategorizeDialog(store);
    }
  }

  void _showCategorizeDialog(CategoryStore store) {
    if (store.uncategorizedTransactions.isEmpty || _isCategorizeDialogOpen) {
      return;
    }
    _isCategorizeDialogOpen = true;

    final tx = store.uncategorizedTransactions.first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.mainBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Categorize Transaction',
            style: TextStyle(color: AppColors.primaryText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.componentBase,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Ksh ${tx.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: store.categories.map((cat) {
                      return Card(
                        color: AppColors.componentBase,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          title: Text(
                            cat.name,
                            style: const TextStyle(color: AppColors.primaryText),
                          ),
                          onTap: () async {
                            if (tx.id != null && cat.id != null) {
                              await store.categorizeTransaction(
                                transactionId: tx.id!,
                                categoryId: cat.id!,
                                categoryName: cat.name,
                              );
                              if (!mounted) return;
                              await store.loadUncategorizedTransactions();
                            }
                            if (mounted) {
                              Navigator.of(context).pop();
                              _isCategorizeDialogOpen = false;
                              if (store.uncategorizedTransactions.isNotEmpty) {
                                _showCategorizeDialog(store);
                              }
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                  _isCategorizeDialogOpen = false;
                }
              },
              child: const Text('Later',
                  style: TextStyle(color: AppColors.secondaryText)),
            ),
          ],
        );
      },
    ).then((_) {
      _isCategorizeDialogOpen = false;
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      // Only respond to vertical scrolling, ignore horizontal (e.g. category cards)
      final metrics = notification.metrics;
      if (metrics.axis != Axis.vertical) return false;

      final delta = notification.scrollDelta ?? 0;
      if (delta > 2 && _navVisible) {
        setState(() => _navVisible = false);
      } else if (delta < -2 && !_navVisible) {
        setState(() => _navVisible = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.mainBackground,
              AppColors.mainBackground,
            ],
          ),
        ),
        child: _booting
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FrequencyLoader(),
                    const SizedBox(height: 10),
                    Text(
                      _bootError ?? 'Loading your budget...',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            : NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: _pages[_index],
              ),
      ),
      bottomNavigationBar: _booting
          ? null
          : AnimatedSlide(
              offset: _navVisible ? Offset.zero : const Offset(0, 1.5),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.componentBase.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.darkShadow,
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BottomNavigationBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    currentIndex: _index,
                    onTap: (value) => setState(() {
                      _index = value;
                      _navVisible = true;
                    }),
                    selectedItemColor: AppColors.accent,
                    unselectedItemColor: AppColors.secondaryText,
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.dashboard_outlined),
                        activeIcon: Icon(Icons.dashboard),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.query_stats_outlined),
                        activeIcon: Icon(Icons.query_stats),
                        label: 'History',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person_outline),
                        activeIcon: Icon(Icons.person),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}