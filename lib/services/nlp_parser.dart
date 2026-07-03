import 'package:flutter/material.dart';
import '../models/task.dart';

class ParsedTask {
  final String title;
  final DateTime? dueDate;
  final TimeOfDay? dueTime;
  final RecurrenceType recurrence;
  final int? recurrenceWeekday;
  final String? category;

  const ParsedTask({
    required this.title,
    this.dueDate,
    this.dueTime,
    this.recurrence = RecurrenceType.none,
    this.recurrenceWeekday,
    this.category,
  });
}

class NlpParser {
  static const _weekdays = {
    'monday': DateTime.monday,
    'mon': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'tue': DateTime.tuesday,
    'tues': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'wed': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'thu': DateTime.thursday,
    'thur': DateTime.thursday,
    'thurs': DateTime.thursday,
    'friday': DateTime.friday,
    'fri': DateTime.friday,
    'saturday': DateTime.saturday,
    'sat': DateTime.saturday,
    'sunday': DateTime.sunday,
    'sun': DateTime.sunday,
  };

  static const _months = {
    'january': 1, 'jan': 1,
    'february': 2, 'feb': 2,
    'march': 3, 'mar': 3,
    'april': 4, 'apr': 4,
    'may': 5,
    'june': 6, 'jun': 6,
    'july': 7, 'jul': 7,
    'august': 8, 'aug': 8,
    'september': 9, 'sep': 9, 'sept': 9,
    'october': 10, 'oct': 10,
    'november': 11, 'nov': 11,
    'december': 12, 'dec': 12,
  };

  static ParsedTask parse(String input) {
    if (input.trim().isEmpty) return const ParsedTask(title: '');

    // Extract /category — requires whitespace before slash so "29/7" is not confused as a category
    String? category;
    final trimmedInput = input.trim();
    final categoryMatch = RegExp(r'\s+/(\w+)').firstMatch(trimmedInput);
    if (categoryMatch != null) {
      category = categoryMatch.group(1)!.toLowerCase();
      input = (trimmedInput.substring(0, categoryMatch.start) +
               trimmedInput.substring(categoryMatch.end)).trim();
    } else {
      // Also handle "/category" as the entire input (no task title)
      final onlyCategory = RegExp(r'^/(\w+)\s*$').firstMatch(trimmedInput);
      if (onlyCategory != null) {
        category = onlyCategory.group(1)!.toLowerCase();
        input = '';
      }
    }

    String text = input.trim().toLowerCase();
    DateTime? date;
    TimeOfDay? time;
    RecurrenceType recurrence = RecurrenceType.none;
    int? recurrenceWeekday;

    // 1. Extract time
    final timeResult = _extractTime(text);
    if (timeResult != null) {
      time = timeResult.$1;
      text = timeResult.$2;
    }

    // 2. Extract recurrence
    final recurrenceResult = _extractRecurrence(text);
    if (recurrenceResult != null) {
      recurrence = recurrenceResult.$1;
      recurrenceWeekday = recurrenceResult.$2;
      text = recurrenceResult.$3;
      if (recurrenceWeekday != null) {
        date = _nextWeekday(recurrenceWeekday);
      }
    }

    // 3. Extract date
    if (date == null) {
      final dateResult = _extractDate(text);
      if (dateResult != null) {
        date = dateResult.$1;
        text = dateResult.$2;
      }
    }

    // 4. Clean title
    final title = _cleanTitle(text, input.trim());

    return ParsedTask(
      title: title,
      dueDate: date,
      dueTime: time,
      recurrence: recurrence,
      category: category,
      recurrenceWeekday: recurrenceWeekday,
    );
  }

