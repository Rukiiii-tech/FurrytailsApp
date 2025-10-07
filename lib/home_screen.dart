import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Furry Tails Logo Image
              Image.network(
                'https://placehold.co/300x150/FFD700/000000?text=FURRY+TAILS+MEYCAUAYAN', // Placeholder image
                height: 150,
                width: 300,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/furrylogo.jpg',
                      height: 150,
                      width: 300,
                    ),
                  ); // Fallback icon
                },
              ),
              const SizedBox(height: 30),
              // Mobile App Booking System Text
              const Text(
                'MOBILE APP',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Text(
                'BOOKING SYSTEM',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 40),
              // Welcome Message Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade200, // Light orange background
                  borderRadius: BorderRadius.circular(20), // Rounded corners
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3), // changes position of shadow
                    ),
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    // Small Furry Tails Logo inside the card
                    Image.network(
                      'https://placehold.co/150x75/FFD700/000000?text=FURRY+TAILS', // Smaller placeholder
                      height: 75,
                      width: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/furrylogo.jpg',
                            height: 75,
                            width: 150,
                          ),
                        ); // Fallback icon
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Welcome to our Online Pet Booking System! Whether you\'re booking a cozy stay for your pet or scheduling grooming or veterinary services, we\'ve made the process simple and convenient.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5, // Line height
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // GET STARTED Button
              ElevatedButton(
                onPressed: () {
                  // Navigate to the new ServicesScreen
                  Navigator.pushReplacementNamed(
                    context,
                    '/services_screen',
                  ); // Changed navigation
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600, // Button color
                  foregroundColor: Colors.white, // Text color
                  padding: const EdgeInsets.symmetric(
                    horizontal: 60,
                    vertical: 18,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30), // Rounded button
                  ),
                  elevation: 5, // Add shadow
                ),
                child: const Text('GET STARTED'),
              ),
              const SizedBox(height: 30), // Space at the bottom
            ],
          ),
        ),
      ),
    );
  }

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
}
