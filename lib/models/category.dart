// lib/models/category.dart

class Category {
  final int? id;
  final String name;
  final String budgetType; // 'daily' or 'monthly'
  final double dailyBudget;
  final double weeklyBudget;
  final double monthlyBudget;
  final double spentToday;
  final double spentThisWeek;
  final double spentThisMonth;
  final double spentThisYear;

  Category({
    this.id,
    required this.name,
    this.budgetType = 'daily',
    required this.dailyBudget,
    required this.weeklyBudget,
    this.monthlyBudget = 0,
    required this.spentToday,
    required this.spentThisWeek,
    this.spentThisMonth = 0,
    required this.spentThisYear,
  });

  bool get isMonthly => budgetType == 'monthly';

  double get budget => isMonthly ? monthlyBudget : dailyBudget;
  double get spent => isMonthly ? spentThisMonth : spentToday;

  double get usage {
    if (budget <= 0) return spent > 0 ? 1.0 : 0.0;
    return spent / budget;
  }

  double get weeklyUsage {
    if (weeklyBudget <= 0) {
      return spentThisWeek > 0 ? 1.0 : 0.0;
    }
    return spentThisWeek / weeklyBudget;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'budget_type': budgetType,
      'daily_budget': dailyBudget,
      'weekly_budget': weeklyBudget,
      'monthly_budget': monthlyBudget,
      'spent_today': spentToday,
      'spent_this_week': spentThisWeek,
      'spent_this_month': spentThisMonth,
      'spent_this_year': spentThisYear,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      budgetType: (map['budget_type'] as String?) ?? 'daily',
      dailyBudget: (map['daily_budget'] as num).toDouble(),
      weeklyBudget: (map['weekly_budget'] as num).toDouble(),
      monthlyBudget: (map['monthly_budget'] as num? ?? 0).toDouble(),
      spentToday: (map['spent_today'] as num).toDouble(),
      spentThisWeek: (map['spent_this_week'] as num).toDouble(),
      spentThisMonth: (map['spent_this_month'] as num? ?? 0).toDouble(),
      spentThisYear: (map['spent_this_year'] as num).toDouble(),
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? budgetType,
    double? dailyBudget,
    double? weeklyBudget,
    double? monthlyBudget,
    double? spentToday,
    double? spentThisWeek,
    double? spentThisMonth,
    double? spentThisYear,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      budgetType: budgetType ?? this.budgetType,
      dailyBudget: dailyBudget ?? this.dailyBudget,
      weeklyBudget: weeklyBudget ?? this.weeklyBudget,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      spentToday: spentToday ?? this.spentToday,
      spentThisWeek: spentThisWeek ?? this.spentThisWeek,
      spentThisMonth: spentThisMonth ?? this.spentThisMonth,
      spentThisYear: spentThisYear ?? this.spentThisYear,
    );
  }
}