  static (TimeOfDay, String)? _extractTime(String text) {
    // Patterns: "at 5pm", "at 5:30pm", "at 17:00", "at 9 am", "noon", "midnight"
    if (text.contains('noon')) {
      return (const TimeOfDay(hour: 12, minute: 0), text.replaceAll('noon', '').trim());
    }
    if (text.contains('midnight')) {
      return (const TimeOfDay(hour: 0, minute: 0), text.replaceAll('midnight', '').trim());
    }

    final re = RegExp(
      r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
      caseSensitive: false,
    );
    final match = re.firstMatch(text);
    if (match == null) return null;

    int hour = int.parse(match.group(1)!);
    final minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
    final period = match.group(3)?.toLowerCase();

    if (period == 'pm' && hour < 12) hour += 12;
    if (period == 'am' && hour == 12) hour = 0;
    if (period == null) {
      // No am/pm: assume PM for 1-11, keep 12 as noon
      if (hour >= 1 && hour <= 11) hour += 12;
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    final cleaned = text.replaceFirst(match[0]!, '').trim();
    return (TimeOfDay(hour: hour, minute: minute), cleaned);
  }

  static (RecurrenceType, int?, String)? _extractRecurrence(String text) {
    if (RegExp(r'\b(every\s+day|daily)\b', caseSensitive: false).hasMatch(text)) {
      final cleaned = text.replaceAll(RegExp(r'\b(every\s+day|daily)\b', caseSensitive: false), '').trim();
      return (RecurrenceType.daily, null, cleaned);
    }
    if (RegExp(r'\b(every\s+week|weekly)\b', caseSensitive: false).hasMatch(text)) {
      final cleaned = text.replaceAll(RegExp(r'\b(every\s+week|weekly)\b', caseSensitive: false), '').trim();
      return (RecurrenceType.weekly, null, cleaned);
    }
    if (RegExp(r'\b(every\s+month|monthly)\b', caseSensitive: false).hasMatch(text)) {
      final cleaned = text.replaceAll(RegExp(r'\b(every\s+month|monthly)\b', caseSensitive: false), '').trim();
      return (RecurrenceType.monthly, null, cleaned);
    }

    final weekdayNames = _weekdays.keys.join('|');
    final everyRe = RegExp(r'\bevery\s+(' + weekdayNames + r')\b', caseSensitive: false);
    final match = everyRe.firstMatch(text);
    if (match != null) {
      final day = _weekdays[match.group(1)!.toLowerCase()]!;
      final cleaned = text.replaceFirst(match[0]!, '').trim();
      return (RecurrenceType.weekday, day, cleaned);
    }
    return null;
  }

  static (DateTime, String)? _extractDate(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Absolute keywords
    final patterns = <RegExp, DateTime Function()>{
      RegExp(r'\btoday\b', caseSensitive: false): () => today,
      RegExp(r'\b(tomorrow|tmrw|tmr)\b', caseSensitive: false): () => today.add(const Duration(days: 1)),
      RegExp(r'\byesterday\b', caseSensitive: false): () => today.subtract(const Duration(days: 1)),
      RegExp(r'\bnext\s+week\b', caseSensitive: false): () => today.add(const Duration(days: 7)),
      RegExp(r'\bnext\s+month\b', caseSensitive: false): () => DateTime(today.year, today.month + 1, today.day),
    };

    for (final entry in patterns.entries) {
      final match = entry.key.firstMatch(text);
      if (match != null) {
        return (entry.value(), text.replaceFirst(match[0]!, '').trim());
      }
    }

    // "in X days/weeks/months"
    final inXRe = RegExp(r'\bin\s+(\d+)\s+(day|days|week|weeks|month|months)\b', caseSensitive: false);
    final inXMatch = inXRe.firstMatch(text);
    if (inXMatch != null) {
      final n = int.parse(inXMatch.group(1)!);
      final unit = inXMatch.group(2)!.toLowerCase();
      DateTime date;
      if (unit.startsWith('day')) {
        date = today.add(Duration(days: n));
      } else if (unit.startsWith('week')) {
        date = today.add(Duration(days: n * 7));
      } else {
        date = DateTime(today.year, today.month + n, today.day);
      }
      return (date, text.replaceFirst(inXMatch[0]!, '').trim());
    }

    // "next monday" etc.
    for (final entry in _weekdays.entries) {
      final re = RegExp(r'\bnext\s+' + entry.key + r'\b', caseSensitive: false);
      final match = re.firstMatch(text);
      if (match != null) {
        return (_nextWeekday(entry.value, forceNext: true), text.replaceFirst(match[0]!, '').trim());
      }
    }

    // "this monday" etc.
    for (final entry in _weekdays.entries) {
      final re = RegExp(r'\bthis\s+' + entry.key + r'\b', caseSensitive: false);
      final match = re.firstMatch(text);
      if (match != null) {
        return (_nextWeekday(entry.value), text.replaceFirst(match[0]!, '').trim());
      }
    }

    // Just "monday" etc. (match longer names first to avoid 'sat' matching inside 'saturday')
    final sortedWeekdays = _weekdays.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final name in sortedWeekdays) {
      final re = RegExp(r'\b' + name + r'\b', caseSensitive: false);
      final match = re.firstMatch(text);
      if (match != null) {
        return (_nextWeekday(_weekdays[name]!), text.replaceFirst(match[0]!, '').trim());
      }
    }

    // "january 5th" / "jan 5" / "5 january" / "5th january"
    final sortedMonths = _months.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final name in sortedMonths) {
      final re1 = RegExp(r'\b' + name + r'\s+(\d{1,2})(?:st|nd|rd|th)?\b', caseSensitive: false);
      final m1 = re1.firstMatch(text);
      if (m1 != null) {
        final date = _monthDay(_months[name]!, int.parse(m1.group(1)!), today);
        if (date != null) return (date, text.replaceFirst(m1[0]!, '').trim());
      }
      final re2 = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?\s+' + name + r'\b', caseSensitive: false);
      final m2 = re2.firstMatch(text);
      if (m2 != null) {
        final date = _monthDay(_months[name]!, int.parse(m2.group(1)!), today);
        if (date != null) return (date, text.replaceFirst(m2[0]!, '').trim());
      }
    }

