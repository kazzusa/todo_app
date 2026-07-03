import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/task_card.dart';
import 'add_task_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedTab = 'inbox';
  final Set<String> _selectedIds = {};

  bool get _selectionMode => _selectedIds.isNotEmpty;

  void _startSelection(Task task) => setState(() => _selectedIds.add(task.id));

  void _toggleSelected(Task task) => setState(() {
        if (!_selectedIds.remove(task.id)) _selectedIds.add(task.id);
      });

  void _clearSelection() => setState(_selectedIds.clear);

  void _selectAll(List<Task> visibleTasks) => setState(() {
        _selectedIds
          ..clear()
          ..addAll(visibleTasks.map((t) => t.id));
      });

  Future<void> _deleteSelected(TaskProvider provider) async {
    final toDelete =
        provider.tasks.where((t) => _selectedIds.contains(t.id)).toList();
    if (toDelete.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${toDelete.length} '
            'task${toDelete.length == 1 ? '' : 's'}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _clearSelection();
    await provider.deleteTasks(toDelete);
  }

  List<Task> _visibleTasks(TaskProvider provider) {
    switch (_selectedTab) {
      case 'inbox':
        return provider.inboxTasks;
      case 'today':
        return provider.todayTasks;
      case 'done':
        return provider.completedTasks;
      default:
        return provider.tasksForCategory(_selectedTab);
    }
  }

  bool get _isCustomTab =>
      _selectedTab != 'inbox' &&
      _selectedTab != 'today' &&
      _selectedTab != 'upcoming' &&
      _selectedTab != 'done';

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskScreen(
        initialCategory: _isCustomTab ? _selectedTab : null,
      ),
    );
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Category name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty && mounted) {
      await context.read<TaskProvider>().addCategory(name.trim());
      setState(() => _selectedTab = name.trim().toLowerCase());
    }
  }

  Future<void> _onCategoryLongPress(String name) async {
    final provider = context.read<TaskProvider>();
    final pinned = provider.isPinned(name);
    final theme = Theme.of(context);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: theme.colorScheme.primary,
              ),
              title: Text(pinned ? 'Unpin' : 'Pin to top'),
              onTap: () => Navigator.of(ctx).pop('pin'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text(
                'Delete "${name[0].toUpperCase()}${name.substring(1)}"',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'pin') {
      if (pinned) {
        await context.read<TaskProvider>().unpinCategory(name);
      } else {
        await context.read<TaskProvider>().pinCategory(name);
      }
    } else if (action == 'delete') {
      await _deleteCategory(name);
    }
  }

  Future<void> _deleteCategory(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${name[0].toUpperCase()}${name.substring(1)}"?'),
        content: const Text('Tasks in this category will move to Inbox.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<TaskProvider>().removeCategory(name);
      setState(() => _selectedTab = 'inbox');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (provider.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(provider.error!)),
            );
            provider.clearError();
          });
        }

        final visibleTasks = _visibleTasks(provider);

        return PopScope(
          canPop: !_selectionMode,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _clearSelection();
          },
          child: Scaffold(
            appBar: _selectionMode
                ? AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearSelection,
                    ),
                    title: Text('${_selectedIds.length} selected'),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.select_all),
                        tooltip: 'Select all',
                        onPressed: () => _selectAll(visibleTasks),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete selected',
                        onPressed: () => _deleteSelected(provider),
                      ),
                    ],
                  )
                : AppBar(
                    title: const Text('ToDo'),
                    actions: [_GoogleButton()],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(44),
                      child: _TabBar(
                        selected: _selectedTab,
                        customCategories: provider.customCategories,
                        pinnedCategories: provider.pinnedCategories,
                        onSelect: (tab) => setState(() => _selectedTab = tab),
                        onAdd: _addCategory,
                        onCategoryLongPress: _onCategoryLongPress,
                      ),
                    ),
                  ),
            body: _buildContent(provider),
            floatingActionButton: _selectionMode
                ? null
                : FloatingActionButton(
                    onPressed: _openAdd,
                    child: const Icon(Icons.add),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildContent(TaskProvider provider) {
    switch (_selectedTab) {
      case 'inbox':
        return _GroupedTaskList(
          tasks: provider.inboxTasks,
          categoryOrder: provider.customCategories,
          selectedIds: _selectedIds,
          onLongPress: _startSelection,
          onTapSelect: _toggleSelected,
        );
      case 'today':
        return _TaskList(
          tasks: provider.todayTasks,
          emptyLabel: 'Nothing due today',
          selectedIds: _selectedIds,
          onLongPress: _startSelection,
          onTapSelect: _toggleSelected,
        );
      case 'done':
        return _TaskList(
          tasks: provider.completedTasks,
          emptyLabel: 'No completed tasks',
          selectedIds: _selectedIds,
          onLongPress: _startSelection,
          onTapSelect: _toggleSelected,
        );
      default:
        return _TaskList(
          tasks: provider.tasksForCategory(_selectedTab),
          emptyLabel: 'No tasks in "$_selectedTab"\nType "/$_selectedTab" to add one',
          selectedIds: _selectedIds,
          onLongPress: _startSelection,
          onTapSelect: _toggleSelected,
        );
    }
  }
}

