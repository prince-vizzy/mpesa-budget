import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mpesa_transaction.dart';
import '../services/database_helper.dart';

class CategorizeScreen extends StatefulWidget {
  final int transactionId;

  const CategorizeScreen({super.key, required this.transactionId});

  @override
  State<CategorizeScreen> createState() => _CategorizeScreenState();
}

class _CategorizeScreenState extends State<CategorizeScreen> {
  MpesaTransaction? _transaction;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Food', 'icon': Icons.restaurant, 'color': Colors.orange},
    {'name': 'Transport', 'icon': Icons.directions_car, 'color': Colors.blue},
    {'name': 'Bills', 'icon': Icons.receipt_long, 'color': Colors.red},
    {'name': 'Shopping', 'icon': Icons.shopping_bag, 'color': Colors.purple},
    {'name': 'Entertainment', 'icon': Icons.movie, 'color': Colors.pink},
    {'name': 'Other', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    final transactions = await DatabaseHelper.instance.getAllTransactions();
    final transaction = transactions.where((t) => t.id == widget.transactionId).firstOrNull;
    
    if (mounted) {
      setState(() {
        _transaction = transaction;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectCategory(String category) async {
    if (_transaction == null) return;

    await DatabaseHelper.instance.updateTransactionCategory(widget.transactionId, category);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction categorized as $category'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Categorize')),
        body: const Center(child: Text('Transaction not found')),
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorize Transaction'),
        backgroundColor: const Color(0xFF25D366),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _transaction!.type == 'received' ? 'Received' : 'Sent',
                          style: TextStyle(
                            fontSize: 16,
                            color: _transaction!.type == 'received' 
                                ? Colors.green 
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'KES ${_transaction!.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_transaction!.name != null)
                      Text(
                        _transaction!.name!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    if (_transaction!.phoneNumber.isNotEmpty)
                      Text(
                        _transaction!.phoneNumber,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(_transaction!.timestamp),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return InkWell(
                    onTap: () => _selectCategory(category['name']),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: (category['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: category['color'] as Color,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            category['icon'] as IconData,
                            size: 40,
                            color: category['color'] as Color,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category['name'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: category['color'] as Color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}