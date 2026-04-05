import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../state/category_store.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../theme/app_colors.dart';
import '../widgets/premium_ui.dart';
import '../services/notification_service.dart';

// ===================================================
// DASHBOARD PAGE
// ===================================================
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isCategorizeDialogOpen = false;
  StreamSubscription<NotificationEvent>? _notificationSub;

  @override
  void initState() {
    super.initState();
    _notificationSub = NotificationService.stream.listen((event) async {
      if (!mounted || _isCategorizeDialogOpen) return;
      if (event.payload != 'categorize') return;

      final store = context.read<CategoryStore>();
      await store.loadUncategorizedTransactions();
      if (!mounted || _isCategorizeDialogOpen) return;

      if (store.uncategorizedTransactions.isNotEmpty) {
        _showCategorizeDialog(store);
      }
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  void _showCategorizeDialog(CategoryStore store) {
    if (store.uncategorizedTransactions.isEmpty || _isCategorizeDialogOpen) return;
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
                        fontWeight: FontWeight.bold
                      )),
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
              child: const Text('Later', style: TextStyle(color: AppColors.secondaryText)),
            ),
          ],
        );
      },
    ).then((_) {
      _isCategorizeDialogOpen = false;
    });
  }

  // =========================================================
  // CATEGORY CREATION DIALOG LOGIC
  // =========================================================

  Future<void> _showBudgetSelectionDialog(BuildContext context, CategoryStore store) async {
    final selectedType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.mainBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('New Category Budget Type', style: TextStyle(color: AppColors.primaryText)),
        content: const Text(
          'Do you want to set a daily or a monthly budget?',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('Daily'),
            child: const Text('Daily Budget', style: TextStyle(color: AppColors.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('Monthly'),
            child: const Text('Monthly Budget', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (selectedType != null) {
      _showCreateCategoryDialog(context, store, selectedType);
    }
  }

  Future<void> _showCreateCategoryDialog(
    BuildContext context,
    CategoryStore store,
    String budgetType,
  ) async {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.mainBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Create ${budgetType} Budget Category', 
            style: const TextStyle(color: AppColors.primaryText)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.primaryText),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  labelStyle: const TextStyle(color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.componentBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: budgetController,
                style: const TextStyle(color: AppColors.primaryText),
                decoration: InputDecoration(
                  labelText: 'Budget Amount (Ksh.)',
                  labelStyle: const TextStyle(color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.componentBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                
                final cleanBudgetString = budgetController.text.replaceAll(RegExp(r'[^\d.]'), '');
                final budgetAmount = double.tryParse(cleanBudgetString);

                if (name.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Category name cannot be empty.'),
                      backgroundColor: AppColors.darkShadow,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                   return;
                }
                
                if (budgetAmount == null || budgetAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter a valid budget amount.'),
                      backgroundColor: AppColors.darkShadow,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                  return; 
                }
                
                double dailyBudget = 0.0;
                double weeklyBudget = 0.0;
                double monthlyBudget = 0.0;
                String type = 'daily';

                if (budgetType == 'Daily') {
                  dailyBudget = budgetAmount;
                  weeklyBudget = budgetAmount * 7;
                  monthlyBudget = budgetAmount * 30;
                } else {
                  monthlyBudget = budgetAmount;
                  dailyBudget = budgetAmount / 30;
                  weeklyBudget = dailyBudget * 7;
                  type = 'monthly';
                }

                final int newId = DateTime.now().millisecondsSinceEpoch;

                final newCategory = Category(
                  id: newId,
                  name: name,
                  budgetType: type,
                  dailyBudget: dailyBudget,
                  weeklyBudget: weeklyBudget,
                  monthlyBudget: monthlyBudget,
                  spentToday: 0,
                  spentThisWeek: 0,
                  spentThisMonth: 0,
                  spentThisYear: 0,
                );
                
                try {
                  await store.addCategory(newCategory);
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add category. Check logs for details.'),
                      backgroundColor: AppColors.darkShadow,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                   );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Create', style: TextStyle(color: AppColors.primaryText)),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // CARD LONG PRESS LOGIC
  // =========================================================
  
  Future<void> _showCategoryOptionsDialog(
    BuildContext context,
    CategoryStore store,
    Category category,
  ) async {
    final monthlyApprox = category.dailyBudget * 30;
    final isMonthly = category.isMonthly;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.mainBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMonthly
                        ? 'Budget: Ksh ${category.monthlyBudget.toStringAsFixed(0)} Monthly'
                        : 'Budget: Ksh ${category.dailyBudget.toStringAsFixed(0)} Daily / ${monthlyApprox.toStringAsFixed(0)} Monthly',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              color: AppColors.componentBase,
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.accent),
              title: const Text('Change Budget', style: TextStyle(color: AppColors.primaryText)),
              onTap: () {
                Navigator.pop(context);
                _showEditBudgetDialog(context, store, category);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.accent),
              title: const Text('Delete Category', style: TextStyle(color: AppColors.primaryText)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmationDialog(context, store, category);
              },
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteTransactionDialog(
    BuildContext context,
    CategoryStore store,
    Transaction tx,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.mainBackground,
        title: const Text('Delete Transaction', style: TextStyle(color: AppColors.primaryText)),
        content: Text(
          'Delete Ksh ${tx.amount.toStringAsFixed(2)} - ${tx.description}?',
          style: const TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await store.deleteTransaction(tx.id!);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        );
      }
    }
  }
  
  void _showEditBudgetDialog(BuildContext context, CategoryStore store, Category category) {
    const int DAYS_IN_MONTH = 30;
    final isMonthly = category.isMonthly;
    final monthlyApprox = category.dailyBudget * DAYS_IN_MONTH;

    final dailyController = TextEditingController(text: category.dailyBudget.toStringAsFixed(0));
    final monthlyController = TextEditingController(text: (isMonthly ? category.monthlyBudget : monthlyApprox).toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.mainBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Edit Budget for ${category.name}',
            style: const TextStyle(color: AppColors.primaryText)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dailyController,
                style: const TextStyle(color: AppColors.primaryText),
                decoration: InputDecoration(
                  labelText: 'Daily Budget (Ksh.)',
                  labelStyle: const TextStyle(color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.componentBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                keyboardType: TextInputType.number,
                onChanged: (text) {
                  final daily = double.tryParse(text.replaceAll(RegExp(r'[^\d.]'), ''));
                  if (daily != null) {
                    monthlyController.text = (daily * DAYS_IN_MONTH).toStringAsFixed(0);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: monthlyController,
                style: const TextStyle(color: AppColors.primaryText),
                decoration: InputDecoration(
                  labelText: 'Monthly Budget (Ksh.)',
                  labelStyle: const TextStyle(color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.componentBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                keyboardType: TextInputType.number,
                onChanged: (text) {
                  final monthly = double.tryParse(text.replaceAll(RegExp(r'[^\d.]'), ''));
                  if (monthly != null) {
                    dailyController.text = (monthly / DAYS_IN_MONTH).toStringAsFixed(0);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText))
            ),
            TextButton(
              onPressed: () async {
                final newDaily = double.tryParse(dailyController.text.replaceAll(RegExp(r'[^\d.]'), ''));
                final newMonthly = double.tryParse(monthlyController.text.replaceAll(RegExp(r'[^\d.]'), ''));

                if (newDaily != null && newDaily > 0) {
                  final newWeekly = newDaily * 7;

                  final updatedCategory = category.copyWith(
                    dailyBudget: newDaily,
                    weeklyBudget: newWeekly,
                    monthlyBudget: newMonthly ?? (newDaily * DAYS_IN_MONTH),
                  );
                  await store.updateCategory(updatedCategory);
                  if (mounted) Navigator.pop(context);
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter a valid budget amount.'),
                      backgroundColor: AppColors.darkShadow,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Save', style: TextStyle(color: AppColors.primaryText)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, CategoryStore store, Category category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.mainBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Confirm Deletion', style: TextStyle(color: AppColors.primaryText)),
          content: Text(
            'Are you sure you want to delete the category "${category.name}"? This action cannot be undone.',
            style: const TextStyle(color: AppColors.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText))
            ),
            TextButton(
              onPressed: () async {
                if (category.id != null) {
                  await store.deleteCategory(category.id!);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Delete', style: TextStyle(color: AppColors.primaryText)),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryStore>(
      builder: (context, store, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(88),
            child: Container(
              color: AppColors.mainBackground,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Container(
                  height: 62,
                  decoration: BoxDecoration(
                    color: AppColors.mainBackground,
                    borderRadius: BorderRadius.circular(31),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.darkShadow,
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Spending Dashboard',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // CATEGORY CARDS
                const Text(
                  'Current Category Budgets',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
SizedBox(
  width: double.infinity,
  height: 180,
  child: ListView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.only(left: 16, right: 16),
    children: [
      ...store.categories.map((category) => CategoryCard(
        category: category,
        onLongPress: () => _showCategoryOptionsDialog(context, store, category),
      )).toList(),
      
      AddCategoryCard(onTap: () => _showBudgetSelectionDialog(context, store)),
    ],
  ),
),

                const SizedBox(height: 24),

                // LATEST TRANSACTIONS
                const Text(
                  'Latest Transactions',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
GlassPanel(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  child: FutureBuilder<List<Transaction>>(
                    future: store.getAllCategorizedTransactions(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          child: const Center(
                            child: Text(
                              'No transactions yet.',
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: snapshot.data!.take(5).map((tx) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Card(
                              color: AppColors.componentBase,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                onLongPress: () => _showDeleteTransactionDialog(context, store, tx),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  tx.name ?? tx.description,
                                  style: const TextStyle(
                                    color: AppColors.primaryText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  '${tx.categoryName ?? 'Uncategorized'} • '
                                  '${DateFormat('MMM d, y').format(tx.date)}',
                                  style: const TextStyle(color: AppColors.secondaryText),
                                ),
                                trailing: Text(
                                  'Ksh ${tx.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
              ),
            ),
        );
      },
    );
  }
}

// =========================================================
// CATEGORY CARDS
// =========================================================
class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onLongPress; 

  const CategoryCard({
    super.key,
    required this.category,
    required this.onLongPress, 
  });

  @override
  Widget build(BuildContext context) {
    final totalBudget = category.budget;
    final spent = category.spent;
    final isMonthly = category.isMonthly;
    final progress =
        totalBudget <= 0 ? 0.0 : (spent / totalBudget).clamp(0.0, 1.0);

    Color progressColor = AppColors.accent;
    if (progress > 0.9) {
      progressColor = AppColors.lightShadow;
    } else if (progress > 0.7) {
      progressColor = AppColors.accent;
    }

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Card(
          elevation: 2,
          color: AppColors.componentBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(category.name,
                        style: const TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: progressColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Ksh ${spent.toStringAsFixed(0)} / ${totalBudget.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14, 
                    color: AppColors.secondaryText,
                  )),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.lightShadow,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isMonthly ? 'This Month' : 'Today',
                      style: TextStyle(
                        fontSize: 10,
                        color: progressColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isMonthly
                          ? 'Ksh ${category.monthlyBudget.toStringAsFixed(0)}'
                          : 'Daily',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddCategoryCard extends StatelessWidget {
  final VoidCallback onTap;
  const AddCategoryCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Card(
          elevation: 2,
          color: AppColors.componentBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3), width: 2),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 24,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add Category', 
                  style: TextStyle(
                    fontSize: 14, 
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}