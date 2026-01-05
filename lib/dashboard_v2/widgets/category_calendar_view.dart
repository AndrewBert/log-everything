import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:myapp/entry/entry.dart';

class CategoryCalendarView extends StatefulWidget {
  final List<Entry> entries;
  final Color categoryColor;

  const CategoryCalendarView({
    super.key,
    required this.entries,
    required this.categoryColor,
  });

  @override
  State<CategoryCalendarView> createState() => _CategoryCalendarViewState();
}

class _CategoryCalendarViewState extends State<CategoryCalendarView> {
  DateTime _focusedDay = DateTime.now();

  /// Normalize a DateTime to midnight (day only, no time component)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Group entries by their normalized date
  Map<DateTime, List<Entry>> get _entriesByDay {
    final map = <DateTime, List<Entry>>{};
    for (final entry in widget.entries) {
      final day = _normalizeDate(entry.timestamp);
      map.putIfAbsent(day, () => []).add(entry);
    }
    return map;
  }

  /// Get entries for a specific day
  List<Entry> _getEntriesForDay(DateTime day) {
    final normalized = _normalizeDate(day);
    return _entriesByDay[normalized] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TableCalendar<Entry>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      eventLoader: _getEntriesForDay,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Month',
      },
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ) ??
            const TextStyle(fontWeight: FontWeight.w600),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: theme.colorScheme.onSurface,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface,
        ),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        weekendTextStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        defaultTextStyle: TextStyle(
          color: theme.colorScheme.onSurface,
        ),
        todayDecoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
        markerDecoration: BoxDecoration(
          color: widget.categoryColor,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 3,
        markerSize: 6,
        markerMargin: const EdgeInsets.symmetric(horizontal: 1),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return null;
          return _buildDotIndicators(events.length);
        },
      ),
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
      },
      // No day selection - display only
      selectedDayPredicate: (_) => false,
    );
  }

  Widget _buildDotIndicators(int count) {
    final dotCount = count.clamp(1, 3);
    return Positioned(
      bottom: 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          dotCount,
          (_) => Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.categoryColor.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}
