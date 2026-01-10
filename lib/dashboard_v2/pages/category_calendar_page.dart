import 'package:flutter/material.dart';
import 'package:myapp/dashboard_v2/widgets/category_calendar_view.dart';
import 'package:myapp/entry/entry.dart';

class CategoryCalendarPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$categoryName Calendar'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            height: 3,
            color: categoryColor.withValues(alpha: 0.6),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CategoryCalendarView(
                entries: entries,
                categoryColor: categoryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