    // "1/7", "1/7/2026", "25/12/26" — day/month/year(optional)
    final slashRe = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b');
    final slashMatch = slashRe.firstMatch(text);
    if (slashMatch != null) {
      final day = int.parse(slashMatch.group(1)!);
      final month = int.parse(slashMatch.group(2)!);
      if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        int? year;
        if (slashMatch.group(3) != null) {
          year = int.parse(slashMatch.group(3)!);
          if (year < 100) year += 2000;
        }
        final date = year != null
            ? _tryDate(year, month, day)
            : _monthDay(month, day, today);
        if (date != null) return (date, text.replaceFirst(slashMatch[0]!, '').trim());
      }
    }

    // "on the 15th" / "the 5th"
    final ordinalRe = RegExp(r'\b(?:on\s+)?(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)\b', caseSensitive: false);
    final ordinalMatch = ordinalRe.firstMatch(text);
    if (ordinalMatch != null) {
      final day = int.parse(ordinalMatch.group(1)!);
      if (day >= 1 && day <= 31) {
        var candidate = DateTime(today.year, today.month, day);
        if (candidate.isBefore(today)) {
          candidate = DateTime(today.year, today.month + 1, day);
        }
        return (candidate, text.replaceFirst(ordinalMatch[0]!, '').trim());
      }
    }

    return null;
  }

  static DateTime _nextWeekday(int weekday, {bool forceNext = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int daysUntil = weekday - today.weekday;
    if (daysUntil < 0 || (daysUntil == 0 && forceNext)) daysUntil += 7;
    return today.add(Duration(days: daysUntil));
  }

  static DateTime? _tryDate(int year, int month, int day) {
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _monthDay(int month, int day, DateTime today) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      var candidate = DateTime(today.year, month, day);
      if (candidate.isBefore(today)) candidate = DateTime(today.year + 1, month, day);
      return candidate;
    } catch (_) {
      return null;
    }
  }

  static String _cleanTitle(String text, String original) {
    // Remove leftover connecting words
    text = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^(on|at|by|for|a|an)\s+', caseSensitive: false), '')
        .trim();

    if (text.isEmpty) return original.trim();

    // Restore original casing for the title portion
    final lower = original.toLowerCase();
    final idx = lower.indexOf(text.toLowerCase());
    if (idx >= 0) {
      return original.substring(idx, idx + text.length).trim();
    }
    return text;
  }
}
