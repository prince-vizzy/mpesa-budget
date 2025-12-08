class Category {
  final String name;

  final double dailyBudget;
  double spentToday;
  double spentThisWeek;

  Category({
    required this.name,
    required this.dailyBudget,
    this.spentToday = 0,
    this.spentThisWeek = 0,
  });

  double get weeklyBudget => dailyBudget * 7;

  double get dailyUsage =>
      dailyBudget == 0 ? 0 : spentToday / dailyBudget;

  double get weeklyUsage =>
      weeklyBudget == 0 ? 0 : spentThisWeek / weeklyBudget;
}
