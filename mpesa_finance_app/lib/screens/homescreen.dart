import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/mpesa_transaction.dart';
import '../services/database_helper.dart';
import '../services/sms_listener_service.dart';
import '../services/notification_service.dart';
import 'permission_screen.dart';
import 'categorize_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MpesaTransaction> _transactions = [];
  bool _isLoading = true;
  final SmsListenerService _smsService = SmsListenerService.instance;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadTransactions();
    await _startListening();
    _checkForPendingCategory();
  }

  void _checkForPendingCategory() {
    final lastId = NotificationService.instance.lastTransactionId;
    if (lastId != null) {
      NotificationService.instance.clearLastTransactionId();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CategorizeScreen(transactionId: lastId),
            ),
          );
        }
      });
    }
  }

  Future<void> _loadTransactions() async {
    final transactions = await DatabaseHelper.instance.getAllTransactions();
    if (mounted) {
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    }
  }

  Future<void> _startListening() async {
    final hasPermission = await _smsService.requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PermissionScreen()),
        );
      }
      return;
    }

    _smsService.transactionStream.listen((transaction) {
      setState(() {
        _transactions.insert(0, transaction);
      });
    });

    await _smsService.startListening();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('M-Pesa Tracker'),
        backgroundColor: const Color(0xFF25D366),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? _buildEmptyState()
              : _buildTransactionList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'M-Pesa transactions will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final transaction = _transactions[index];
        return _buildTransactionTile(transaction);
      },
    );
  }

  Widget _buildTransactionTile(MpesaTransaction transaction) {
    final isReceived = transaction.type == 'received';
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    
    IconData icon;
    Color iconColor;
    String typeLabel;

    switch (transaction.type) {
      case 'sent':
        icon = Icons.arrow_upward;
        iconColor = Colors.red;
        typeLabel = 'Sent';
        break;
      case 'received':
        icon = Icons.arrow_downward;
        iconColor = Colors.green;
        typeLabel = 'Received';
        break;
      case 'withdraw':
        icon = Icons.account_balance;
        iconColor = Colors.orange;
        typeLabel = 'Withdraw';
        break;
      case 'airtime':
        icon = Icons.phone_android;
        iconColor = Colors.blue;
        typeLabel = 'Airtime';
        break;
      default:
        icon = Icons.swap_horiz;
        iconColor = Colors.grey;
        typeLabel = 'Other';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: () async {
            debugPrint('Long press triggered for transaction: ${transaction.id}');
            final confirm = await _showDeleteConfirmation(context, transaction);
            if (confirm == true) {
              await _deleteTransaction(transaction);
            }
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.1),
              child: Icon(icon, color: iconColor),
            ),
            title: Text(
              '${isReceived ? '+' : '-'} KES ${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isReceived ? Colors.green : Colors.black,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(typeLabel),
                if (transaction.name != null && transaction.name!.isNotEmpty)
                  Text(
                    transaction.name!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                if (transaction.phoneNumber.isNotEmpty)
                  Text(
                    transaction.phoneNumber,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                Text(
                  dateFormat.format(transaction.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
                if (transaction.userFirstName != null && transaction.userFirstName!.isNotEmpty)
                  Text(
                    'User: ${transaction.userFirstName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (transaction.message != null && transaction.message!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      transaction.message!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            isThreeLine: true,
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, MpesaTransaction transaction) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to delete this ${transaction.type} transaction of KES ${transaction.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(MpesaTransaction transaction) async {
    if (transaction.id == null) return;
    
    await DatabaseHelper.instance.deleteTransaction(transaction.id!);
    
    setState(() {
      _transactions.removeWhere((t) => t.id == transaction.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _smsService.stopListening();
    super.dispose();
  }
}