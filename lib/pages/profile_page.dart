import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../security/app_lock.dart';
import '../security/pin_views.dart';
import '../services/notification_service.dart';
import '../state/category_store.dart';
import '../theme/app_colors.dart';
import '../widgets/premium_ui.dart';
import '../widgets/magic_card.dart';

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

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  String _userName = '';
  final TextEditingController _nameController = TextEditingController();
  bool? _ignoringBatteryOptimizations;
  bool? _smsCaptureEnabled;
  int _rulesVersion = 0;
  bool _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserName();
    _checkBatteryOptimizations();
    _checkSmsCapture();
    _checkBiometrics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when the user comes back from a system permission dialog.
    if (state == AppLifecycleState.resumed) {
      _checkBatteryOptimizations();
      _checkSmsCapture();
      // A fingerprint may have been enrolled in system settings meanwhile.
      _checkBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    final available = await AppLock.instance.biometricsAvailable();
    if (mounted) setState(() => _biometricsAvailable = available);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleAppLock(bool on) async {
    final lock = AppLock.instance;
    if (on) {
      final pin = await showCreatePin(context);
      if (pin == null || !mounted) return;
      await lock.enable(pin);
      if (!mounted) return;
      if (_biometricsAvailable) {
        // Offer fingerprint straight away, the way most wallets do.
        final useFingerprint = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Unlock with fingerprint?'),
            content: const Text(
              'Use your fingerprint to open the app. Your PIN still works too.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Use fingerprint'),
              ),
            ],
          ),
        );
        if (useFingerprint == true) await _toggleBiometric(true);
      }
      if (mounted) _snack('App lock is on.');
    } else {
      final ok = await showVerifyPin(context, title: 'Enter PIN to turn off lock');
      if (!ok) return;
      await lock.disable();
      if (mounted) _snack('App lock is off.');
    }
  }

  Future<void> _toggleBiometric(bool on) async {
    final result = await AppLock.instance.setBiometricEnabled(on);
    if (!mounted) return;
    switch (result) {
      case BiometricResult.success:
        break;
      case BiometricResult.unavailable:
        _snack('No fingerprint is set up on this phone. Add one in system settings.');
        break;
      case BiometricResult.lockedOut:
        _snack('Fingerprint is locked after too many tries. Try again later.');
        break;
      case BiometricResult.failed:
        _snack("Fingerprint not confirmed, so it wasn't turned on.");
        break;
    }
  }

  Future<void> _changePin() async {
    final ok = await showVerifyPin(context, title: 'Enter your current PIN');
    if (!ok || !mounted) return;
    final pin = await showCreatePin(context, title: 'Enter a new PIN');
    if (pin == null) return;
    await AppLock.instance.changePin(pin);
    if (mounted) _snack('PIN changed.');
  }

  Widget _buildSecurityCard() {
    return ListenableBuilder(
      listenable: AppLock.instance,
      builder: (context, _) {
        final lock = AppLock.instance;
        final switchTheme = SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? AppColors.accent : null),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : null),
        );
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Theme(
              data: Theme.of(context).copyWith(switchTheme: switchTheme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Security',
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.lock_outline, color: AppColors.accent),
                    title: const Text('App lock',
                        style: TextStyle(color: AppColors.primaryText)),
                    subtitle: const Text(
                      'Ask for a PIN every time the app is opened',
                      style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                    ),
                    value: lock.isEnabled,
                    onChanged: _toggleAppLock,
                  ),
                  if (lock.isEnabled) ...[
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint, color: AppColors.accent),
                      title: const Text('Unlock with fingerprint',
                          style: TextStyle(color: AppColors.primaryText)),
                      subtitle: Text(
                        _biometricsAvailable
                            ? 'Your PIN still works as a backup'
                            : 'Set up a fingerprint in phone settings first',
                        style: const TextStyle(
                            color: AppColors.secondaryText, fontSize: 12),
                      ),
                      value: lock.isBiometricEnabled,
                      onChanged: _biometricsAvailable || lock.isBiometricEnabled
                          ? _toggleBiometric
                          : null,
                    ),
                    ListTile(
                      leading: const Icon(Icons.pin_outlined, color: AppColors.accent),
                      title: const Text('Change PIN',
                          style: TextStyle(color: AppColors.primaryText)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.secondaryText),
                      onTap: _changePin,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkBatteryOptimizations() async {
    final ignoring = await NotificationService.isIgnoringBatteryOptimizations();
    if (mounted) {
      setState(() => _ignoringBatteryOptimizations = ignoring);
    }
  }

  Future<void> _checkSmsCapture() async {
    final enabled = await NotificationService.isSmsCaptureEnabled();
    if (mounted) {
      setState(() => _smsCaptureEnabled = enabled);
    }
  }

  Future<void> _enableSmsCapture() async {
    final granted = await NotificationService.requestSmsCapture();
    if (!mounted) return;
    setState(() => _smsCaptureEnabled = granted);
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SMS access denied. M-Pesa capture will keep relying on notifications, '
            'which can miss messages.',
          ),
        ),
      );
    }
  }

  Future<void> _forgetRule(String recipient, String? categoryName) async {
    await context.read<CategoryStore>().forgetRecipientRule(recipient);
    if (!mounted) return;
    setState(() => _rulesVersion++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          categoryName == null
              ? 'Payments to $recipient will be asked about again.'
              : 'Payments to $recipient will no longer file under $categoryName.',
        ),
      ),
    );
  }

  /// Clearing is irreversible and the transactions do not come back on the next
  /// sweep, so it asks first and says exactly what will go.
  Future<void> _confirmClearUncategorized() async {
    final store = context.read<CategoryStore>();
    final count = store.uncategorizedTransactions.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear uncategorized queue?'),
        content: Text(
          '$count transaction${count == 1 ? '' : 's'} waiting to be categorized '
          'will be removed for good. Transactions already filed under a category '
          'are not affected, and neither are your auto-categorization rules.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final removed = await store.clearUncategorizedTransactions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Removed $removed uncategorized transaction${removed == 1 ? '' : 's'}.',
        ),
      ),
    );
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
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 2),
                        ),
                        child: const Icon(Icons.person, color: AppColors.accent, size: 30),
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

              // SMS CAPTURE — the only path that does not depend on a
              // notification being posted, so it is the one that stops
              // transactions being missed entirely.
              if (_smsCaptureEnabled == false)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.sms_failed, color: AppColors.accent, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Turn on SMS capture so nothing is missed',
                              style: TextStyle(
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Reading notifications alone misses transactions that arrive '
                        'while the app is not running, in a muted conversation, or while '
                        'you have the M-Pesa thread open. Allowing SMS access lets the '
                        'app read those messages directly, and recover ones already '
                        'missed.',
                        style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _enableSmsCapture,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Allow SMS access'),
                        ),
                      ),
                    ],
                  ),
                ),

              // BACKGROUND CAPTURE RELIABILITY WARNING
              if (_ignoringBatteryOptimizations == false)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.battery_alert, color: AppColors.accent, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Battery optimization may stop M-Pesa capture',
                              style: TextStyle(
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Android can kill background capture after the app has been closed '
                        'for a while. Exempt this app from battery optimization to keep it '
                        'listening for M-Pesa messages.',
                        style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              NotificationService.requestIgnoreBatteryOptimizations(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Allow background capture'),
                        ),
                      ),
                    ],
                  ),
                ),

              // SECURITY — PIN and fingerprint lock
              _buildSecurityCard(),

              // AUTO-CATEGORIZATION RULES
              //
              // Written whenever the user categorises a transaction that has a
              // payee name, so this list is the record of what will now be
              // filed without asking.
              FutureBuilder<List<Map<String, dynamic>>>(
                key: ValueKey(_rulesVersion),
                future: context.read<CategoryStore>().getRecipientRules(),
                builder: (context, snapshot) {
                  final rules = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (rules.isEmpty) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Auto-categorized payees',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Repeat payments to these are filed automatically. '
                          'Categorizing a transaction differently updates its rule.',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...rules.map((rule) {
                          final recipient = rule['recipient'] as String? ?? '';
                          final categoryName = rule['category_name'] as String?;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        recipient,
                                        style: const TextStyle(
                                          color: AppColors.primaryText,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        categoryName ?? 'Unknown category',
                                        style: const TextStyle(
                                          color: AppColors.secondaryText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  color: AppColors.secondaryText,
                                  tooltip: 'Stop auto-categorizing',
                                  onPressed: () =>
                                      _forgetRule(recipient, categoryName),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),

              // PENDING QUEUE
              Consumer<CategoryStore>(
                builder: (context, store, _) {
                  final pending = store.uncategorizedTransactions.length;
                  if (pending == 0) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$pending transaction${pending == 1 ? '' : 's'} waiting '
                          'to be categorized',
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Old payments you no longer want to file can be cleared '
                          'out. They will not come back.',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _confirmClearUncategorized,
                            icon: const Icon(Icons.delete_sweep_outlined),
                            label: const Text('Clear uncategorized queue'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
      : GridView.builder(
          shrinkWrap: true,
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
                                Expanded(
                                  child: Text(
                                    'Weekly: Ksh ${category.spentThisWeek.toStringAsFixed(0)} / ${category.weeklyBudget.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: AppColors.secondaryText,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
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
const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}