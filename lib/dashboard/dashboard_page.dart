import 'package:flutter/material.dart';
import '../models/category.dart';
import '../details/category_details_page.dart';

// ✅ Budget color helper
Color budgetColor(double usage) {
  if (usage < 0.5) return Colors.green;
  if (usage < 0.8) return Colors.orange;
  return Colors.red;
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<Category> categories = [];

  void _addCategory() {
    final nameCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Category"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: "Category name"),
            ),
            TextField(
              controller: budgetCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: "Daily Budget (KES)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final budget = double.tryParse(budgetCtrl.text);
              if (nameCtrl.text.isEmpty || budget == null) return;

              setState(() {
                categories.add(
                  Category(
                    name: nameCtrl.text,
                    dailyBudget: budget,
                  ),
                );
              });

              Navigator.pop(context);
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MPESA Budget Tracker")),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          // ➕ ADD CARD
          if (index == categories.length) {
            return GestureDetector(
              onTap: _addCategory,
              child: const Card(
                child: Center(
                  child: Icon(Icons.add, size: 48),
                ),
              ),
            );
          }

          // ✅ CATEGORY CARD
          final category = categories[index];
          final dailyRemaining =
              category.dailyBudget - category.spentToday;
          final weeklyRemaining =
              category.weeklyBudget - category.spentThisWeek;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CategoryDetailsPage(category: category),
                ),
              );
            },
            child: Card(
              color:
                  budgetColor(category.dailyUsage).withOpacity(0.15),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text("Daily left: KES ${dailyRemaining.toStringAsFixed(0)}"),
                    LinearProgressIndicator(
                      value: category.dailyUsage.clamp(0, 1),
                      color: budgetColor(category.dailyUsage),
                    ),

                    const SizedBox(height: 10),

                    Text("Weekly left: KES ${weeklyRemaining.toStringAsFixed(0)}"),
                    LinearProgressIndicator(
                      value: category.weeklyUsage.clamp(0, 1),
                      color: budgetColor(category.weeklyUsage),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
