import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/medicine.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {},
    );

    _initialized = true;
  }

  Future<void> scheduleMedicineReminder({
    required Medicine medicine,
    required String patientName,
    required double lastGlucose,
    int startId = 100,
  }) async {
    await initialize();

    for (int i = 0; i < medicine.times.length; i++) {
      final timeParts = medicine.times[i].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final glucoseNote = lastGlucose > 126
          ? 'Your last glucose was slightly high — don\'t skip your meal!'
          : 'Keep it up, you\'re doing great!';

      final body = '$patientName, time for your ${medicine.name} ${medicine.dosage}. $glucoseNote';

      await _plugin.zonedSchedule(
        startId + i,
        '💊 Medication Reminder',
        body,
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Daily medication reminders from Antigravity',
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFF2D9CDB),
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> scheduleAllMedicines({
    required List<Medicine> medicines,
    required String patientName,
    required double lastGlucose,
  }) async {
    await cancelAll();
    for (int i = 0; i < medicines.length; i++) {
      await scheduleMedicineReminder(
        medicine: medicines[i],
        patientName: patientName,
        lastGlucose: lastGlucose,
        startId: i * 10,
      );
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    await _plugin.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general',
          'General',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
