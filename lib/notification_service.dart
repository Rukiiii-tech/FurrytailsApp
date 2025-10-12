// notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:customerap/booking_details_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Import if used for background messaging

// Global Key for navigation outside widgets (used in main.dart)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  // Singleton pattern definition
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  // Plugin is an INSTANCE variable (part of the class)
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
  }

  // Handles notification taps and navigates
  void onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse,
  ) async {
    if (notificationResponse.payload != null) {
      final bookingId = notificationResponse.payload;
      if (bookingId != null) {
        // Safe check for context availability before navigation
        if (navigatorKey.currentState != null &&
            navigatorKey.currentState!.overlay != null) {
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
  }

  // METHOD FIX: This method is specifically for the Approved Booking Pop-up
  Future<void> showBookingApprovedNotification({
    required String bookingId,
    required String serviceType,
    required String petName,
  }) async {
    const AndroidNotificationDetails
    androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'booking_status_channel', // Channel ID (This must be used consistently)
      'Booking Status Notifications', // Channel Name
      channelDescription: 'Notifications for booking status updates.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _flutterLocalNotificationsPlugin.show(
      bookingId.hashCode, // Unique ID
      'Booking Approved! 🎉',
      'Your $serviceType booking for $petName has been confirmed!',
      platformChannelSpecifics,
      payload: bookingId, // Pass the booking ID in the payload for navigation
    );
  }

  // Generic show notification for Firebase Messaging (as needed by main.dart)
  Future<void> showNotification(
    int id,
    String title,
    String body, {
    String? payload,
    String channelId = 'general_channel_id',
    String channelName = 'General Notifications',
    String channelDescription = 'General app notifications.',
  }) async {
    // Re-using the booking channel for simple Firebase messages if needed, or define a new one.
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'general_channel_id', // General Channel ID
          'General Notifications',
          channelDescription: 'General app notifications.',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}
