// services_screen.dart
import 'package:flutter/material.dart';
import 'package:customerap/bookings.dart'; // My Bookings
import 'package:customerap/profile_screen.dart'; // Profile Screen
import 'package:customerap/my_pets_screen.dart'; // My Pets Screen
import 'package:customerap/booking_form_screen.dart'; // Booking Form Screen
import 'package:customerap/notification_screen.dart'; // Notification Screen (accessed via AppBar icon)
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore access
import 'package:firebase_auth/firebase_auth.dart'; // Current user

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  int _selectedIndex = 0; // Controls the currently selected tab/page
  late PageController _pageController; // Controls the PageView
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  int _unreadNotificationsCount = 1; // State for the notification badge count

  // **CRITICAL:** The order of widgets in this list defines their index for the PageView.
  // Use 'const' where applicable for performance optimization.
  final List<Widget> _screens = [
    const _ServicesContent(), // Index 0: Services (Default landing)
    const PetsScreen(), // Index 1: My Bookings
    const MyPetsScreen(isModal: true), // Index 2: My Pets
    const ProfileScreen(), // Index 3: Profile
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _currentUser = FirebaseAuth.instance.currentUser;

    // Listen for Firebase Auth state changes to manage _currentUser and notification listener
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        if (user != null) {
          _listenForUnreadNotifications(); // Start listener if user logs in
        }
      }
    });

    // Also call listener once in initState if user is already logged in at app start
    if (_currentUser != null) {
      _listenForUnreadNotifications();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Method called when a BottomNavigationBarItem is tapped
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Update the selected index
    });
    _pageController.jumpToPage(
      index,
    ); // Make the PageView display the corresponding page
  }

  // Listener for unread approved bookings to update the badge count
  void _listenForUnreadNotifications() {
    if (_currentUser == null) {
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = 1;
        });
      }
      return;
    }

    _firestore
        .collection('bookings')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where(
          'status',
          isEqualTo: 'Approved',
        ) // Filtering for 'Approved' status
        .where('isRead', isEqualTo: false) // Filter for unread notifications
        .snapshots() // Listen for real-time updates
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                _unreadNotificationsCount = snapshot.docs.length;
              });
              print(
                "DEBUG: Unread notifications snapshot received. Count: ${_unreadNotificationsCount}",
              ); // Debug print
              // Removed `for` loop for printing individual docs here, as per your screenshot and general production practice.
              // It's still good for in-depth debugging if the count is incorrect.
            }
          },
          onError: (error) {
            print("Error listening for unread notifications: $error");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error fetching notification count: ${error.toString()}',
                  ),
                ),
              );
            }
          },
        );
  }

  // Builds the AppBar dynamically based on the selected tab
  AppBar _buildAppBar() {
    Widget titleWidget;

    switch (_selectedIndex) {
      case 0: // Services tab
        titleWidget = Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/furrylogo.jpg',
                height: 25,
                width: 50,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/furrylogo.jpg',
                      height: 24,
                      width: 24,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'FURRY TAILS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        );
        break;
      case 1: // My Bookings tab
        titleWidget = const Text(
          'My Bookings',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        );
        break;
      case 2: // My Pets tab
        titleWidget = const Text(
          'My Pets',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        );
        break;
      case 3: // Profile tab
        titleWidget = const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        );
        break;
      default: // Fallback
        titleWidget = const Text('Furry Tails');
    }

    return AppBar(
      title: titleWidget,
      backgroundColor: Colors.orange.shade300,
      elevation: 0,
      automaticallyImplyLeading: false, // Prevents back button on main tabs
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none,
                color: Colors.black87,
                size: 28,
              ),
              onPressed: () {
                // Navigate to the NotificationScreen (which is NOT a tab in the PageView)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationScreen(),
                  ),
                ).then((_) {
                  // After returning from NotificationScreen, mark viewed notifications as read
                  // This will also cause the _unreadNotificationsCount to refresh
                  _markAllApprovedBookingsAsRead();
                });
              },
            ),
            // Display red badge if there are unread notifications
            if (_unreadNotificationsCount > 1)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '${_unreadNotificationsCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8), // Spacing to the right of the icon
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          // This updates _selectedIndex when the user swipes (if swiping was enabled)
          // or if jumpToPage is called.
          setState(() {
            _selectedIndex = index;
          });
        },
        physics:
            const NeverScrollableScrollPhysics(), // Disables manual swiping between tabs
        children: _screens, // The list of screens for the PageView
      ),
      bottomNavigationBar: BottomNavigationBar(
        // **CRITICAL:** Ensure these items exactly match the order and number of items in _screens list.
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'Services',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'My Bookings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'My Pets'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex, // The currently selected tab
        selectedItemColor:
            Colors.orange.shade700, // Color for the selected icon/label
        unselectedItemColor: Colors.grey, // Color for unselected icons/labels
        onTap: _onItemTapped, // Callback when a tab is tapped
        backgroundColor:
            Colors.orange.shade100, // Background color of the nav bar
        type:
            BottomNavigationBarType.fixed, // Use fixed type for 4 or more items
      ),
    );
  }

  // Function to mark all approved and unread bookings as read
  Future<void> _markAllApprovedBookingsAsRead() async {
    if (_currentUser == null) return;

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: _currentUser!.uid)
          .where(
            'status',
            isEqualTo: 'Approved',
          ) // <--- NOW FILTERS FOR 'Approved'
          .where('isRead', isEqualTo: false)
          .get();

      final WriteBatch batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true}); // Set 'isRead' to true
      }
      await batch.commit(); // Commit the batch update
      print(
        "Marked all approved bookings as read for user ${_currentUser!.uid}",
      ); // Debug print
    } catch (e) {
      print("Error marking notifications as read: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error marking notifications as read: ${e.toString()}',
            ),
          ),
        );
      }
    }
  }
}

