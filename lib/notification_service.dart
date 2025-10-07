import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:customerap/booking_details_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Function to initialize the notification settings
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );
}

// Function to handle notification taps and navigate
void onDidReceiveNotificationResponse(
  NotificationResponse notificationResponse,
) async {
  if (notificationResponse.payload != null) {
    final bookingId = notificationResponse.payload;
    if (bookingId != null) {
      final context = navigatorKey.currentState!.overlay!.context;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailsScreen(bookingId: bookingId),
        ),
      );
    }
  }
}

// Function to show a local notification with the booking status
Future<void> showLocalNotification(RemoteMessage message) async {
  if (message.notification != null) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'booking_status_channel', // Channel ID
          'Booking Status Notifications', // Channel name
          channelDescription: 'Notifications for booking status updates.',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      message.hashCode, // Unique ID for the notification
      message.notification!.title,
      message.notification!.body,
      platformChannelSpecifics,
      payload: message.data['bookingId'], // Pass bookingId to the payload
    );
  }
}
