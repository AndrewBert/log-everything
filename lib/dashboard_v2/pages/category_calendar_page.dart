import 'package:flutter/material.dart';
import 'package:myapp/dashboard_v2/widgets/category_calendar_view.dart';
import 'package:myapp/entry/entry.dart';

class CategoryCalendarPage extends StatefulWidget {
  final String categoryName;
  final List<Entry> entries;
  final Color categoryColor;

  const CategoryCalendarPage({
    super.key,
    required this.categoryName,
    required this.entries,
    required this.categoryColor,
  });

  @override
  State<CategoryCalendarPage> createState() => _CategoryCalendarPageState();
}

class _CategoryCalendarPageState extends State<CategoryCalendarPage> {
  final _calendarKey = GlobalKey<CategoryCalendarViewState>();
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime.now();
  }

  bool get _isViewingCurrentMonth {
    final now = DateTime.now();
    return _focusedMonth.year == now.year && _focusedMonth.month == now.month;
  }

  List<Entry> get _entriesThisMonth {
    return widget.entries.where((entry) {
      return entry.timestamp.year == _focusedMonth.year &&
          entry.timestamp.month == _focusedMonth.month;
    }).toList();
  }

  int get _daysWithEntries {
    final days = <String>{};
    for (final entry in _entriesThisMonth) {
      days.add('${entry.timestamp.year}-${entry.timestamp.month}-${entry.timestamp.day}');
    }
    return days.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entriesCount = _entriesThisMonth.length;
    final daysCount = _daysWithEntries;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName} Calendar'),
        centerTitle: true,
        actions: [
          if (!_isViewingCurrentMonth)
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: () => _calendarKey.currentState?.goToToday(),
              tooltip: 'Go to today',
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 3,
            color: widget.categoryColor.withValues(alpha: 0.6),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CategoryCalendarView(
                    key: _calendarKey,
                    entries: widget.entries,
                    categoryColor: widget.categoryColor,
                    onMonthChanged: (month) {
                      setState(() {
                        _focusedMonth = month;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // Stats section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'THIS MONTH',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                value: '$entriesCount',
                                label: entriesCount == 1 ? 'Entry' : 'Entries',
                                color: widget.categoryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                value: '$daysCount',
                                label: daysCount == 1 ? 'Day Active' : 'Days Active',
                                color: widget.categoryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
