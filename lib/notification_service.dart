
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // Singleton pattern to ensure only one instance of this service
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialization settings for Android
    // Uses the default launcher icon
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // General initialization settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    // Request notification permissions on Android 13+
    // This is crucial for the notifications to be displayed
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // CORRECTED: The method is requestNotificationsPermission, not requestPermission
    await androidPlugin?.requestNotificationsPermission();
  }

  // Shows a persistent notification indicating the SSH connection is active
  Future<void> showSshConnectedNotification(String connectionTime) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'ssh_connection_channel', // A unique channel ID
      'SSH Connection Status',    // The channel name displayed to the user
      channelDescription: 'Notification for active SSH tunnel',
      importance: Importance.low, // Use low importance for ongoing notifications
      priority: Priority.low,
      ongoing: true,        // Makes the notification persistent (cannot be swiped away)
      autoCancel: false,      // The notification does not close when tapped
      subText: 'Connection is active', 
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    // The show method updates the notification if it already exists with the same ID (0)
    await _notificationsPlugin.show(
      0, // Notification ID
      'SSH Tunnel: Connected',
      'Uptime: $connectionTime',
      notificationDetails,
    );
  }

  // Cancels the SSH notification
  Future<void> cancelSshNotification() async {
    await _notificationsPlugin.cancel(0); // Cancel the notification with ID 0
  }
}
