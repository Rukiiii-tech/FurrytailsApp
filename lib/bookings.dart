// bookings.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:customerap/booking_details_screen.dart'; // Import BookingDetailsScreen
import 'package:customerap/booking_form_screen.dart'; // Import the BookingFormScreen
import 'dart:async'; // Import for StreamSubscription

class PetsScreen extends StatefulWidget {
  const PetsScreen({Key? key}) : super(key: key);

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser; // To store the current logged-in user
  bool _hasPendingBookingRestriction =
      false; // State variable to check for Pending bookings
  // Removed StreamSubscription _bookingStatusSubscription; as it's no longer needed for in-app SnackBar notifications
  // Removed _lastKnownBookingStatuses as it's no longer needed for in-app SnackBar notifications

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    // Listen for auth state changes to update the UI
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        if (user != null) {
          _checkRestrictedBookings(); // Initial check for pending bookings
          // Removed _startBookingStatusListener();
        }
      }
    });

    // If a user is already logged in at startup, start the listener immediately
    if (_currentUser != null) {
      _checkRestrictedBookings(); // Still need this for the "New Booking" button restriction
    }
  }

  @override
  void dispose() {
    // Removed _stopBookingStatusListener();
    super.dispose();
  }

  // Removed _stopBookingStatusListener() method
  // Removed _startBookingStatusListener() method (and its helper methods like _showInAppNotification)

  // Method to check for pending bookings that restrict new ones
  Future<void> _checkRestrictedBookings() async {
    if (_currentUser == null) {
      setState(() {
        _hasPendingBookingRestriction = false; // No user, no restriction
      });
      return;
    }

    try {
      final querySnapshot =
          await _firestore // Use the initialized _firestore instance
              .collection('bookings')
              .where('userId', isEqualTo: _currentUser!.uid)
              .where(
                'status',
                isEqualTo: 'Pending',
              ) // ONLY check for 'Pending' status to restrict
              .limit(1) // We only need to find one to know if exists
              .get();

      if (mounted) {
        setState(() {
          _hasPendingBookingRestriction = querySnapshot
              .docs
              .isNotEmpty; // Update state based on pending bookings
        });
      }
    } catch (e) {
      print('Error checking restricted bookings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking bookings: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no user is logged in, show a message
    if (_currentUser == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Please log in to view and create bookings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Optional: Keep background image if desired
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  'assets/pet_background.jpg',
                ), // Ensure this asset exists and pubspec.yaml is configured
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 20), // Adjusted space
                  Row(
                    children: [
                      const Icon(
                        Icons.history, // Icon to represent booking history
                        size: 30,
                        color: Colors.black,
                      ),
                      const Spacer(),
                      // Add Reload Button
                      IconButton(
                        onPressed: () {
                          setState(() {
                            // This will trigger a rebuild and refresh the StreamBuilder
                            _checkRestrictedBookings(); // Re-check booking restriction
                          });
                        },
                        icon: Icon(
                          Icons.refresh,
                          color: Colors.orange.shade700,
                          size: 28,
                        ),
                        tooltip: 'Refresh Bookings',
                      ),
                      const SizedBox(width: 8),
                      // Conditionally display the "New Booking" button
                      ElevatedButton(
                        onPressed: _hasPendingBookingRestriction
                            ? null
                            : () async {
                                print('New Booking button pressed!'); // DEBUG
                                String? currentUserEmail =
                                    _currentUser?.email; //

                                if (!mounted) {
                                  print(
                                    'Context not mounted, cannot show modal.',
                                  ); //
                                  return; //
                                }

                                // Show the modal bottom sheet for creating a new booking
                                final String?
                                resultBookingId = await showModalBottomSheet(
                                  context: context, //
                                  isScrollControlled:
                                      true, // Essential for full-height modals
                                  backgroundColor: Colors
                                      .transparent, // Transparent background for rounded corners to show
                                  builder: (BuildContext modalContext) {
                                    return _buildBookingModal(
                                      modalContext, // Pass the modal's context
                                      currentUserEmail, //
                                    );
                                  },
                                );

                                // If a booking ID is returned, update the UI to reflect the new booking
                                if (resultBookingId != null) {
                                  print(
                                    'New Booking ID created: $resultBookingId',
                                  ); // DEBUG
                                  // Trigger rebuild of the StreamBuilder to show the newly added booking
                                  setState(() {
                                    _checkRestrictedBookings(); // Re-check after a new booking is potentially made
                                  }); //
                                } else {
                                  print(
                                    'Modal closed without booking ID (cancelled or failed).',
                                  ); // DEBUG
                                }
                                // Call refresh after modal is dismissed regardless of result,
                                // to ensure booking list and restriction status are up-to-date.
                                setState(
                                  () {},
                                ); // Simple setState to trigger rebuild of bookings list
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _hasPendingBookingRestriction // Conditional background color
                              ? Colors
                                    .grey // Grey when disabled
                              : Colors
                                    .orangeAccent, // Original color when enabled
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'New Booking', // Button text remains the same
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Display list of bookings for the current user
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream:
                          _firestore // Use the initialized _firestore instance
                              .collection('bookings') //
                              .where(
                                'userId',
                                isEqualTo: _currentUser!.uid,
                              ) // Filter by current user's ID
                              .orderBy(
                                'timestamp',
                                descending: true,
                              ) // Order by most recent bookings first
                              .snapshots(), // Listen for real-time updates
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No booking records found for your account.\nTap "New Booking" to create one.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }

                        // Build a list of booking cards
                        return ListView.builder(
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            var bookingDoc = snapshot.data!.docs[index];
                            var bookingData =
                                bookingDoc.data() as Map<String, dynamic>;

                            // Safely extract booking details
                            String petName =
                                bookingData['petInformation']?['petName'] ??
                                'N/A';
                            String service =
                                bookingData['serviceType'] ?? 'N/A'; //
                            String status = bookingData['status'] ?? 'N/A'; //
                            final String pendingReasonRaw = bookingData['pendingReason'] ?? '';
                            final String vaccinationUrl = (bookingData['vaccinationRecord']?['imageUrl'] ?? '').toString();
                            final bool missingVaccination = status.toLowerCase() == 'pending' && (vaccinationUrl.isEmpty);
                            final String effectivePendingReason = pendingReasonRaw.isNotEmpty
                                ? pendingReasonRaw
                                : (missingVaccination ? 'Missing vaccination record' : '');
                            final String displayStatus = (status.toLowerCase() == 'pending' && effectivePendingReason.isNotEmpty)
                                ? 'Pending (Incomplete)'
                                : status;
                            Timestamp? timestamp =
                                bookingData['timestamp'] as Timestamp?; //
                            String submittedDate = timestamp != null
                                ? 'Submitted: ${timestamp.toDate().toLocal().toString().split(' ')[0]}'
                                : 'N/A'; //

                            // Determine status color
                            Color statusColor; //
                            switch (status.toLowerCase()) {
                              //
                              case 'accepted': //
                                statusColor = Colors.green; //
                                break; //
                              case 'pending': //
                                statusColor = Colors.orange; //
                                break; //
                              case 'rejected': //
                                statusColor = Colors.red; //
                                break; //
                              case 'cancelled': // Add cancelled status for consistent color
                                statusColor = Colors.red;
                                break;
                              case 'completed': // Add completed status for consistent color
                                statusColor = Colors.blueGrey;
                                break;
                              default: //
                                statusColor = Colors.grey; //
                            } //

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 4.0,
                              ), //
                              elevation: 4, //
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ), //
                              child: InkWell(
                                onTap: () {
                                  //
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BookingDetailsScreen(
                                            bookingId: bookingDoc.id,
                                          ),
                                    ),
                                  );
                                }, //
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0), //
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start, //
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                Colors.orange.shade100, //
                                            child: Icon(
                                              Icons.pets, //
                                              color: Colors.orange.shade700,
                                            ), //
                                          ),
                                          const SizedBox(width: 12), //
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start, //
                                              children: [
                                                Text(
                                                  petName, //
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ), //
                                                ),
                                                Text(
                                                  service, //
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 14,
                                                  ), //
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ), //
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.1,
                                              ), //
                                              borderRadius:
                                                  BorderRadius.circular(20), //
                                              border: Border.all(
                                                color: statusColor.withOpacity(
                                                  0.5,
                                                ),
                                              ), //
                                            ),
                                            child: Text(
                                              displayStatus, //
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.w600,
                                              ), //
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12), //
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: Colors.grey.shade600,
                                          ), //
                                          const SizedBox(width: 4), //
                                          Text(
                                            submittedDate, //
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ), //
                                          ),
                                          if (status.toLowerCase() == 'pending' && effectivePendingReason.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            const Text('•', style: TextStyle(color: Colors.grey)),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                effectivePendingReason,
                                                style: TextStyle(
                                                  color: Colors.orange.shade700,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // REMOVED FloatingActionButton from here
        ],
      ),
    );
  }

  // Helper method to build the content of the booking modal
  Widget _buildBookingModal(BuildContext modalContext, String? userEmail) {
    final double bottomPadding = MediaQuery.of(
      modalContext,
    ).viewInsets.bottom; //
    print('Building Booking Modal. Bottom padding: $bottomPadding'); // DEBUG

    return SizedBox.expand(
      //
      child: Padding(
        //
        padding: EdgeInsets.only(bottom: bottomPadding), //
        child: DraggableScrollableSheet(
          //
          initialChildSize: 0.9, // Start at 90% of screen height
          maxChildSize: 0.95, // Can expand to 95%
          minChildSize: 0.5, // Can shrink to 50%
          expand: false, // Essential to make it draggable
          builder: (BuildContext context, ScrollController scrollController) {
            //
            return Container(
              //
              decoration: BoxDecoration(
                //
                color: Colors.orange.shade300, //
                borderRadius: const BorderRadius.only(
                  //
                  topLeft: Radius.circular(20.0), //
                  topRight: Radius.circular(20.0), //
                ),
              ),
              child: Column(
                //
                children: [
                  Padding(
                    //
                    padding: const EdgeInsets.all(16.0), //
                    child: Row(
                      //
                      children: [
                        IconButton(
                          //
                          icon: const Icon(
                            //
                            Icons.arrow_back, //
                            color: Colors.white, //
                          ),
                          onPressed: () {
                            Navigator.pop(context, null); //
                            print(
                              'Back button pressed on modal, returning null.',
                            ); // DEBUG
                          },
                        ),
                        const Expanded(
                          //
                          child: Center(
                            //
                            child: Text(
                              'Booking Form', // Adjusted title
                              style: TextStyle(
                                //
                                color: Colors.white, //
                                fontWeight: FontWeight.bold, //
                                fontSize: 18, //
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          //
                          icon: const Icon(Icons.close, color: Colors.white), //
                          onPressed: () {
                            Navigator.pop(context, null); //
                            print(
                              'Close button pressed on modal, returning null.',
                            ); // DEBUG
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    //
                    child: SingleChildScrollView(
                      //
                      controller: scrollController, //
                      padding: const EdgeInsets.all(16.0), //
                      child: BookingFormScreen(
                        //
                        userEmail: userEmail, //
                        isModal:
                            true, // Indicate that it's being used as a modal
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
