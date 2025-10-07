import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:customerap/booking_details_screen.dart'; // Import to navigate to details

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    // Listen for auth state changes to ensure we have a user
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  // Method to mark a specific notification as read when it's tapped
  Future<void> _markNotificationAsRead(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'isRead': true,
      });
      print('Booking $bookingId marked as read.');
    } catch (e) {
      print('Error marking booking as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to mark notification as read: ${e.toString()}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Please log in to view your notifications.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.orange.shade300,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('bookings')
            .where('userId', isEqualTo: _currentUser!.uid)
            .where('status', isEqualTo: 'Approved') // Filters for 'Approved'
            .orderBy('timestamp', descending: true) // Most recent first
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No approved booking notifications yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Approved bookings will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var bookingDoc = snapshot.data!.docs[index];
              var bookingData = bookingDoc.data() as Map<String, dynamic>;

              String petName =
                  bookingData['petInformation']?['petName'] ?? 'N/A';
              String serviceType = bookingData['serviceType'] ?? 'N/A';
              Timestamp? timestamp = bookingData['timestamp'] as Timestamp?;
              bool isRead = bookingData['isRead'] ?? false; // Get read status

              String dateApprovedFormatted = '';
              // Prefer 'approvedAt' timestamp if it exists, otherwise use 'timestamp' (submission date)
              if (bookingData.containsKey('approvedAt') &&
                  bookingData['approvedAt'] is Timestamp) {
                dateApprovedFormatted = DateFormat(
                  'MMM dd, yyyy',
                ).format((bookingData['approvedAt'] as Timestamp).toDate());
              } else if (bookingData.containsKey('adminNotes')) {
                dynamic adminNotesRaw = bookingData['adminNotes'];
                String adminNoteString = '';

                if (adminNotesRaw is List) {
                  adminNoteString = adminNotesRaw.join('\n');
                } else if (adminNotesRaw is String) {
                  adminNoteString = adminNotesRaw;
                }

                RegExp regExp = RegExp(
                  r"Status changed to Approved by admin at (.*)",
                ); // Updated to 'Approved'
                Match? match = regExp.firstMatch(adminNoteString);
                if (match != null && match.groupCount > 0) {
                  try {
                    DateTime parsedDate = DateFormat(
                      'MMM dd, yyyy hh:mm a',
                    ).parse(match.group(1)!);
                    dateApprovedFormatted = DateFormat(
                      'MMM dd, yyyy',
                    ).format(parsedDate);
                  } catch (e) {
                    print("Error parsing adminNotes date: $e");
                    dateApprovedFormatted = DateFormat(
                      'MMM dd, yyyy',
                    ).format(timestamp?.toDate() ?? DateTime.now());
                  }
                } else {
                  dateApprovedFormatted = DateFormat(
                    'MMM dd, yyyy',
                  ).format(timestamp?.toDate() ?? DateTime.now());
                }
              } else {
                dateApprovedFormatted = DateFormat(
                  'MMM dd, yyyy',
                ).format(timestamp?.toDate() ?? DateTime.now());
              }

              return Card(
                margin: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                color: isRead
                    ? Colors.white
                    : Colors.blue.shade50, // Highlight unread notifications
                child: InkWell(
                  onTap: () {
                    // Mark as read when tapped and navigate
                    _markNotificationAsRead(bookingDoc.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BookingDetailsScreen(bookingId: bookingDoc.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: isRead
                              ? Colors.grey.shade300
                              : Colors.green.shade100, // Change color if read
                          child: Icon(
                            isRead
                                ? Icons.notifications_none
                                : Icons
                                      .check_circle_outline, // Change icon if read
                            color: isRead
                                ? Colors.grey.shade700
                                : Colors.green.shade700, // Change color if read
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Booking Approved!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isRead
                                      ? Colors.black54
                                      : Colors.green.shade800, // Dim if read
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your $serviceType booking for $petName has been approved.', // Changed to 'approved' for consistency
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isRead
                                      ? Colors.grey.shade600
                                      : Colors.black87, // Dim if read
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Approved on: $dateApprovedFormatted', // Display the extracted/formatted approval date
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isRead
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade600, // Dim if read
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
