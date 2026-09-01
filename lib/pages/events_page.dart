import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/budget_event.dart';
import '../state/event_store.dart';
import '../theme/app_colors.dart';
import 'event_detail_page.dart';
import 'new_event_page.dart';

String formatMoney(double amount) => 'Ksh ${amount.toStringAsFixed(0)}';

/// "Sat 12 Sep, 2:00 PM" — the time matters as much as the date, because an
/// event owns a window rather than a whole day.
String formatMoment(DateTime moment) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour24 = moment.hour;
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = moment.minute.toString().padLeft(2, '0');
  final suffix = hour24 < 12 ? 'AM' : 'PM';
  return '${days[moment.weekday - 1]} ${moment.day} ${months[moment.month - 1]}, '
      '$hour:$minute $suffix';
}

String formatWindow(BudgetEvent event) {
  final sameDay = event.startsAt.year == event.endsAt.year &&
      event.startsAt.month == event.endsAt.month &&
      event.startsAt.day == event.endsAt.day;

  if (!sameDay) {
    return '${formatMoment(event.startsAt)}  →  ${formatMoment(event.endsAt)}';
  }

  // Within one day, repeating the date on both sides is noise.
  final end = formatMoment(event.endsAt).split(', ').last;
  return '${formatMoment(event.startsAt)} – $end';
}

String formatDuration(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) {
    final minutes = d.inMinutes % 60;
    return minutes == 0 ? '${d.inHours} hr' : '${d.inHours} hr ${minutes} min';
  }
  final hours = d.inHours % 24;
  return hours == 0 ? '${d.inDays} days' : '${d.inDays} d ${hours} hr';
}

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EventStore>();

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        // The header sits outside the scroll view so the action stays reachable
        // whether or not there are events yet.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            Expanded(
              child: store.loading
                  ? const Center(child: CircularProgressIndicator())
                  : store.events.isEmpty
                      ? const _EmptyState()
                      : ListView(
                          // The shell draws its nav bar over the page
                          // (extendBody), so the last card needs room to clear it.
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                          children: [
                            for (final event in store.events)
                              _EventCard(
                                event: event,
                                pending: store.queueCountFor(event.id),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Events',
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Top right rather than a floating button: the shell's nav bar floats
          // over the bottom of every page and was covering it.
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewEventPage()),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration_outlined,
                color: AppColors.secondaryText, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No events yet',
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap New to set one up: when it runs, and what you are budgeting '
              'for.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final BudgetEvent event;
  final int pending;

  const _EventCard({required this.event, required this.pending});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = event.isActiveAt(now);
    final ended = event.hasEndedBy(now);
    final usage = event.usage;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.componentBase,
        borderRadius: BorderRadius.circular(16),
        border: active
            ? Border.all(color: AppColors.accent.withValues(alpha: 0.6))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EventDetailPage(eventId: event.id!)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.name,
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _StatusChip(active: active, ended: ended),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  formatWindow(event),
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Runs ${formatDuration(event.duration)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                if (event.budget > 0) ...[
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
                ],
                Row(
                  children: [
                    Text(
                      formatMoney(event.spent),
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      event.budget > 0
                          ? ' of ${formatMoney(event.budget)}'
                          : ' spent · no budget set',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (event.isOverBudget)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 15, color: Colors.redAccent),
                          SizedBox(width: 4),
                          Text(
                            'Over',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (pending > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$pending payment${pending == 1 ? '' : 's'} waiting to be filed',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;
  final bool ended;

  const _StatusChip({required this.active, required this.ended});

  @override
  Widget build(BuildContext context) {
    final label = active ? 'Happening now' : ended ? 'Finished' : 'Upcoming';
    final color = active
        ? AppColors.accent
        : ended
            ? AppColors.textSecondary
            : AppColors.secondaryText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
