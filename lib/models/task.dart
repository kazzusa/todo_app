import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum RecurrenceType { none, daily, weekly, monthly, weekday }

class Task {
  final String id;
  final String title;
  final DateTime? dueDateTime;
  final bool hasDueTime;
  final RecurrenceType recurrence;
  final int? recurrenceWeekday; // DateTime.monday=1 ... DateTime.sunday=7
  final bool isCompleted;
  final bool notified;
  final String? googleCalendarEventId;
  final String? category;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.title,
    this.dueDateTime,
    this.hasDueTime = false,
    this.recurrence = RecurrenceType.none,
    this.recurrenceWeekday,
    this.isCompleted = false,
    this.notified = false,
    this.googleCalendarEventId,
    this.category,
    required this.createdAt,
  });

  String get listCategory {
    if (dueDateTime == null) return 'inbox';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(dueDateTime!.year, dueDateTime!.month, dueDateTime!.day);
    if (taskDay.isBefore(today)) return 'overdue';
    if (taskDay.isAtSameMomentAs(today)) return 'today';
    return 'upcoming';
  }

  TimeOfDay? get dueTimeOfDay {
    if (dueDateTime == null || !hasDueTime) return null;
    return TimeOfDay(hour: dueDateTime!.hour, minute: dueDateTime!.minute);
  }

  DateTime get effectiveDueDateTime {
    if (dueDateTime == null) return DateTime(9999);
    if (!hasDueTime) return DateTime(dueDateTime!.year, dueDateTime!.month, dueDateTime!.day, 23, 59);
    return dueDateTime!;
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'dueDateTime': dueDateTime != null ? Timestamp.fromDate(dueDateTime!) : null,
    'hasDueTime': hasDueTime,
    'recurrence': recurrence.index,
    'recurrenceWeekday': recurrenceWeekday,
    'isCompleted': isCompleted,
    'notified': notified,
    'googleCalendarEventId': googleCalendarEventId,
    'category': category,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory Task.fromMap(String id, Map<String, dynamic> map) => Task(
    id: id,
    title: map['title'] as String? ?? '',
    dueDateTime: (map['dueDateTime'] as Timestamp?)?.toDate(),
    hasDueTime: map['hasDueTime'] as bool? ?? false,
    recurrence: RecurrenceType.values[map['recurrence'] as int? ?? 0],
    recurrenceWeekday: map['recurrenceWeekday'] as int?,
    isCompleted: map['isCompleted'] as bool? ?? false,
    notified: map['notified'] as bool? ?? false,
    googleCalendarEventId: map['googleCalendarEventId'] as String?,
    category: map['category'] as String?,
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  Task copyWith({
    String? id,
    String? title,
    DateTime? dueDateTime,
    bool? hasDueTime,
    RecurrenceType? recurrence,
    int? recurrenceWeekday,
    bool? isCompleted,
    bool? notified,
    String? googleCalendarEventId,
    String? category,
    DateTime? createdAt,
    bool clearDueDateTime = false,
    bool clearGoogleEventId = false,
    bool clearRecurrenceWeekday = false,
    bool clearCategory = false,
  }) =>
      Task(
        id: id ?? this.id,
        title: title ?? this.title,
        dueDateTime:
            clearDueDateTime ? null : (dueDateTime ?? this.dueDateTime),
        hasDueTime: hasDueTime ?? this.hasDueTime,
        recurrence: recurrence ?? this.recurrence,
        recurrenceWeekday: clearRecurrenceWeekday
            ? null
            : (recurrenceWeekday ?? this.recurrenceWeekday),
        isCompleted: isCompleted ?? this.isCompleted,
        notified: notified ?? this.notified,
        googleCalendarEventId: clearGoogleEventId
            ? null
            : (googleCalendarEventId ?? this.googleCalendarEventId),
        category: clearCategory ? null : (category ?? this.category),
        createdAt: createdAt ?? this.createdAt,
      );
}
