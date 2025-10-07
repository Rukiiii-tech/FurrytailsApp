import 'package:customerap/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // REMOVE: No longer using Firebase Storage for images
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http; // ADDED: For Cloudinary upload
import 'dart:convert'; // ADDED: For JSON encoding/decoding

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseStorage _storage = FirebaseStorage.instance; // REMOVE: No longer using Firebase Storage
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  File? _profileImageFile; // This will hold the picked image file temporarily
  String?
  _profileImageUrl; // This will hold the URL from Firestore or after upload

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  User? _currentUser;

  // Cloudinary Configuration (from my_pets_screen.dart and your request)
  static const String CLOUDINARY_CLOUD_NAME = 'dlec25zve';
  static const String CLOUDINARY_UPLOAD_PRESET = 'pet_photo_preset';

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    _contactNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Helper method to pick an image (consistent with my_pets_screen.dart)
  Future<void> _pickImage({required Function(File?) onPicked}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75, // Compress image for faster upload and smaller size
      );
      if (!mounted) return;
      if (pickedFile != null) {
        onPicked(File(pickedFile.path));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image selected.')));
        onPicked(null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
      onPicked(null);
    }
  }

  // Method to upload the image to Cloudinary (consistent with my_pets_screen.dart)
  Future<String?> _uploadImageToCloudinary(File? imageFile) async {
    if (imageFile == null) {
      return null;
    }

    if (CLOUDINARY_CLOUD_NAME == 'YOUR_ACTUAL_CLOUD_NAME' ||
        CLOUDINARY_UPLOAD_PRESET == 'YOUR_UNSIGNED_UPLOAD_PRESET_NAME') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cloudinary credentials not set up. Please update CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET.',
            ),
          ),
        );
      }
      return null;
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final result = jsonDecode(utf8.decode(responseData));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image uploaded successfully!'),
            ),
          );
        }
        return result['secure_url']; // This is the public URL
      } else {
        final responseData = await response.stream.bytesToString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cloudinary upload failed: ${response.statusCode}, ${responseData}',
              ),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image to Cloudinary: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _fetchUserProfile() async {
    if (_currentUser != null) {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      try {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _firstNameController.text = userData['firstName'] ?? '';
              _lastNameController.text = userData['lastName'] ?? '';
              _emailController.text = userData['email'] ?? '';
              _contactNumberController.text = userData['contactNo'] ?? '';
              _addressController.text = userData['address'] ?? '';
              _profileImageUrl = userData['profileImageUrl']; // Fetch the URL
              _profileImageFile =
                  null; // Clear any temporarily picked file if fetching from Firestore
            });
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _updateUserProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not logged in.')));
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // 1. Upload new profile image if _profileImageFile is set
      String? finalProfileImageUrl;
      if (_profileImageFile != null) {
        // If a new file is selected, upload it
        finalProfileImageUrl = await _uploadImageToCloudinary(
          _profileImageFile,
        );
        if (finalProfileImageUrl == null) {
          // If upload failed, stop the update process
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      } else {
        // If no new file is selected, keep the existing _profileImageUrl (which could be null)
        finalProfileImageUrl = _profileImageUrl;
      }

      // 2. Update email if changed
      if (_emailController.text.trim() != _currentUser!.email) {
        try {
          await _currentUser!.updateEmail(_emailController.text.trim());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email updated successfully!')),
            );
          }
        } on FirebaseAuthException catch (e) {
          String errorMessage = 'Failed to update email. Please try again.';
          if (e.code == 'requires-recent-login') {
            errorMessage =
                'Email update requires recent login. Please log out and back in, then try again.';
          } else if (e.code == 'invalid-email') {
            errorMessage = 'The email address is invalid.';
          } else if (e.code == 'email-already-in-use') {
            errorMessage =
                'The email address is already in use by another account.';
          }
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(errorMessage)));
          }
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      }

      // 3. Handle password change if new password fields are filled
      if (_newPasswordController.text.isNotEmpty) {
        if (_newPasswordController.text != _confirmNewPasswordController.text) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('New passwords do not match.')),
            );
          }
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }

        String? currentPassword = await _promptForCurrentPassword();
        if (currentPassword == null || currentPassword.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Current password is required to change password.',
                ),
              ),
            );
          }
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }

        try {
          AuthCredential credential = EmailAuthProvider.credential(
            email: _currentUser!.email!,
            password: currentPassword,
          );
          await _currentUser!.reauthenticateWithCredential(credential);

          await _currentUser!.updatePassword(
            _newPasswordController.text.trim(),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password updated successfully!')),
            );
          }
          _newPasswordController.clear();
          _confirmNewPasswordController.clear();
        } on FirebaseAuthException catch (e) {
          String errorMessage = 'Failed to change password. Please try again.';
          if (e.code == 'wrong-password') {
            errorMessage =
                'Incorrect current password provided for re-authentication.';
          } else if (e.code == 'weak-password') {
            errorMessage = 'The new password is too weak.';
          } else if (e.code == 'requires-recent-login') {
            errorMessage =
                'Password update requires recent login. Please log out and back in, then try again.';
          }
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(errorMessage)));
          }
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      }

      // 4. Update Firestore document for other profile details
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'contactNo': _contactNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'profileImageUrl':
            finalProfileImageUrl, // Store the uploaded URL or existing URL
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile details updated successfully!'),
          ),
        );
      }
      _fetchUserProfile(); // Refresh profile to show new image/data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _promptForCurrentPassword() async {
    final TextEditingController _currentPasswordController =
        TextEditingController();
    String? password;

    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Current Password'),
          content: TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current Password',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Confirm'),
              onPressed: () {
                password = _currentPasswordController.text.trim();
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
    _currentPasswordController.dispose();
    return password;
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.orange.shade100,
                          // Display picked image (highest priority) or fetched URL
                          backgroundImage: _profileImageFile != null
                              ? FileImage(_profileImageFile!) as ImageProvider
                              : (_profileImageUrl != null &&
                                        _profileImageUrl!.isNotEmpty
                                    ? NetworkImage(_profileImageUrl!)
                                    : null),
                          child:
                              _profileImageFile == null &&
                                  (_profileImageUrl == null ||
                                      _profileImageUrl!.isEmpty)
                              ? Icon(
                                  Icons.person,
                                  size: 80,
                                  color: Colors.orange.shade700,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.shade700,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons
                                    .camera_alt, // Changed icon to represent camera/gallery
                                color: Colors.white,
                              ),
                              onPressed: () => _pickImage(
                                // Use the new pickImage with callback
                                onPicked: (file) {
                                  setState(() {
                                    _profileImageFile = file;
                                    // If a new file is picked, clear the old URL from Firestore
                                    if (file != null) {
                                      _profileImageUrl = null;
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        // Optional: Add a clear button for the image if _profileImageFile or _profileImageUrl exists
                        if (_profileImageFile != null ||
                            (_profileImageUrl != null &&
                                _profileImageUrl!.isNotEmpty))
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _profileImageFile = null;
                                    _profileImageUrl = null;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile image cleared.'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildProfileInfoField(
                    'First Name',
                    _firstNameController,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'First name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  _buildProfileInfoField(
                    'Last Name',
                    _lastNameController,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Last name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  _buildProfileInfoField(
                    'Email',
                    _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Email is required';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))
                        return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showChangePasswordModal(context),
                      icon: Icon(
                        Icons.lock_outline,
                        color: Colors.orange.shade700,
                      ),
                      label: Text(
                        'Change Password',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildProfileInfoField(
                    'Contact Number',
                    _contactNumberController,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Contact number is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  _buildProfileInfoField(
                    'Address',
                    _addressController,
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Address is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      onPressed: _updateUserProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Update'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        showLogoutModal(context, () async {
                          await _auth.signOut();
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                          }
                        });
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  Widget _buildProfileInfoField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: _getFormFieldDecoration(label),
          style: const TextStyle(fontSize: 16, color: Colors.black54),
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _getFormFieldDecoration(String labelText) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey[200],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
      ),
      contentPadding: const EdgeInsets.all(12),
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.black54),
    );
  }

  void showLogoutModal(BuildContext context, VoidCallback onLogout) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Color(0xFFC09B6A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    'Message',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Are you sure you want to logout?',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        onLogout();
                      },
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangePasswordModal(BuildContext context) {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: _getFormFieldDecoration('Current Password'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: _getFormFieldDecoration('New Password'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: _getFormFieldDecoration('Confirm New Password'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (value != newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            try {
                              AuthCredential credential =
                                  EmailAuthProvider.credential(
                                    email: _currentUser!.email!,
                                    password: currentPasswordController.text,
                                  );
                              await _currentUser!.reauthenticateWithCredential(
                                credential,
                              );

                              await _currentUser!.updatePassword(
                                newPasswordController.text,
                              );

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password updated successfully!',
                                    ),
                                  ),
                                );
                              }
                            } on FirebaseAuthException catch (e) {
                              String message = 'Failed to update password.';
                              if (e.code == 'wrong-password') {
                                message = 'Current password is incorrect.';
                              } else if (e.code == 'weak-password') {
                                message = 'The new password is too weak.';
                              } else if (e.code == 'requires-recent-login') {
                                message =
                                    'Please log out and log in again before changing your password.';
                              }
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Update Password'),
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
  }
}
