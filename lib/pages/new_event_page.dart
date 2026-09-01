import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/budget_event.dart';
import '../state/event_store.dart';
import '../theme/app_colors.dart';
import 'events_page.dart' show formatMoment, formatDuration, formatMoney;

/// Set up an event: what it is, when it runs, and what you are budgeting for.
///
/// The end is a full timestamp rather than "the rest of the day" — most events
/// run for a few hours, and a window that swallows the whole day would count
/// unrelated spending.
class NewEventPage extends StatefulWidget {
  const NewEventPage({super.key});

  @override
  State<NewEventPage> createState() => _NewEventPageState();
}

class _NewEventPageState extends State<NewEventPage> {
  final _nameController = TextEditingController();

  late DateTime _startsAt;
  late DateTime _endsAt;

  final List<EventCategory> _categories = [];
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default to the next whole hour for six hours — a plausible event, and
    // short enough that nobody leaves it at "all day" by accident.
    _startsAt = DateTime(now.year, now.month, now.day, now.hour + 1);
    _endsAt = _startsAt.add(const Duration(hours: 6));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickMoment({required bool isStart}) async {
    final initial = isStart ? _startsAt : _endsAt;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    setState(() {
      _error = null;
      if (isStart) {
        // Keep the length the user already chose rather than silently
        // producing a backwards window.
        final length = _endsAt.difference(_startsAt);
        _startsAt = picked;
        _endsAt = picked.add(length.isNegative ? const Duration(hours: 6) : length);
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _addCategory() async {
    final result = await showDialog<EventCategory>(
      context: context,
      builder: (_) => const _CategoryDialog(),
    );
    if (result == null) return;
    setState(() {
      _categories.add(result);
      _error = null;
    });
  }

  Future<void> _save() async {
    final store = context.read<EventStore>();
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Give the event a name.');
      return;
    }
    if (_categories.isEmpty) {
      setState(() => _error =
          'Add at least one category — payments during the event need '
          'somewhere to go.');
      return;
    }

    final problem = await store.validateWindow(_startsAt, _endsAt);
    if (problem != null) {
      if (mounted) setState(() => _error = problem);
      return;
    }

    setState(() => _saving = true);
    await store.createEvent(BudgetEvent(
      name: name,
      startsAt: _startsAt,
      endsAt: _endsAt,
      createdAt: DateTime.now(),
      categories: _categories,
    ));

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final budget = _categories.fold<double>(0, (sum, c) => sum + c.budget);
    final length = _endsAt.difference(_startsAt);

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: AppColors.mainBackground,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        title: const Text('New event'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.primaryText),
            decoration: InputDecoration(
              labelText: 'What is it?',
              hintText: 'Wanjiru wedding, Mombasa trip…',
              labelStyle: const TextStyle(color: AppColors.secondaryText),
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.componentBase,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 20),
          const _SectionLabel('When does it run?'),
          _MomentRow(
            label: 'Starts',
            moment: _startsAt,
            onTap: () => _pickMoment(isStart: true),
          ),
          const SizedBox(height: 8),
          _MomentRow(
            label: 'Ends',
            moment: _endsAt,
            onTap: () => _pickMoment(isStart: false),
          ),
          const SizedBox(height: 8),
          Text(
            length.isNegative
                ? 'The end is before the start.'
                : 'Runs ${formatDuration(length)}. Every M-Pesa payment in that '
                    'window counts towards this event.',
            style: TextStyle(
              color: length.isNegative
                  ? Colors.redAccent
                  : AppColors.secondaryText,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: _SectionLabel('What are you budgeting for?')),
              TextButton.icon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),

          if (_categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Catering, transport, decor — the line items for this event '
                'only. They do not touch your normal categories.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
            )
          else
            for (int i = 0; i < _categories.length; i++)
              _DraftCategoryRow(
                category: _categories[i],
                onRemove: () => setState(() => _categories.removeAt(i)),
              ),

          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Total budget ${formatMoney(budget)}',
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Start event'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryText,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MomentRow extends StatelessWidget {
  final String label;
  final DateTime moment;
  final VoidCallback onTap;

  const _MomentRow({
    required this.label,
    required this.moment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.componentBase,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                formatMoment(moment),
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit_calendar_outlined,
                  color: AppColors.secondaryText, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftCategoryRow extends StatelessWidget {
  final EventCategory category;
  final VoidCallback onRemove;

  const _DraftCategoryRow({required this.category, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.componentBase,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            category.budget > 0 ? formatMoney(category.budget) : 'No budget',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.secondaryText,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

/// Name + amount for one line item.
class _CategoryDialog extends StatefulWidget {
  final EventCategory? existing;
  const _CategoryDialog({this.existing});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _budget = TextEditingController(
    text: (widget.existing?.budget ?? 0) > 0
        ? widget.existing!.budget.toStringAsFixed(0)
        : '',
  );

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.mainBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.existing == null ? 'Add a category' : 'Edit category',
        style: const TextStyle(color: AppColors.primaryText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            style: const TextStyle(color: AppColors.primaryText),
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Catering, transport, decor…',
              labelStyle: TextStyle(color: AppColors.secondaryText),
              hintStyle: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.primaryText),
            decoration: const InputDecoration(
              labelText: 'Budget (optional)',
              prefixText: 'Ksh ',
              labelStyle: TextStyle(color: AppColors.secondaryText),
              prefixStyle: TextStyle(color: AppColors.secondaryText),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              EventCategory(
                id: widget.existing?.id,
                // Filled in once the event row exists; a draft has no event yet.
                eventId: widget.existing?.eventId ?? 0,
                name: name,
                budget: double.tryParse(_budget.text.trim()) ?? 0,
              ),
            );
          },
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

/// Reused by the detail page so adding a line item later looks the same.
Future<EventCategory?> showEventCategoryDialog(
  BuildContext context, {
  EventCategory? existing,
}) {
  return showDialog<EventCategory>(
    context: context,
    builder: (_) => _CategoryDialog(existing: existing),
  );
}
