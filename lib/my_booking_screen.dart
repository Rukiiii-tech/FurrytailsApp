// my_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:customerap/booking_details_screen.dart'; // Ensure this import path is correct

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({Key? key}) : super(key: key);

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  User? _currentUser;
  String _selectedStatusFilter = 'All'; // Filter for booking status

  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Accepted',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  void _refreshBookings() {
    setState(() {
      // Rebuilds the widget tree, causing StreamBuilder to re-evaluate the query
      print('Refreshing bookings...');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Please log in to view your bookings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    // Build the query dynamically based on selected filter
    Query<Map<String, dynamic>> bookingsQuery = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: _currentUser!.uid)
        .orderBy('timestamp', descending: true); // Order by submission time

    if (_selectedStatusFilter != 'All') {
      bookingsQuery = bookingsQuery.where(
        'status',
        isEqualTo: _selectedStatusFilter,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatusFilter,
                    decoration: InputDecoration(
                      labelText: 'Filter by Status',
                      prefixIcon: const Icon(
                        Icons.filter_list,
                        color: Color(0xFFFFB74D), // Consistent icon color
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.deepPurple.shade50,
                    ),
                    items: _statusFilters.map((String filter) {
                      return DropdownMenuItem<String>(
                        value: filter,
                        child: Text(filter),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedStatusFilter = newValue;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    size: 30,
                    color: Colors.deepPurple,
                  ),
                  onPressed: _refreshBookings, // Call the refresh function
                  tooltip: 'Refresh Bookings', // Add tooltip for better UX
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: bookingsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print(
                    'Error fetching bookings: ${snapshot.error}',
                  ); // For debugging
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No bookings found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Once you book a service, it will appear here.',
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

                    // Safely extract data from new top-level structure
                    final String serviceType =
                        bookingData['serviceType'] as String? ?? 'N/A';
                    final String status =
                        bookingData['status'] as String? ?? 'N/A';
                    final String petName =
                        bookingData['petName'] as String? ??
                        'N/A'; // Top-level petName
                    final String bookingDate =
                        bookingData['date'] as String? ??
                        'N/A'; // Top-level date
                    final String bookingTime =
                        bookingData['time'] as String? ??
                        'N/A'; // Top-level time

                    // Determine icon and color based on service type
                    IconData serviceIcon;
                    Color iconColor;
                    if (serviceType == 'Boarding') {
                      serviceIcon = Icons.hotel;
                      iconColor = Colors.blue.shade700;
                    } else if (serviceType == 'Grooming') {
                      serviceIcon = Icons.cut;
                      iconColor = Colors.pink.shade700;
                    } else {
                      serviceIcon = Icons.miscellaneous_services;
                      iconColor = Colors.grey.shade700;
                    }

                    // Determine status color
                    Color statusColor;
                    switch (status) {
                      case 'Accepted':
                        statusColor = Colors.green.shade700;
                        break;
                      case 'Pending':
                        statusColor = Colors.orange.shade700;
                        break;
                      case 'Cancelled':
                        statusColor = Colors.red.shade700;
                        break;
                      case 'Completed':
                        statusColor = Colors.blueGrey.shade700;
                        break;
                      default:
                        statusColor = Colors.grey.shade700;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: InkWell(
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext dialogContext) {
                              return Dialog(
                                backgroundColor: Color(0xFFC09B6A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 24,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Align(
                                        alignment: Alignment.topLeft,
                                        child: Text(
                                          'Notice',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Please note: The downpayment is non-refundable. Do you wish to continue?',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 24),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              dialogContext,
                                              rootNavigator: true,
                                            ).pop(false),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.orange.shade700,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => Navigator.of(
                                              dialogContext,
                                              rootNavigator: true,
                                            ).pop(true),
                                            child: Text('Continue'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                          if (confirmed == true && mounted) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookingDetailsScreen(
                                  bookingId: bookingDoc.id,
                                ),
                              ),
                            );
                            _refreshBookings(); // Refresh when returning from detail screen
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: iconColor.withOpacity(0.1),
                                    child: Icon(serviceIcon, color: iconColor),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$serviceType for $petName',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Display top-level date and time
                                        Text(
                                          'Booked for $bookingDate at $bookingTime',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: statusColor),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
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
    );
  }
}
