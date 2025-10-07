// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Your screen imports
import 'package:customerap/welcome_screen.dart';
import 'package:customerap/login_screen.dart';
import 'package:customerap/signup_screen.dart';
import 'package:customerap/home_screen.dart';
import 'package:customerap/services_screen.dart';
import 'package:customerap/bookings.dart'; // Still My Bookings
import 'package:customerap/forgot_password_screen.dart';
import 'package:customerap/my_pets_screen.dart';
import 'package:customerap/booking_details_screen.dart';
import 'package:customerap/notification_screen.dart';
import 'package:customerap/notification_service.dart'; // The new notification service

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  await showLocalNotification(
    message,
  ); // Show a local notification using the service
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Set the background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications
  await initializeNotifications();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    setupFirebaseMessaging();
  }

  Future<void> setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission for notifications
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Get the FCM token and save to Firestore
    String? token = await messaging.getToken();
    print('FCM Token: $token');

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && token != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true))
            .then((_) {
              print('FCM Token updated for user ${user.uid}');
            })
            .catchError((error) {
              print('Failed to update FCM Token: $error');
            });
      }
    });

    // Handle messages in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      showLocalNotification(message); // Show a local pop-up notification
    });

    // Handle taps on notifications when the app is in the background or terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      if (message.data.containsKey('bookingId') &&
          message.data['bookingId'] != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) =>
                BookingDetailsScreen(bookingId: message.data['bookingId']!),
          ),
        );
      }
    });

    // Handle initial message when the app is launched from a terminated state
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      if (initialMessage.data.containsKey('bookingId') &&
          initialMessage.data['bookingId'] != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => BookingDetailsScreen(
              bookingId: initialMessage.data['bookingId']!,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Use the global key for navigation
      title: 'Furry Tails',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home_screen': (context) => const HomeScreen(),
        '/services_screen': (context) => const ServicesScreen(),
        '/bookings': (context) => const PetsScreen(), // Corrected route name
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/my_pets_screen': (context) => const MyPetsScreen(),
        '/notification_screen': (context) => const NotificationScreen(),
      },
    );
  }
}
