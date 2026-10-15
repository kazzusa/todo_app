import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/nlp_parser.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? existingTask;
  final String? initialCategory;
  const AddTaskScreen({super.key, this.existingTask, this.initialCategory});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  late final TextEditingController _controller;
  ParsedTask? _parsed;
  bool _showFields = false;
  bool _categoryOverridden = false;

  // Editable parsed fields
  late String _title;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  RecurrenceType _recurrence = RecurrenceType.none;
  int? _recurrenceWeekday;
  String? _category;

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    if (task != null) {
      _controller = TextEditingController(text: task.title);
      _title = task.title;
      _dueDate = task.dueDateTime != null
          ? DateTime(
              task.dueDateTime!.year,
              task.dueDateTime!.month,
              task.dueDateTime!.day,
            )
          : null;
      _dueTime = task.dueTimeOfDay;
      _recurrence = task.recurrence;
      _recurrenceWeekday = task.recurrenceWeekday;
      _category = task.category;
      _showFields = true;
    } else {
      _controller = TextEditingController();
      _title = '';
      _category = widget.initialCategory;
    }
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.isEmpty) {
      setState(() {
        _parsed = null;
        _showFields = false;
      });
      return;
    }
    final p = NlpParser.parse(text);
    setState(() {
      _parsed = p;
      _title = p.title.isNotEmpty ? p.title : (p.category == null ? text : '');
      _dueDate = p.dueDate;
      _dueTime = p.dueTime;
      _recurrence = p.recurrence;
      _recurrenceWeekday = p.recurrenceWeekday;
      if (p.category != null) {
        _category = p.category;
      } else if (!_categoryOverridden) {
        _category = widget.initialCategory;
      }
      _showFields = true;
    });
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (result != null) setState(() => _dueDate = result);
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (result != null) setState(() => _dueTime = result);
  }

  Future<void> _pickCategory() async {
    final categories = context.read<TaskProvider>().customCategories;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _CategoryPicker(categories: categories, selected: _category),
    );
    if (selected != null) {
      setState(() {
        _category = selected == '__none__' ? null : selected;
        _categoryOverridden = true;
      });
    }
  }

  Future<void> _save() async {
    final title = _title.trim();
    if (title.isEmpty) return;

    DateTime? dueDateTime;
    bool hasDueTime = false;
    if (_dueDate != null) {
      if (_dueTime != null) {
        dueDateTime = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          _dueTime!.hour,
          _dueTime!.minute,
        );
        hasDueTime = true;
      } else {
        dueDateTime = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
      }
    }

    final provider = context.read<TaskProvider>();
    if (widget.existingTask != null) {
      await provider.updateTask(
        widget.existingTask!.copyWith(
          title: title,
          dueDateTime: dueDateTime,
          hasDueTime: hasDueTime,
          recurrence: _recurrence,
          recurrenceWeekday: _recurrenceWeekday,
          category: _category,
          clearDueDateTime: dueDateTime == null,
          clearRecurrenceWeekday: _recurrenceWeekday == null,
          clearCategory: _category == null,
        ),
      );
    } else {
      await provider.addTask(
        Task(
          id: '',
          title: title,
          dueDateTime: dueDateTime,
          hasDueTime: hasDueTime,
          recurrence: _recurrence,
          recurrenceWeekday: _recurrenceWeekday,
          category: _category,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.existingTask == null) return;
    await context.read<TaskProvider>().deleteTask(widget.existingTask!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingTask != null;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        // `padding.bottom` (not `viewPadding.bottom`) so this doesn't add
        // safe-area clearance on top of the keyboard when both are present —
        // padding already shrinks to ~0 once the keyboard exceeds the system
        // bar inset, avoiding an overflow that clips the buttons off-screen.
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              isEditing ? 'Edit Task' : 'New Task',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            // NLP input
            TextField(
              controller: _controller,
              autofocus: !isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. "Submit report tomorrow at 5pm"',
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _controller.clear(),
                      )
                    : null,
              ),
            ),

            // Parse preview
            if (_parsed != null && !isEditing && _controller.text.isNotEmpty)
              _ParsePreview(parsed: _parsed!),

            // Editable fields
            if (_showFields) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ChipButton(
                      icon: Icons.calendar_today_outlined,
                      label: _dueDate != null
                          ? DateFormat('MMM d').format(_dueDate!)
                          : 'Date',
                      active: _dueDate != null,
                      onTap: _pickDate,
                      onClear: _dueDate != null
                          ? () => setState(() {
                              _dueDate = null;
                              _dueTime = null;
                            })
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChipButton(
                      icon: Icons.schedule,
                      label: _dueTime != null
                          ? _dueTime!.format(context)
                          : 'Time',
                      active: _dueTime != null,
                      enabled: _dueDate != null,
                      onTap: _dueDate != null ? _pickTime : null,
                      onClear: _dueTime != null
                          ? () => setState(() => _dueTime = null)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChipButton(
                      icon: Icons.folder_outlined,
                      label: _category != null
                          ? (_category![0].toUpperCase() +
                                _category!.substring(1))
                          : 'Category',
                      active: _category != null,
                      onTap: _pickCategory,
                      onClear: _category != null
                          ? () => setState(() {
                              _category = null;
                              _categoryOverridden = true;
                            })
                          : null,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (isEditing) ...[
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: _delete,
                  ),
                  const Spacer(),
                ],
                if (!isEditing) const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _title.trim().isNotEmpty ? _save : null,
                  child: Text(isEditing ? 'Save' : 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ParsePreview extends StatelessWidget {
  final ParsedTask parsed;
  const _ParsePreview({required this.parsed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];
    if (parsed.dueDate != null) {
      parts.add(DateFormat('EEE, MMM d').format(parsed.dueDate!));
    }
    if (parsed.dueTime != null) {
      parts.add(parsed.dueTime!.format(context));
    }
    if (parsed.recurrence != RecurrenceType.none) {
      parts.add(_recurrenceLabel(parsed.recurrence, parsed.recurrenceWeekday));
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _recurrenceLabel(RecurrenceType r, int? weekday) {
    switch (r) {
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.weekday:
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final idx = (weekday ?? 1) - 1;
        return 'Every ${days[idx]}';
      case RecurrenceType.none:
        return '';
    }
  }
}

class _ChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _ChipButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.enabled = true,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final color = active ? accent : theme.colorScheme.onSurface.withAlpha(120);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? accent.withAlpha(30)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: active ? Border.all(color: accent.withAlpha(80)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 12, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final List<String> categories;
  final String? selected;

  const _CategoryPicker({required this.categories, required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Category', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          // None option
          _CategoryTile(
            label: 'None',
            isSelected: selected == null,
            onTap: () => Navigator.of(context).pop('__none__'),
          ),
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'No categories yet.\nCreate one with the + tab on the home screen.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            ...categories.map(
              (cat) => _CategoryTile(
                label: cat[0].toUpperCase() + cat.substring(1),
                isSelected: selected == cat,
                onTap: () => Navigator.of(context).pop(cat),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        Icons.folder_outlined,
        size: 18,
        color: isSelected
            ? theme.colorScheme.primary
            : theme.textTheme.bodySmall!.color,
      ),
      title: Text(
        label,
        style: isSelected ? TextStyle(color: theme.colorScheme.primary) : null,
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.primary, size: 18)
          : null,
      onTap: onTap,
      dense: true,
    );
  }
}
