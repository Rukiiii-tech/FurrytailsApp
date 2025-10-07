// signup_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>(); // Key for form validation
  // Text editing controllers for each input field
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _detailedAddressController =
      TextEditingController();

  // New state variables for the dropdowns
  String? _selectedMunicipality;
  String? _selectedBarangay;

  bool _isLoading = false; // State to manage loading indicator

  // List of cities and municipalities in Bulacan
  final List<String> bulacanMunicipalities = [
    'Angat',
    'Balagtas',
    'Baliuag',
    'Bocaue',
    'Bulakan',
    'Bustos',
    'Calumpit',
    'Doña Remedios Trinidad',
    'Guiguinto',
    'Hagonoy',
    'Malolos',
    'Marilao',
    'Meycauayan',
    'Norzagaray',
    'Obando',
    'Pandi',
    'Paombong',
    'Plaridel',
    'Pulilan',
    'San Ildefonso',
    'San Jose del Monte',
    'San Miguel',
    'San Rafael',
    'Santa Maria',
  ];

  // Map of municipalities to their barangays
  final Map<String, List<String>> _barangays = {
    'Angat': [
      'Baybay',
      'Binagbag',
      'Doña Remedios Trinidad',
      'Encanto',
      'Laog',
      'Marungko',
      'Niugan',
      'Paltok',
      'Poblacion',
      'San Roque',
    ],
    'Balagtas': [
      'Borol 1st',
      'Borol 2nd',
      'Dalig',
      'Longos',
      'Panginay',
      'Pulong Gubat',
      'San Juan',
      'Santol',
      'Wawa',
    ],
    'Baliuag': [
      'Bagong Nayon',
      'Barangay 1 (Poblacion)',
      'Barangay 2 (Poblacion)',
      'Barangay 3 (Poblacion)',
      'Barangay 4 (Poblacion)',
      'Barangay 5 (Poblacion)',
      'Calantipay',
      'Catulinan',
      'Concepcion',
      'Hinukay',
      'Makinig',
      'Pagala',
      'Piel',
      'Pinagbarilan',
      'Sabang',
      'San Jose',
      'San Roque',
      'Santa Barbara',
      'Santa Ines',
      'Santo Cristo',
      'Santo Nino',
      'Sulivan',
      'Tangos',
      'Tarcan',
      'Tiaong',
      'Tibagan',
      'Virgen delos Flores',
    ],
    'Bocaue': [
      'Antipona',
      'Bagumbayan',
      'Bambang',
      'Binga',
      'Buenavista',
      'Bunducan',
      'Caingin',
      'Caypombo',
      'Duhat',
      'Igulot',
      'Lolomboy',
      'Patubig',
      'Poblacion',
      'Sulucan',
      'Taal',
      'Tambobong',
      'Turo',
      'Wakas',
    ],
    'Bulakan': [
      'Balubad',
      'Bambang',
      'Bagumbayan',
      'Maysantol',
      'Perez',
      'Pitpitan',
      'San Francisco',
      'San Jose',
      'San Nicolas',
      'Santa Ana',
    ],
    'Bustos': [
      'Bustos',
      'Camachilihan',
      'Catacte',
      'Cambaog',
      'Liciada',
      'Malamig',
      'Malawak',
      'Poblacion',
      'San Pedro',
      'Talampas',
      'Tanawan',
    ],
    'Calumpit': [
      'Balungao',
      'Calumpang',
      'Cañiogan',
      'Corazon',
      'Frances',
      'Gatbuca',
      'Gatbuca',
      'Iba Este',
      'Iba Oeste',
      'Maconac',
      'Meysulao',
    ],
    'Doña Remedios Trinidad': [
      'Bayabas',
      'Camachin',
      'Kabuco',
      'Pulong Sampalok',
      'Sapang Bulak',
      'Tiaong',
      'Tulay',
      'Ugat',
    ],
    'Guiguinto': [
      'Daungan',
      'Ilaw ng Nayon',
      'Malusac',
      'Marungko',
      'Perez',
      'Pinagbakahan',
      'San Francisco',
      'San Nicolas',
      'Santa Cruz',
    ],
    'Hagonoy': [
      'Abulalas',
      'Hagonoy',
      'Iba',
      'Mabolo',
      'Maligaya',
      'Poblacion',
      'San Agustin',
      'San Miguel',
      'San Nicolas',
    ],
    'Malolos': [
      'Anilao',
      'Bagna',
      'Balayong',
      'Balite',
      'Bangkal',
      'Barihan',
      'Bulihan',
    ],
    'Marilao': [
      'Abangan Norte',
      'Abangan Sur',
      'Calvario',
      'Ibayo',
      'Lias',
      'Loma de Gato',
      'Marilao',
      'Poblacion',
      'San Pedro',
      'Santa Rosa',
      'Tabing Ilog',
    ],
    'Meycauayan': [
      'Bahay Pare',
      'Bancal',
      'Banga',
      'Bayugo',
      'Caingin',
      'Calvario',
      'Camalig',
    ],
    'Norzagaray': [
      'Barangay 1',
      'Barangay 2',
      'Barangay 3',
      'Barangay 4',
      'Barangay 5',
      'Barangay 6',
      'Barangay 7',
    ],
    'Obando': [
      'Binuangan',
      'Hulo',
      'Lawa',
      'Malabon',
      'Paco',
      'Pag-asa',
      'Polo',
    ],
    'Pandi': [
      'Bagbaguin',
      'Bagong Barrio',
      'Bunsuran 1st',
      'Bunsuran 2nd',
      'Bunsuran 3rd',
      'Cambaog',
      'Cupang',
      'Malibong Bata',
      'Malibong Matanda',
      'Mataas na Lupa',
      'Masuso',
      'Siling Bata',
    ],
    'Paombong': [
      'Barangay 1',
      'Barangay 2',
      'Barangay 3',
      'Barangay 4',
      'Barangay 5',
      'Barangay 6',
    ],
    'Plaridel': [
      'Agaya',
      'Agaya',
      'Balante',
      'Bintog',
      'Bulihan',
      'Culianin',
      'Lumang Gapan',
      'Poblacion',
      'Rueda',
      'Santa Ines',
      'Santo Nino',
      'Sukat',
    ],
    'Pulilan': [
      'Balatong A',
      'Balatong B',
      'Cutcut',
      'Dampol 1st',
      'Dampol 2nd',
      'Inaon',
      'Lumbac',
      'Paltao',
      'Poblacion',
    ],
    'San Ildefonso': [
      'Bagong Barrio',
      'Basuit',
      'Bayan-Bayan',
      'Bgy. Matimbubong',
      'Bgy. Ulingao',
      'Biclat',
      'Bubulong Malaki',
      'Bubulong Munti',
    ],
    'San Jose del Monte': [
      'Assumption',
      'Bagong Silang',
      'Bagong Buhay',
      'Bagong Buhay 2',
      'Bagong Buhay 3',
      'Bagong Buhay 4',
      'Bagong Buhay 5',
      'Bagong Buhay 6',
    ],
    'San Miguel': [
      'Bagong Buhay',
      'Bagong Barrio',
      'Buliran',
      'Calasag',
      'Kabulusan',
      'Lourdes',
      'Maginao',
      'Malimban',
    ],
    'San Rafael': [
      'Bucal',
      'Capihan',
      'Cattleya',
      'Dulong Bayan',
      'Dulong Bayan 2nd',
      'Galo',
      'Mahabang Parang',
      'Manicling',
    ],
    'Santa Maria': [
      'Bagbaguin',
      'Balasing',
      'Bulac',
      'Caysio',
      'Guyong',
      'Malis',
      'Poblacion',
      'Sampaloc',
      'Santa Cruz',
      'Turo',
      'Tumana',
    ],
  };

  @override
  void dispose() {
    // Dispose all controllers to prevent memory leaks
    _lastNameController.dispose();
    _firstNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _contactNumberController.dispose();
    _detailedAddressController.dispose();
    super.dispose();
  }

  void _signUp() async {
    if (_formKey.currentState!.validate()) {
      // Check if passwords match
      if (_passwordController.text != _confirmPasswordController.text) {
        showCustomModal(
          context,
          'Registration Failed',
          'Passwords do not match!',
        );
        return; // Stop the sign-up process
      }

      setState(() {
        _isLoading = true; // Show loading indicator
      });

      try {
        // Create user with email and password
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        // Send email verification after user creation
        await userCredential.user!.sendEmailVerification();

        // Combine the address fields into a single string
        String fullAddress =
            '${_detailedAddressController.text.trim()}, $_selectedBarangay, $_selectedMunicipality, Bulacan';

        // Add additional user data to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'firstName': _firstNameController.text.trim(),
              'lastName': _lastNameController.text.trim(),
              'email': _emailController.text.trim(),
              'contactNo': _contactNumberController.text.trim(),
              'address': fullAddress, // Use the new combined address here
              'role': 'user', // Default role for customer app signup
              'createdAt': FieldValue.serverTimestamp(), // Add server timestamp
            });

        // If signup is successful, show a success message and navigate to login
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext dialogContext) {
            return Dialog(
              backgroundColor: const Color(0xFFC09B6A),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Message',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Registration Successful',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your account has been created! Please check your email for verification.',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        // Navigate back to the login screen after the modal is closed
        Navigator.pop(context);
      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'weak-password') {
          message = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          message = 'The account already exists for that email.';
        } else if (e.code == 'invalid-email') {
          message = 'The email address is not valid.';
        } else {
          message =
              e.message ?? 'An unknown error occurred during registration.';
        }
        showCustomModal(context, 'Registration Failed', message);
      } catch (e) {
        showCustomModal(
          context,
          'Error',
          'An unexpected error occurred: ${e.toString()}',
        );
      } finally {
        setState(() {
          _isLoading = false; // Hide loading indicator
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'FURRY TAILS',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD166),
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        blurRadius: 2,
                        color: Colors.black26,
                        offset: Offset(1, 2),
                      ),
                    ],
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'MEYCAUAYAN',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 350,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB74D),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Create Your Account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            hintText: 'First Name',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your first name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            hintText: 'Last Name',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your last name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters long';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Confirm Password',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _contactNumberController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'Contact Number',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your contact number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Dropdown for City/Municipality
                        DropdownButtonFormField<String>(
                          value: _selectedMunicipality,
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedMunicipality = newValue;
                              _selectedBarangay =
                                  null; // Reset barangay when municipality changes
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select your city or municipality';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Select City/Municipality',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: bulacanMunicipalities
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              })
                              .toList(),
                        ),

                        const SizedBox(height: 12),

                        // Dropdown for Barangays
                        DropdownButtonFormField<String>(
                          value: _selectedBarangay,
                          onChanged: _selectedMunicipality == null
                              ? null // Disable if no municipality is selected
                              : (String? newValue) {
                                  setState(() {
                                    _selectedBarangay = newValue;
                                  });
                                },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select your barangay';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Select Barangay',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items:
                              _barangays[_selectedMunicipality]
                                  ?.map<DropdownMenuItem<String>>((
                                    String value,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  })
                                  .toList() ??
                              [], // Show an empty list if no municipality is selected
                        ),

                        const SizedBox(height: 12),

                        // New TextFormField for detailed street, house #, etc.
                        TextFormField(
                          controller: _detailedAddressController,
                          decoration: InputDecoration(
                            hintText: 'Street, House #, etc.',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          maxLines:
                              2, // Allow multiple lines for detailed address
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your detailed address';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _signUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFA6763C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(fontSize: 18),
                                  ),
                                  child: const Text('Sign Up'),
                                ),
                              ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Already have an account? Login',
                            style: TextStyle(
                              color: Colors.black,
                              decoration: TextDecoration.underline,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable custom modal function
void showCustomModal(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: const Color(0xFFC09B6A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Align(
                alignment: Alignment.topLeft,
                child: Text(
                  'Message',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(fontSize: 16, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
