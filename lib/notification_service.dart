
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    // Request notification permissions on Android 13+
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  Future<void> showSshConnectedNotification(String connectionTime) async {
    // Corrected for flutter_local_notifications >= v19
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'ssh_connection_channel',      // Channel ID
      'SSH Connection Status',         // Channel Name
      channelDescription: 'Notification for active SSH tunnel', // Named param
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,                 // Makes the notification persistent
      autoCancel: false,             // Does not close on tap
      subText: 'Connection is active',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await _notificationsPlugin.show(
      0, // Notification ID
      'SSH Tunnel: Connected',
      'Uptime: $connectionTime',
      notificationDetails,
    );
  }

  Future<void> cancelSshNotification() async {
    await _notificationsPlugin.cancel(0);
  }
}
