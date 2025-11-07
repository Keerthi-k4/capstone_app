import 'package:attempt2/providers/auth_provider.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;

class CalendarService {
  CalendarService(this._authProvider);

  AuthProvider _authProvider;

  static const String _calendarId = 'primary';

  void updateAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  Future<void> addWorkoutToCalendar({
    required String title,
    required String description,
    required DateTime start,
    required DateTime end,
    List<String>? attendeeEmails,
  }) async {
    if (!_authProvider.isLoggedIn) {
      throw CalendarException('You must be logged in to add calendar events.');
    }

    final headers =
        await _authProvider.getGoogleAuthHeaders(promptIfNeeded: true);
    if (headers == null) {
      throw CalendarException('Google Calendar permissions are not granted.');
    }

    final client = _GoogleAuthClient(headers);

    try {
      final calendarApi = calendar.CalendarApi(client);
      final event = calendar.Event(
        summary: title,
        description: description,
        start: calendar.EventDateTime(
          dateTime: start.toUtc(),
          timeZone: 'UTC',
        ),
        end: calendar.EventDateTime(
          dateTime: end.toUtc(),
          timeZone: 'UTC',
        ),
      );

      if (attendeeEmails != null && attendeeEmails.isNotEmpty) {
        event.attendees = attendeeEmails
            .map((email) => calendar.EventAttendee(email: email))
            .toList();
      }

      await calendarApi.events.insert(event, _calendarId);
    } on calendar.DetailedApiRequestError catch (e) {
      throw CalendarException('Google Calendar error: ${e.message ?? e}');
    } catch (e) {
      throw CalendarException('Failed to add workout to calendar: $e');
    } finally {
      client.close();
    }
  }
}

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class CalendarException implements Exception {
  CalendarException(this.message);

  final String message;

  @override
  String toString() => message;
}
