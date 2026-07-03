import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class GoogleCalendarService {
  static final _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/calendar.events'],
  );

  static const _baseUrl = 'https://www.googleapis.com/calendar/v3/calendars/primary/events';

  GoogleSignInAccount? _account;
  String? _accessToken;
  DateTime? _tokenExpiry;

  bool get isSignedIn => _account != null;

  Future<bool> signIn() async {
    try {
      _account = await _googleSignIn.signIn();
      if (_account == null) return false;
      await _refreshToken();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    _accessToken = null;
  }

  Future<void> tryRestoreSession() async {
    try {
      _account = await _googleSignIn.signInSilently();
      if (_account != null) await _refreshToken();
    } catch (_) {}
  }

  Future<void> _refreshToken() async {
    if (_account == null) return;
    final auth = await _account!.authentication;
    _accessToken = auth.accessToken;
    _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
  }

  Future<String?> _getToken() async {
    if (_account == null) return null;
    if (_accessToken == null || (_tokenExpiry?.isBefore(DateTime.now()) ?? true)) {
      await _refreshToken();
    }
    return _accessToken;
  }

  Future<String?> createEvent(Task task) async {
    if (task.dueDateTime == null) return null;
    final token = await _getToken();
    if (token == null) return null;

    final start = _formatDateTime(task);
    final end = _formatDateTimeEnd(task);

    final body = {
      'summary': task.title,
      'start': start,
      'end': end,
      if (task.recurrence != RecurrenceType.none)
        'recurrence': [_buildRRule(task)],
    };

    final res = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['id'] as String?;
    }
    return null;
  }

  Future<void> updateEvent(Task task) async {
    if (task.googleCalendarEventId == null || task.dueDateTime == null) return;
    final token = await _getToken();
    if (token == null) throw StateError('Google Calendar: not signed in');

    final body = {
      'summary': task.title,
      'start': _formatDateTime(task),
      'end': _formatDateTimeEnd(task),
    };

    final res = await http.patch(
      Uri.parse('$_baseUrl/${task.googleCalendarEventId}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw HttpException(
          'Google Calendar update failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final token = await _getToken();
    if (token == null) throw StateError('Google Calendar: not signed in');

    final res = await http.delete(
      Uri.parse('$_baseUrl/$eventId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    // 410 Gone means the event was already deleted — treat as success.
    if (res.statusCode != 204 && res.statusCode != 410) {
      throw HttpException(
          'Google Calendar delete failed (${res.statusCode}): ${res.body}');
    }
  }

  Map<String, String> _formatDateTime(Task task) {
    final dt = task.dueDateTime!;
    if (task.hasDueTime) {
      return {
        'dateTime': dt.toUtc().toIso8601String(),
        'timeZone': 'UTC',
      };
    }
    final dateStr =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    return {'date': dateStr};
  }

  Map<String, String> _formatDateTimeEnd(Task task) {
    final dt = task.dueDateTime!;
    if (task.hasDueTime) {
      final end = dt.add(const Duration(hours: 1));
      return {
        'dateTime': end.toUtc().toIso8601String(),
        'timeZone': 'UTC',
      };
    }
    final next = dt.add(const Duration(days: 1));
    final dateStr =
        '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
    return {'date': dateStr};
  }

  String _buildRRule(Task task) {
    switch (task.recurrence) {
      case RecurrenceType.daily:
        return 'RRULE:FREQ=DAILY';
      case RecurrenceType.weekly:
        return 'RRULE:FREQ=WEEKLY';
      case RecurrenceType.monthly:
        return 'RRULE:FREQ=MONTHLY';
      case RecurrenceType.weekday:
        final days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
        final idx = (task.recurrenceWeekday ?? 1) - 1;
        return 'RRULE:FREQ=WEEKLY;BYDAY=${days[idx]}';
      case RecurrenceType.none:
        return '';
    }
  }
}