class _TabBar extends StatelessWidget {
  final String selected;
  final List<String> customCategories;
  final Set<String> pinnedCategories;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<String> onCategoryLongPress;

  const _TabBar({
    required this.selected,
    required this.customCategories,
    required this.pinnedCategories,
    required this.onSelect,
    required this.onAdd,
    required this.onCategoryLongPress,
  });

  @override
  Widget build(BuildContext context) {
    const fixed = [
      ('inbox', 'Inbox'),
      ('today', 'Today'),
      ('done', 'Done'),
    ];

    final pinned = customCategories.where((c) => pinnedCategories.contains(c)).toList();
    final unpinned = customCategories.where((c) => !pinnedCategories.contains(c)).toList();

    _Tab catTab(String cat, {bool isPinned = false}) => _Tab(
          label: cat[0].toUpperCase() + cat.substring(1),
          selected: selected == cat,
          isPinned: isPinned,
          onTap: () => onSelect(cat),
          onLongPress: () => onCategoryLongPress(cat),
        );

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          // Pinned custom categories appear first (leftmost)
          ...pinned.map((cat) => catTab(cat, isPinned: true)),
          // Fixed system tabs
          ...fixed.map((t) => _Tab(
                label: t.$2,
                selected: selected == t.$1,
                onTap: () => onSelect(t.$1),
              )),
          // Unpinned custom categories after fixed tabs
          ...unpinned.map((cat) => catTab(cat)),
          // "+" button
          GestureDetector(
            onTap: onAdd,
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primary.withAlpha(80),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add, size: 16, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _Tab({
    required this.label,
    required this.selected,
    this.isPinned = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primary : const Color(0xFF2E2E2E),
            width: selected ? 1.2 : 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPinned)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.push_pin, size: 9, color: AppTheme.primary),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppTheme.primary : const Color(0xFF888888),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final String emptyLabel;
  final Set<String> selectedIds;
  final ValueChanged<Task> onLongPress;
  final ValueChanged<Task> onTapSelect;

  const _TaskList({
    required this.tasks,
    required this.emptyLabel,
    required this.selectedIds,
    required this.onLongPress,
    required this.onTapSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 44, color: AppTheme.primary.withAlpha(60)),
            const SizedBox(height: 12),
            Text(
              emptyLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: tasks.length,
      itemBuilder: (_, i) => TaskCard(
        key: ValueKey(tasks[i].id),
        task: tasks[i],
        selectionMode: selectedIds.isNotEmpty,
        selected: selectedIds.contains(tasks[i].id),
        onLongPress: onLongPress,
        onTapSelect: onTapSelect,
      ),
    );
  }
}

class _GroupedTaskList extends StatelessWidget {
  final List<Task> tasks;
  final List<String> categoryOrder;
  final Set<String> selectedIds;
  final ValueChanged<Task> onLongPress;
  final ValueChanged<Task> onTapSelect;

  const _GroupedTaskList({
    required this.tasks,
    required this.categoryOrder,
    required this.selectedIds,
    required this.onLongPress,
    required this.onTapSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 44, color: AppTheme.primary.withAlpha(60)),
            const SizedBox(height: 12),
            Text('All done!',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    final uncategorized = tasks
        .where((t) => t.category == null)
        .toList()
      ..sort((a, b) => a.effectiveDueDateTime.compareTo(b.effectiveDueDateTime));

    final byCategory = <String, List<Task>>{};
    for (final task in tasks) {
      if (task.category != null) {
        (byCategory[task.category!] ??= []).add(task);
      }
    }
    for (final list in byCategory.values) {
      list.sort((a, b) => a.effectiveDueDateTime.compareTo(b.effectiveDueDateTime));
    }

    final orderedKeys = [
      ...categoryOrder.where((c) => byCategory.containsKey(c)),
      ...byCategory.keys.where((c) => !categoryOrder.contains(c)),
    ];

    Widget card(Task task) => TaskCard(
          key: ValueKey(task.id),
          task: task,
          selectionMode: selectedIds.isNotEmpty,
          selected: selectedIds.contains(task.id),
          onLongPress: onLongPress,
          onTapSelect: onTapSelect,
        );

    final items = <Widget>[
      for (final task in uncategorized) card(task),
      for (final cat in orderedKeys) ...[
        _SectionHeader(title: cat),
        for (final task in byCategory[cat]!) card(task),
      ],
    ];

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      children: items,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title[0].toUpperCase() + title.substring(1),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, _) => IconButton(
        icon: Icon(
          provider.isGoogleSignedIn ? Icons.sync : Icons.sync_disabled,
          color: provider.isGoogleSignedIn
              ? AppTheme.primary
              : const Color(0xFF6B6B6B),
        ),
        tooltip: provider.isGoogleSignedIn
            ? 'Google Calendar synced'
            : 'Connect Google Calendar',
        onPressed: () async {
          if (provider.isGoogleSignedIn) {
            await provider.signOutGoogle();
          } else {
            final ok = await provider.signInGoogle();
            if (context.mounted && !ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Google sign-in failed')),
              );
            }
          }
        },
      ),
    );
  }
}

