import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../screens/add_task_screen.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final bool showCategory;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<Task>? onLongPress;
  final ValueChanged<Task>? onTapSelect;

  const TaskCard({
    super.key,
    required this.task,
    this.showCategory = false,
    this.selectionMode = false,
    this.selected = false,
    this.onLongPress,
    this.onTapSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = task.listCategory == 'overdue';

    final card = Card(
      color: selected ? theme.colorScheme.primary.withAlpha(30) : null,
      child: InkWell(
        onTap: selectionMode
            ? () => onTapSelect?.call(task)
            : () => _openEdit(context),
        onLongPress: () => onLongPress?.call(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withAlpha(100),
                  ),
                )
              else ...[
                _CheckCircle(task: task),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? theme.colorScheme.onSurface.withAlpha(100)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (task.dueDateTime != null) ...[
                      const SizedBox(height: 3),
                      _MetaRow(task: task, isOverdue: isOverdue, showCategory: showCategory),
                    ],
                  ],
                ),
              ),
              if (task.recurrence != RecurrenceType.none)
                Icon(Icons.repeat, size: 14,
                    color: theme.colorScheme.secondary.withAlpha(180)),
            ],
          ),
        ),
      ),
    );

    if (selectionMode) return card;

    return Dismissible(
      key: ValueKey(task.id),
      background: _buildSwipeBackground(context, isLeft: true),
      secondaryBackground: _buildSwipeBackground(context, isLeft: false),
      onDismissed: (direction) {
        final provider = context.read<TaskProvider>();
        if (direction == DismissDirection.startToEnd) {
          provider.toggleComplete(task);
        } else {
          provider.deleteTask(task);
        }
      },
      child: card,
    );
  }

  Widget _buildSwipeBackground(BuildContext context, {required bool isLeft}) {
    final color = isLeft
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    final icon = isLeft ? Icons.check : Icons.delete_outline;
    final alignment = isLeft ? Alignment.centerLeft : Alignment.centerRight;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: color),
    );
  }

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskScreen(existingTask: task),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  final Task task;
  const _CheckCircle({required this.task});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<TaskProvider>().toggleComplete(task),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: task.isCompleted
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          border: Border.all(
            color: task.isCompleted
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFF6B6B8A),
            width: 1.5,
          ),
        ),
        child: task.isCompleted
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final Task task;
  final bool isOverdue;
  final bool showCategory;
  const _MetaRow({required this.task, required this.isOverdue, this.showCategory = false});

  @override
  Widget build(BuildContext context) {
    final dt = task.dueDateTime!;
    final color = isOverdue
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).textTheme.bodySmall!.color!;

    String dateStr;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDay = DateTime(dt.year, dt.month, dt.day);

    if (taskDay.isAtSameMomentAs(today)) {
      dateStr = 'Today';
    } else if (taskDay.isAtSameMomentAs(tomorrow)) {
      dateStr = 'Tomorrow';
    } else if (isOverdue) {
      dateStr = DateFormat('MMM d').format(dt);
    } else {
      dateStr = DateFormat('EEE, MMM d').format(dt);
    }

    final timeStr =
        task.hasDueTime ? DateFormat('h:mm a').format(dt) : null;

    return Row(
      children: [
        Icon(Icons.schedule, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          timeStr != null ? '$dateStr · $timeStr' : dateStr,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
        if (showCategory && task.category != null) ...[
          const Spacer(),
          Text(
            task.category![0].toUpperCase() + task.category!.substring(1),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFCC6820),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