// _ServicesContent class has a missing `super.key` in its constructor.
// This is causing the "Expected to find '{'." error in your screenshot.
// FIX: Add `super.key` to its constructor.
class _ServicesContent extends StatelessWidget {
  const _ServicesContent({Key? key}) : super(key: key); // FIX: Added super.key

  void _showZoomableImage(
    BuildContext context,
    String imagePath,
    String label,
  ) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                semanticLabel: label,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    String title,
    String description,
    IconData leadingIcon, {
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.deepPurple.shade100,
                child: Icon(
                  leadingIcon,
                  size: 40,
                  color: Colors.deepPurple.shade700,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Our Services',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildServiceCard(
            context,
            'Book Now',
            'Safe and comfortable overnight stays for your beloved pets. Click to book!',
            Icons.book_online,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BookingFormScreen(isModal: false),
                ),
              );
            },
          ),
          const SizedBox(height: 15),
          _buildServiceCard(
            context,
            'Register Your Pet',
            'Manage your pet profiles for easier booking and services.',
            Icons.app_registration,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyPetsScreen(isModal: false),
                ),
              );
            },
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () => _showZoomableImage(
                  context,
                  'assets/cat_dog_hotel.jpg',
                  'Cat and Dog Hotel',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/cat_dog_hotel.jpg',
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    semanticLabel: 'Cat and Dog Hotel',
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showZoomableImage(
                  context,
                  'assets/why_choose_us.jpg',
                  'Why Choose Us',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/why_choose_us.jpg',
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    semanticLabel: 'Why Choose Us',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () => _showZoomableImage(
                  context,
                  'assets/inclusions.jpg',
                  'Inclusions',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/inclusions.jpg',
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    semanticLabel: 'Inclusions',
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showZoomableImage(
                  context,
                  'assets/mode_of_payment.jpg',
                  'Mode of Payment',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/mode_of_payment.jpg',
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    semanticLabel: 'Mode of Payment',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            'Facilities',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () => _showZoomableImage(
                  context,
                  'assets/kennel1.jpg',
                  'Kennel area for large dogs',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/kennel1.jpg',
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    semanticLabel: 'Kennel area for large dogs',
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showZoomableImage(
                  context,
                  'assets/kennel2.jpg',
                  'Kennel area for small dogs',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/kennel2.jpg',
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    semanticLabel: 'Kennel area for small dogs',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () => _showZoomableImage(
                  context,
                  'assets/furry1.jpg',
                  'Cat lounging at Furry Tails',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/furry1.jpg',
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    semanticLabel: 'Cat lounging at Furry Tails',
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showZoomableImage(
                  context,
                  'assets/furry2.jpg',
                  'Dog at Furry Tails',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/furry2.jpg',
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    semanticLabel: 'Dog at Furry Tails',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
