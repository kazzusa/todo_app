import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/firestore_service.dart';
import '../services/google_calendar_service.dart';
import '../services/notification_service.dart';

class TaskProvider extends ChangeNotifier {
  final _firestoreService = FirestoreService();
  final _calendarService = GoogleCalendarService();

  List<Task> _tasks = [];
  List<String> _customCategories = [];
  List<String> _pinnedCategories = [];
  bool _isLoading = true;
  String? _error;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isGoogleSignedIn => _calendarService.isSignedIn;
  Set<String> get pinnedCategories => _pinnedCategories.toSet();
  bool isPinned(String name) => _pinnedCategories.contains(name.toLowerCase());

  List<String> get customCategories {
    final pinned = _customCategories.where((c) => _pinnedCategories.contains(c)).toList();
    final unpinned = _customCategories.where((c) => !_pinnedCategories.contains(c)).toList();
    return [...pinned, ...unpinned];
  }

  List<Task> get todayTasks => _tasks
      .where((t) => !t.isCompleted && (t.listCategory == 'today' || t.listCategory == 'overdue'))
      .toList()
    ..sort((a, b) => a.effectiveDueDateTime.compareTo(b.effectiveDueDateTime));

  List<Task> get inboxTasks => _tasks.where((t) => !t.isCompleted).toList();

  List<Task> get completedTasks => _tasks.where((t) => t.isCompleted).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Task> tasksForCategory(String category) => _tasks
      .where((t) => !t.isCompleted && t.category == category)
      .toList()
    ..sort((a, b) => a.effectiveDueDateTime.compareTo(b.effectiveDueDateTime));

  List<Task> tasksForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return _tasks.where((t) {
      if (t.dueDateTime == null) return false;
      final taskDay = DateTime(t.dueDateTime!.year, t.dueDateTime!.month, t.dueDateTime!.day);
      return taskDay.isAtSameMomentAs(day);
    }).toList()
      ..sort((a, b) => a.effectiveDueDateTime.compareTo(b.effectiveDueDateTime));
  }

  Set<DateTime> get datesWithTasks => _tasks
      .where((t) => t.dueDateTime != null)
      .map((t) => DateTime(t.dueDateTime!.year, t.dueDateTime!.month, t.dueDateTime!.day))
      .toSet();

  static const _widgetChannel = MethodChannel('com.personal.todo_app/widget');

  void init() {
    _loadPrefs();
    _firestoreService.tasksStream().listen(
      (tasks) {
        _tasks = tasks;
        _isLoading = false;
        _error = null;
        notifyListeners();
        _syncWidget();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
    _calendarService.tryRestoreSession();
  }

  Future<void> _syncWidget() async {
    try {
      final data = jsonEncode(
        _tasks.where((t) => !t.isCompleted).take(20).map((t) => {
          'title': t.title,
          'category': t.category,
        }).toList(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_tasks', data);
      await _widgetChannel.invokeMethod('updateWidget');
    } catch (_) {
      // Widget may not be placed on home screen — safe to ignore
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _customCategories = prefs.getStringList('custom_categories') ?? [];
    _pinnedCategories = prefs.getStringList('pinned_categories') ?? [];
    notifyListeners();
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_categories', _customCategories);
    await prefs.setStringList('pinned_categories', _pinnedCategories);
  }

  Future<void> addCategory(String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty || _customCategories.contains(key)) return;
    _customCategories = [..._customCategories, key];
    await _savePrefs();
    notifyListeners();
  }

  Future<void> removeCategory(String name) async {
    final key = name.toLowerCase();
    _customCategories = _customCategories.where((c) => c != key).toList();
    _pinnedCategories = _pinnedCategories.where((c) => c != key).toList();
    await _savePrefs();
    notifyListeners();
  }

  Future<void> pinCategory(String name) async {
    final key = name.toLowerCase();
    if (_pinnedCategories.contains(key)) return;
    _pinnedCategories = [..._pinnedCategories, key];
    await _savePrefs();
    notifyListeners();
  }

  Future<void> unpinCategory(String name) async {
    final key = name.toLowerCase();
    _pinnedCategories = _pinnedCategories.where((c) => c != key).toList();
    await _savePrefs();
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    try {
      if (task.category != null && !_customCategories.contains(task.category)) {
        await addCategory(task.category!);
      }
      final saved = await _firestoreService.addTask(task);
      await NotificationService.scheduleTaskNotification(saved);
      if (_calendarService.isSignedIn && saved.dueDateTime != null) {
        final eventId = await _calendarService.createEvent(saved);
        if (eventId != null) {
          await _firestoreService.updateTask(saved.copyWith(googleCalendarEventId: eventId));
        }
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      if (task.category != null && !_customCategories.contains(task.category)) {
        await addCategory(task.category!);
      }
      await _firestoreService.updateTask(task);
      if (task.isCompleted) {
        await NotificationService.cancelTaskNotification(task.id);
      } else {
        await NotificationService.scheduleTaskNotification(task);
      }
      if (_calendarService.isSignedIn) {
        if (task.googleCalendarEventId != null) {
          if (task.isCompleted) {
            await _calendarService.deleteEvent(task.googleCalendarEventId!);
            await _firestoreService.updateTask(task.copyWith(clearGoogleEventId: true));
          } else {
            await _calendarService.updateEvent(task);
          }
        } else if (!task.isCompleted && task.dueDateTime != null) {
          final eventId = await _calendarService.createEvent(task);
          if (eventId != null) {
            await _firestoreService.updateTask(task.copyWith(googleCalendarEventId: eventId));
          }
        }
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteTask(Task task) async {
    try {
      await _firestoreService.deleteTask(task.id);
      await NotificationService.cancelTaskNotification(task.id);
      if (_calendarService.isSignedIn && task.googleCalendarEventId != null) {
        await _calendarService.deleteEvent(task.googleCalendarEventId!);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteTasks(List<Task> tasks) async {
    if (tasks.isEmpty) return;
    try {
      await _firestoreService.deleteTasks(tasks.map((t) => t.id).toList());
      await Future.wait(
          tasks.map((t) => NotificationService.cancelTaskNotification(t.id)));
      if (_calendarService.isSignedIn) {
        await Future.wait(tasks
            .where((t) => t.googleCalendarEventId != null)
            .map((t) => _calendarService.deleteEvent(t.googleCalendarEventId!)));
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleComplete(Task task) async {
    await updateTask(task.copyWith(isCompleted: !task.isCompleted));
  }

  Future<bool> signInGoogle() async {
    final success = await _calendarService.signIn();
    notifyListeners();
    return success;
  }

  Future<void> signOutGoogle() async {
    await _calendarService.signOut();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
