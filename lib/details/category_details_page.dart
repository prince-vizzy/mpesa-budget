import 'package:flutter/material.dart';
import '../models/category.dart';

Color budgetColor(double usage) {
  if (usage < 0.5) return Colors.green;
  if (usage < 0.8) return Colors.orange;
  return Colors.red;
}

class CategoryDetailsPage extends StatelessWidget {
  final Category category;

  const CategoryDetailsPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Daily Budget: KES ${category.dailyBudget}",
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 12),

            LinearProgressIndicator(
              value: category.dailyUsage.clamp(0, 1),
              color: budgetColor(category.dailyUsage),
            ),

            const SizedBox(height: 24),

            Text(
              "Weekly Budget: KES ${category.weeklyBudget}",
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 12),

            LinearProgressIndicator(
              value: category.weeklyUsage.clamp(0, 1),
              color: budgetColor(category.weeklyUsage),
            ),
          ],
        ),
      ),
    );
  }
}
