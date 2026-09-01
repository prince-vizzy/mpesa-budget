import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/budget_event.dart';
import '../state/event_store.dart';
import '../theme/app_colors.dart';
import 'events_page.dart' show formatMoney, formatMoment, formatWindow;
import 'new_event_page.dart' show showEventCategoryDialog;

class EventDetailPage extends StatelessWidget {
  final int eventId;

  const EventDetailPage({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EventStore>();

    BudgetEvent? event;
    for (final candidate in store.events) {
      if (candidate.id == eventId) event = candidate;
    }

    if (event == null) {
      // Deleted from underneath us.
      return Scaffold(
        backgroundColor: AppColors.mainBackground,
        appBar: AppBar(
          backgroundColor: AppColors.mainBackground,
          foregroundColor: AppColors.primaryText,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'This event no longer exists.',
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
      );
    }

    return _EventDetailView(event: event);
  }
}

class _EventDetailView extends StatelessWidget {
  final BudgetEvent event;

  const _EventDetailView({required this.event});

  Future<void> _confirmDelete(BuildContext context) async {
    final store = context.read<EventStore>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.mainBackground,
        title: Text(
          'Delete ${event.name}?',
          style: const TextStyle(color: AppColors.primaryText),
        ),
        content: const Text(
          'The event and its categories go. Payments captured during it are '
          'kept and return to the normal uncategorized queue, so nothing real '
          'is lost.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await store.deleteEvent(event.id!);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _addCategory(BuildContext context) async {
    final store = context.read<EventStore>();
    final draft = await showEventCategoryDialog(context);
    if (draft == null) return;
    await store.addCategory(event.id!, draft.name, draft.budget);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EventStore>();
    final pending = store.queueCountFor(event.id);
    final usage = event.usage;

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: AppColors.mainBackground,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        title: Text(event.name),
        actions: [
          IconButton(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete event',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            formatWindow(event),
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Headline: spent against budget.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.componentBase,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatMoney(event.spent),
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  event.budget > 0
                      ? 'of ${formatMoney(event.budget)} budgeted'
                      : 'spent · no budget set',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                if (event.budget > 0) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (usage ?? 0).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: AppColors.mainBackground,
                      valueColor: AlwaysStoppedAnimation(
                        event.isOverBudget ? Colors.redAccent : AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.isOverBudget
                        ? 'Over by ${formatMoney(event.spent - event.budget)}'
                        : '${formatMoney(event.budget - event.spent)} left',
                    style: TextStyle(
                      color: event.isOverBudget
                          ? Colors.redAccent
                          : AppColors.secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (pending > 0) ...[
            const SizedBox(height: 20),
            _PendingSection(event: event),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Categories',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _addCategory(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),

          if (event.categories.isEmpty)
            const Text(
              'No categories yet. Payments during this event need one before '
              'they can be filed.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            )
          else
            for (final category in event.categories)
              _CategoryRow(category: category),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final EventCategory category;

  const _CategoryRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final store = context.read<EventStore>();
    final usage = category.usage;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.componentBase,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                usage == null ? '—' : '${(usage * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.componentBase,
                icon: const Icon(Icons.more_vert,
                    size: 18, color: AppColors.secondaryText),
                onSelected: (value) async {
                  if (value == 'edit') {
                    final updated = await showEventCategoryDialog(
                      context,
                      existing: category,
                    );
                    if (updated == null) return;
                    await store.updateCategory(
                      category.copyWith(
                        name: updated.name,
                        budget: updated.budget,
                      ),
                    );
                  } else if (value == 'delete') {
                    await store.deleteCategory(category.id!);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (category.budget > 0) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (usage ?? 0).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.mainBackground,
                valueColor: AlwaysStoppedAnimation(
                  category.isOverBudget ? Colors.redAccent : AppColors.accent,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${formatMoney(category.spent)} spent',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (category.isOverBudget)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.redAccent),
                    SizedBox(width: 4),
                    Text(
                      'Over budget',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  category.budget > 0
                      ? 'of ${formatMoney(category.budget)}'
                      : 'no budget',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Payments the event captured that still need a line item.
class _PendingSection extends StatelessWidget {
  final BudgetEvent event;

  const _PendingSection({required this.event});

  @override
  Widget build(BuildContext context) {
    final store = context.read<EventStore>();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: store.queueFor(event.id!),
      builder: (context, snapshot) {
        final queue = snapshot.data ?? const [];
        if (queue.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${queue.length} payment${queue.length == 1 ? '' : 's'} to file',
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Captured during the event. Pick the category each belongs to.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (final row in queue)
                _QueueRow(row: row, categories: event.categories),
            ],
          ),
        );
      },
    );
  }
}

class _QueueRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final List<EventCategory> categories;

  const _QueueRow({required this.row, required this.categories});

  @override
  Widget build(BuildContext context) {
    final store = context.read<EventStore>();
    final amount = (row['amount'] as num? ?? 0).toDouble();
    final date = DateTime.fromMillisecondsSinceEpoch(row['date'] as int);
    final payee = (row['name'] as String?)?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.componentBase,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payee?.isNotEmpty == true ? payee! : 'Payment',
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                formatMoney(amount),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            formatMoment(date),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          if (categories.isEmpty)
            const Text(
              'Add a category above before this can be filed.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in categories)
                  ActionChip(
                    backgroundColor: AppColors.mainBackground,
                    side: BorderSide(
                      color: AppColors.secondaryText.withValues(alpha: 0.3),
                    ),
                    label: Text(
                      category.name,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () => store.fileTransaction(
                      transactionId: row['id'] as int,
                      eventCategoryId: category.id!,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
