import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Call once before any zonedSchedule / TZDateTime.now(tz.local) usage.
Future<void> initNotificationTimezone() async {
  tz.initializeTimeZones();
  final String localTz = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(localTz));
}
