import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';
import 'add_task_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        final selectedTasks = provider.tasksForDate(_selected);

        return Scaffold(
          appBar: AppBar(
            title: Text(DateFormat('MMMM yyyy').format(_focused)),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddTaskScreen(),
            ),
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime(2030),
                focusedDay: _focused,
                selectedDayPredicate: (d) => isSameDay(d, _selected),
                onDaySelected: (selected, focused) => setState(() {
                  _selected = selected;
                  _focused = focused;
                }),
                onPageChanged: (focused) => setState(() => _focused = focused),
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                calendarStyle: CalendarStyle(
                  defaultTextStyle: const TextStyle(color: Colors.white),
                  weekendTextStyle: TextStyle(color: theme.colorScheme.secondary),
                  selectedTextStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  todayTextStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold),
                  selectedDecoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  outsideDaysVisible: false,
                  markerDecoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  leftChevronIcon:
                      Icon(Icons.chevron_left, color: theme.colorScheme.onSurface),
                  rightChevronIcon:
                      Icon(Icons.chevron_right, color: theme.colorScheme.onSurface),
                  headerPadding: const EdgeInsets.symmetric(vertical: 4),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withAlpha(140),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  weekendStyle: TextStyle(
                    color: theme.colorScheme.secondary.withAlpha(180),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                rowHeight: 48,
                eventLoader: (day) {
                  final d = DateTime(day.year, day.month, day.day);
                  return provider.tasksForDate(d);
                },
              ),
              Divider(height: 1, color: theme.dividerColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_dayLabel(_selected),
                      style: theme.textTheme.bodySmall),
                ),
              ),
              Expanded(
                child: selectedTasks.isEmpty
                    ? Center(
                        child: Text('No tasks',
                            style: theme.textTheme.bodyMedium))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: selectedTasks.length,
                        itemBuilder: (_, i) =>
                            TaskCard(task: selectedTasks[i], showCategory: true),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(d.year, d.month, d.day);
    if (sel.isAtSameMomentAs(today)) return 'Today';
    if (sel.isAtSameMomentAs(today.add(const Duration(days: 1)))) return 'Tomorrow';
    return DateFormat('EEEE, MMMM d').format(d);
  }
}
