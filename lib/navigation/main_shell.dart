// lib/navigation/main_shell.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pages/home_page.dart';
import '../pages/history_page.dart';
import '../pages/profile_page.dart';
import '../state/category_store.dart';
import '../theme/app_colors.dart';
import '../widgets/frequency_loader.dart';

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
