import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../state/category_store.dart';
import '../theme/app_colors.dart';
import '../widgets/premium_ui.dart';

// 🎨 Theme Colors
const Color darkPrimary = AppColors.mainBackground;
const Color cardBackground = AppColors.componentBase;
const Color accentColor = AppColors.accent;

// 🎨 Budget color helper
Color budgetColor(double usage) {
  if (usage < 0.5) return AppColors.accentLight;
  if (usage < 0.8) return AppColors.accent;
  return AppColors.accent;
}

/// A profile page displaying user information, budget summaries, spending details,
/// and a grid of budget categories in a dark-themed, banking-inspired UI.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _userName = '';
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final name = await DatabaseHelper.instance.getUserSetting('user_name');
    if (mounted && name != null) {
      setState(() => _userName = name);
      _nameController.text = name;
    }
  }

  Future<void> _showEditNameDialog() async {
    _nameController.text = _userName;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Your Name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Enter your first name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final newName = _nameController.text.trim();
      if (newName.isNotEmpty) {
        await DatabaseHelper.instance.setUserSetting('user_name', newName);
        setState(() => _userName = newName);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name updated successfully'),
              backgroundColor: AppColors.accent,
            ),
          );
        }
      }
    }
  }

  /// Builds a reusable row widget for displaying metrics with labels, values, and optional icons.
  Widget _buildMetricRow({
    required String label,
    required String value,
    required Color valueColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.lightShadow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                label,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Access the shared store instance
    final categories = context.watch<CategoryStore>().categories;

    // Calculate totals - daily categories only for daily/weekly cards
    final dailyCategories = categories.where((c) => !c.isMonthly).toList();
    final monthlyCategories = categories.where((c) => c.isMonthly).toList();

    final totalDailyBudget = dailyCategories.fold<double>(0, (sum, c) => sum + c.dailyBudget);
    final totalDailySpent = dailyCategories.fold<double>(0, (sum, c) => sum + c.spentToday);
    final potentialDailySavings = totalDailyBudget - totalDailySpent;

    final totalWeeklyBudget = dailyCategories.fold<double>(0, (sum, c) => sum + c.weeklyBudget);
    final totalWeeklySpent = dailyCategories.fold<double>(0, (sum, c) => sum + c.spentThisWeek);
    final potentialWeeklySavings = totalWeeklyBudget - totalWeeklySpent;

    // Monthly projection accounts for ALL categories
    final dailyProjectedMonthly = totalWeeklyBudget * 4;
    final monthlyCategoriesTotal = monthlyCategories.fold<double>(0, (sum, c) => sum + c.monthlyBudget);
    final totalMonthlyBudget = dailyProjectedMonthly + monthlyCategoriesTotal;

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
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
              child: const Center(
                child: Text(
                  'Profile',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
              ),
            ),
          ),
        ),
      ),
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
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // USER PROFILE CARD
            Container(
              margin: const EdgeInsets.all(16),
              child: GlassPanel(
                padding: const EdgeInsets.all(20),
                child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 2),
                    ),
                    child: const Icon(Icons.person, color: accentColor, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName.isNotEmpty ? _userName : 'User',
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "MPESA Budget Tracker",
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${categories.length} Active Categories",
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ),
              ),
            ),

            // BUDGET OVERVIEW SECTION
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'Budget Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // BUDGET CARDS
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      decoration: BoxDecoration(
                        color: AppColors.componentBase,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.calendar_today, color: AppColors.accent, size: 20),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Daily',
                                style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ksh ${totalDailyBudget.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Spent: Ksh ${totalDailySpent.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      decoration: BoxDecoration(
                        color: AppColors.componentBase,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.calendar_view_week, color: AppColors.accent, size: 20),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Weekly',
                                style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ksh ${totalWeeklyBudget.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Spent: Ksh ${totalWeeklySpent.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              constraints: const BoxConstraints(minHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.componentBase,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month, color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Monthly Projection',
                          style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ksh ${totalMonthlyBudget.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Based on weekly + monthly',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SAVINGS SECTION
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.componentBase,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildMetricRow(
                    label: "Daily Savings Potential",
                    value: "Ksh ${potentialDailySavings.toStringAsFixed(0)}",
                    valueColor: AppColors.accent,
                    icon: Icons.trending_up,
                  ),
                  const Divider(color: AppColors.lightShadow, height: 1),
                  _buildMetricRow(
                    label: "Weekly Savings Potential",
                    value: "Ksh ${potentialWeeklySavings.toStringAsFixed(0)}",
                    valueColor: AppColors.accent,
                    icon: Icons.savings,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // CATEGORIES SECTION
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Budget Categories",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.lightShadow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${categories.length} total",
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

             // CATEGORY GRID - FIXED LAYOUT
             Container(
               margin: const EdgeInsets.symmetric(horizontal: 16),
               child: categories.isEmpty
                   ? Container(
                       padding: const EdgeInsets.all(40),
                       decoration: BoxDecoration(
                         color: AppColors.componentBase,
                         borderRadius: BorderRadius.circular(16),
                       ),
                       child: const Column(
                         children: [
                           Icon(Icons.category_outlined, color: AppColors.secondaryText, size: 48),
                           SizedBox(height: 12),
                           Text(
                             "No categories yet",
                             style: TextStyle(color: AppColors.secondaryText),
                           ),
                           SizedBox(height: 4),
                           Text(
                             "Add categories from the dashboard",
                             style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                             textAlign: TextAlign.center,
                           ),
                         ],
                       ),
                     )
                   : SizedBox(
                       width: double.infinity,
                       height: _calculateGridHeight(categories.length),
                       child: GridView.builder(
                         physics: const NeverScrollableScrollPhysics(),
                         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                           crossAxisCount: 2,
                           crossAxisSpacing: 12,
                           mainAxisSpacing: 12,
                           childAspectRatio: 1,
                         ),
                         itemCount: categories.length,
                         itemBuilder: (context, index) {
                           final category = categories[index];
                           final isMonthly = category.isMonthly;
                           final totalBudget = category.budget;
                           final spent = category.spent;
                           final usage = totalBudget > 0
                               ? spent / totalBudget
                               : 0.0;
                           final color = budgetColor(usage);

                           return Container(
                             decoration: BoxDecoration(
                               color: AppColors.componentBase,
                               borderRadius: BorderRadius.circular(16),
                             ),
                             child: Padding(
                               padding: const EdgeInsets.all(16),
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 children: [
                                   Row(
                                     children: [
                                       Container(
                                         width: 32,
                                         height: 32,
                                         decoration: BoxDecoration(
                                           color: color.withValues(alpha: 0.1),
                                           borderRadius: BorderRadius.circular(8),
                                         ),
                                         child: Icon(Icons.category, color: color, size: 18),
                                       ),
                                       const SizedBox(width: 8),
                                       Expanded(
                                         child: Text(
                                           category.name,
                                           style: const TextStyle(
                                             color: AppColors.primaryText,
                                             fontSize: 14,
                                             fontWeight: FontWeight.w600,
                                           ),
                                           overflow: TextOverflow.ellipsis,
                                         ),
                                       ),
                                     ],
                                   ),
                                   Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(
                                         'Ksh ${spent.toStringAsFixed(0)} / ${totalBudget.toStringAsFixed(0)}',
                                         style: const TextStyle(
                                           color: AppColors.primaryText,
                                           fontSize: 14,
                                           fontWeight: FontWeight.bold,
                                         ),
                                       ),
                                       const SizedBox(height: 8),
                                       ClipRRect(
                                         borderRadius: BorderRadius.circular(4),
                                         child: LinearProgressIndicator(
                                           value: usage.clamp(0, 1),
                                           minHeight: 6,
                                           backgroundColor: AppColors.lightShadow,
                                           valueColor: AlwaysStoppedAnimation<Color>(color),
                                         ),
                                       ),
                                       const SizedBox(height: 4),
                                       Row(
                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                         children: [
                                           Text(
                                             '${(usage * 100).toStringAsFixed(0)}% used',
                                             style: TextStyle(
                                               color: color,
                                               fontSize: 11,
                                               fontWeight: FontWeight.w500,
                                             ),
                                           ),
                                           Text(
                                             isMonthly ? 'Monthly' : 'Weekly',
                                             style: TextStyle(
                                               color: AppColors.secondaryText,
                                               fontSize: 10,
                                             ),
                                           ),
                                         ],
                                       ),
                                       if (!isMonthly) ...[
                                         const SizedBox(height: 8),
                                         Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                           decoration: BoxDecoration(
                                             color: AppColors.lightShadow.withValues(alpha: 0.3),
                                             borderRadius: BorderRadius.circular(6),
                                           ),
                                           child: Row(
                                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                             children: [
                                               Text(
                                                 'Weekly: Ksh ${category.spentThisWeek.toStringAsFixed(0)} / ${category.weeklyBudget.toStringAsFixed(0)}',
                                                 style: TextStyle(
                                                   color: AppColors.secondaryText,
                                                   fontSize: 10,
                                                   fontWeight: FontWeight.w500,
                                                 ),
                                               ),
                                               Text(
                                                 '${category.weeklyBudget > 0 ? ((category.spentThisWeek / category.weeklyBudget) * 100).toStringAsFixed(0) : 0}%',
                                                 style: TextStyle(
                                                   color: AppColors.secondaryText,
                                                   fontSize: 10,
                                                   fontWeight: FontWeight.w500,
                                                 ),
                                               ),
                                             ],
                                           ),
                                         ),
                                       ],
                                     ],
                                   ),
                                 ],
                               ),
                             ),
                           );
                         },
                       ),
                     ),
            ),
            const SizedBox(height: 30),
          ],
          ),
        ),
      ),
    );
  }

  double _calculateGridHeight(int itemCount) {
    if (itemCount <= 2) return 180;  // 1 row
    if (itemCount <= 4) return 360;  // 2 rows
    if (itemCount <= 6) return 540;  // 3 rows
    return 720; // 4 rows max (should be enough for most cases)
  }
}