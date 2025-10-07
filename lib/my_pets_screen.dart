// my_pets_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MyPetsScreen extends StatefulWidget {
  final bool isModal;
  const MyPetsScreen({Key? key, this.isModal = false}) : super(key: key);

  @override
  State<MyPetsScreen> createState() => _MyPetsScreenState();
}

class _MyPetsScreenState extends State<MyPetsScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  User? _currentUser;
  bool _showRegistrationForm = false;
  DocumentSnapshot? _editingPet;
  bool _isLoadingForm = false;

  final TextEditingController _petNameController = TextEditingController();
  final TextEditingController _petBreedController = TextEditingController();
  final TextEditingController _petWeightController = TextEditingController();
  final TextEditingController _petBirthdateController = TextEditingController();
  // NOTE: FoodBrandController is no longer used for the Dropdown VALUE, but we keep it
  // for potential 'Other' food brand text input if you implement that later.
  final TextEditingController _foodBrandController = TextEditingController();
  final TextEditingController _numberOfMealsController =
      TextEditingController();
  bool _morningFeeding = false;
  TextEditingController _morningTimeController = TextEditingController();
  bool _afternoonFeeding = false;
  TextEditingController _afternoonTimeController = TextEditingController();
  bool _eveningFeeding = false;
  TextEditingController _eveningTimeController = TextEditingController();

  final TextEditingController _morningFoodGramsController =
      TextEditingController();
  final TextEditingController _afternoonFoodGramsController =
      TextEditingController();
  final TextEditingController _eveningFoodGramsController =
      TextEditingController();

  bool _bringOwnFood = false;

  File? _vaccinationRecordImageFile;
  File? _petProfileImageFile;

  String? _vaccinationRecordImageUrl;
  String? _petProfileImageUrl;

  // State variables for Dropdown values
  String? _selectedPetType;
  String? _selectedGender;
  String? _selectedCageType;
  String? _selectedFoodBrand; // <-- NEW STATE VARIABLE FOR THE FIX

  // Dropdown Item Lists
  final List<String> _petTypes = ['Dog', 'Cat'];
  final List<String> _genders = ['Male', 'Female'];
  final List<String> _cageTypes = ['Small Kennel', 'Large Kennel'];
  // ADDED 'Premium' to the list to match the value causing the assertion error
  final List<String> _foodBrands = [
    'Puppy Kibble',
    'Pedigree',
    'Royal Canin',
    'Acana',
    'Premium',
    'Other',
  ];

  static const String CLOUDINARY_CLOUD_NAME = 'dlec25zve';
  static const String CLOUDINARY_UPLOAD_PRESET = 'pet_photo_preset';

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

  @override
  void dispose() {
    _petNameController.dispose();
    _petBreedController.dispose();
    _petWeightController.dispose();
    _petBirthdateController.dispose();
    _foodBrandController.dispose();
    _numberOfMealsController.dispose();
    _morningTimeController.dispose();
    _afternoonTimeController.dispose();
    _eveningTimeController.dispose();
    _morningFoodGramsController.dispose();
    _afternoonFoodGramsController.dispose();
    _eveningFoodGramsController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _petNameController.clear();
    _petBreedController.clear();
    _petWeightController.clear();
    _petBirthdateController.clear();
    _foodBrandController.clear();
    _numberOfMealsController.clear();
    _morningTimeController.clear();
    _afternoonTimeController.clear();
    _eveningTimeController.clear();
    _morningFoodGramsController.clear();
    _afternoonFoodGramsController.clear();
    _eveningFoodGramsController.clear();

    setState(() {
      _selectedPetType = null;
      _selectedGender = null;
      _selectedCageType = null;
      _selectedFoodBrand = null; // <-- CLEAR NEW STATE
      _morningFeeding = false;
      _afternoonFeeding = false;
      _eveningFeeding = false;
      _bringOwnFood = false;
      _vaccinationRecordImageFile = null;
      _petProfileImageFile = null;
      _vaccinationRecordImageUrl = null;
      _petProfileImageUrl = null;
      _editingPet = null;
      _showRegistrationForm = false;
    });
  }

  void _prefillFormForEdit(DocumentSnapshot petDoc) {
    _editingPet = petDoc;
    final petData = petDoc.data() as Map<String, dynamic>;

    _petNameController.text = petData['petName'] ?? '';
    _petBreedController.text = petData['petBreed'] ?? '';
    _petWeightController.text = petData['petWeight'] ?? '';
    _petBirthdateController.text = petData['dateOfBirth'] ?? '';
    _foodBrandController.text =
        petData['foodBrand'] ?? ''; // Keep for reference
    _numberOfMealsController.text = petData['numberOfMeals'] ?? '';
    _morningTimeController.text = petData['morningTime'] ?? '';
    _afternoonTimeController.text = petData['afternoonTime'] ?? '';
    _eveningTimeController.text = petData['eveningTime'] ?? '';
    _morningFoodGramsController.text = petData['morningFoodGrams'] ?? '';
    _afternoonFoodGramsController.text = petData['afternoonFoodGrams'] ?? '';
    _eveningFoodGramsController.text = petData['eveningFoodGrams'] ?? '';

    setState(() {
      _selectedPetType = _petTypes.contains(petData['petType'])
          ? petData['petType']
          : null;
      _selectedGender = _genders.contains(petData['petGender'])
          ? petData['petGender']
          : null;
      _selectedCageType = _cageTypes.contains(petData['cageType'])
          ? petData['cageType']
          : null;
      // FIX: Set the new state variable correctly
      _selectedFoodBrand = _foodBrands.contains(petData['foodBrand'])
          ? petData['foodBrand'] as String?
          : petData['foodBrand']
                as String?; // Allow existing value even if not in the new list

      _morningFeeding = petData['morningFeeding'] ?? false;
      _afternoonFeeding = petData['afternoonFeeding'] ?? false;
      _eveningFeeding = petData['eveningFeeding'] ?? false;
      _bringOwnFood = petData['bringOwnFood'] ?? false;

      _vaccinationRecordImageUrl = petData['vaccinationRecordImageUrl'];
      _petProfileImageUrl = petData['petProfileImageUrl'];
      _vaccinationRecordImageFile = null;
      _petProfileImageFile = null;

      _showRegistrationForm = true;
    });
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        controller.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  Future<void> _selectTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  // Helper method to pick image
  Future<void> _pickImage(
    Function(File?) onPicked,
    BuildContext context,
  ) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      if (mounted) {
        onPicked(File(pickedFile.path));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image selected.')));
      }
    }
  }

  // Method to upload image to Cloudinary
  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    if (CLOUDINARY_CLOUD_NAME == 'YOUR_ACTUAL_CLOUD_NAME' ||
        CLOUDINARY_UPLOAD_PRESET == 'YOUR_UNSIGNED_UPLOAD_PRESET_NAME') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cloudinary credentials not set up. Please update CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET in my_pets_screen.dart.',
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
        return result['secure_url'];
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
          SnackBar(content: Text('Error uploading to Cloudinary: $e')),
        );
      }
      return null;
    }
  }

  void _submitPetForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingForm = true;
    });

    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in. Please log in to manage pets.'),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _isLoadingForm = false;
      });
      return;
    }

    try {
      if (_numberOfMealsController.text.isNotEmpty &&
          int.tryParse(_numberOfMealsController.text) == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Number of Meals per day must be a valid number, or left empty.',
              ),
            ),
          );
        }
        if (!mounted) return;
        setState(() {
          _isLoadingForm = false;
        });
        return;
      }

      if (_morningFeeding &&
          _morningFoodGramsController.text.isNotEmpty &&
          double.tryParse(_morningFoodGramsController.text) == null) {
        _showSnackBar('Morning food grams must be a valid number.');
        setState(() {
          _isLoadingForm = false;
        });
        return;
      }
      if (_afternoonFeeding &&
          _afternoonFoodGramsController.text.isNotEmpty &&
          double.tryParse(_afternoonFoodGramsController.text) == null) {
        _showSnackBar('Afternoon food grams must be a valid number.');
        setState(() {
          _isLoadingForm = false;
        });
        return;
      }
      if (_eveningFeeding &&
          _eveningFoodGramsController.text.isNotEmpty &&
          double.tryParse(_eveningFoodGramsController.text) == null) {
        _showSnackBar('Evening food grams must be a valid number.');
        setState(() {
          _isLoadingForm = false;
        });
        return;
      }

      // Handle Vaccination Record Image Upload
      String? finalVaccinationRecordImageUrl = _vaccinationRecordImageUrl;
      if (_vaccinationRecordImageFile != null) {
        final uploadedUrl = await _uploadImageToCloudinary(
          _vaccinationRecordImageFile!,
        );
        if (uploadedUrl != null) {
          finalVaccinationRecordImageUrl = uploadedUrl;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload vaccination record image.'),
              ),
            );
          }
          finalVaccinationRecordImageUrl = _vaccinationRecordImageUrl;
        }
      }

      // Handle Pet Profile Image Upload
      String? finalPetProfileImageUrl = _petProfileImageUrl;
      if (_petProfileImageFile != null) {
        final uploadedUrl = await _uploadImageToCloudinary(
          _petProfileImageFile!,
        );
        if (uploadedUrl != null) {
          finalPetProfileImageUrl = uploadedUrl;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload pet profile image.'),
              ),
            );
          }
          finalPetProfileImageUrl = _petProfileImageUrl;
        }
      }

      final Map<String, dynamic> petData = {
        'ownerUserId': currentUser.uid,
        'petName': _petNameController.text.trim(),
        'petType': _selectedPetType,
        'petBreed': _petBreedController.text.trim(),
        'petWeight': _petWeightController.text.trim(),
        'dateOfBirth': _petBirthdateController.text.trim(),
        'petGender': _selectedGender,
        'cageType': _selectedCageType,
        'foodBrand': _selectedFoodBrand, // <-- USE NEW STATE VARIABLE
        'numberOfMeals': _numberOfMealsController.text.trim(),
        'bringOwnFood': _bringOwnFood,
        'morningFeeding': _morningFeeding,
        'morningTime': _morningTimeController.text.trim(),
        'morningFoodGrams': _morningFeeding
            ? _morningFoodGramsController.text.trim()
            : '',
        'afternoonFeeding': _afternoonFeeding,
        'afternoonTime': _afternoonTimeController.text.trim(),
        'afternoonFoodGrams': _afternoonFeeding
            ? _afternoonFoodGramsController.text.trim()
            : '',
        'eveningFeeding': _eveningFeeding,
        'eveningTime': _eveningTimeController.text.trim(),
        'eveningFoodGrams': _eveningFeeding
            ? _eveningFoodGramsController.text.trim()
            : '',
        'vaccinationRecordImageUrl': finalVaccinationRecordImageUrl,
        'petProfileImageUrl': finalPetProfileImageUrl,
      };

      if (_editingPet == null) {
        petData['registeredAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('petsp').add(petData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet registered successfully!')),
          );
        }
      } else {
        await _firestore
            .collection('petsp')
            .doc(_editingPet!.id)
            .update(petData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet updated successfully!')),
          );
        }
      }

      _clearForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save pet: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingForm = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int? maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB74D)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
      validator: validator,
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB74D)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
      onTap: () => _selectDate(context, controller),
      validator: validator,
    );
  }

  Widget _buildTimeField(
    BuildContext context,
    TextEditingController controller,
    String labelText,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB74D)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
      onTap: () => _selectTime(context, controller),
    );
  }

  // NEW: _buildFoodGramsField widget
  Widget _buildFoodGramsField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.number,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB74D)),
        suffixText: 'grams',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required String labelText,
    required IconData icon,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((String item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB74D)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
      validator: validator,
    );
  }

  Widget _buildCheckboxField(
    String title,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return CheckboxListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.deepPurple,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple.shade700,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showAppBar = !widget.isModal;

    if (_currentUser == null) {
      if (showAppBar) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('My Pets'),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Please log in to manage your pet profiles.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          ),
        );
      } else {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Please log in to manage your pet profiles.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
        );
      }
    }

    final Widget mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('petsp')
              .where('ownerUserId', isEqualTo: _currentUser!.uid)
              .orderBy('registeredAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            bool hasRegisteredPets =
                snapshot.hasData && snapshot.data!.docs.isNotEmpty;

            if (_showRegistrationForm) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _clearForm,
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else if (!hasRegisteredPets) {
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pets_outlined,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No pet profiles found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Tap "Add New Pet" to register your furry friend!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _clearForm();
                            _showRegistrationForm = true;
                          });
                        },
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                        label: const Text(
                          'Add New Pet',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _clearForm();
                        _showRegistrationForm = true;
                      });
                    },
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                    label: const Text(
                      'Add New Pet',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              );
            }
          },
        ),
        if (_showRegistrationForm)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildSectionTitle(
                      _editingPet == null
                          ? 'Register New Pet'
                          : 'Edit Pet Profile',
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.orange.shade100,
                            backgroundImage: _petProfileImageFile != null
                                ? FileImage(_petProfileImageFile!)
                                      as ImageProvider
                                : (_petProfileImageUrl != null &&
                                              _petProfileImageUrl!.isNotEmpty
                                          ? NetworkImage(_petProfileImageUrl!)
                                          : null)
                                      as ImageProvider?,
                            child:
                                _petProfileImageFile == null &&
                                    (_petProfileImageUrl == null ||
                                        _petProfileImageUrl!.isEmpty)
                                ? Icon(
                                    Icons.pets,
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
                                  Icons.camera_alt,
                                  color: Colors.white,
                                ),
                                onPressed: () => _pickImage(
                                  (file) => setState(() {
                                    _petProfileImageFile = file;
                                    _petProfileImageUrl = null;
                                  }),
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _petNameController,
                      labelText: 'Pet Name',
                      icon: Icons.pets,
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter pet name' : null,
                    ),
                    const SizedBox(height: 10),
                    _buildDropdownField(
                      value: _selectedPetType,
                      items: _petTypes,
                      labelText: 'Pet Type',
                      icon: Icons.category,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedPetType = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select pet type' : null,
                    ),
                    const SizedBox(height: 10),
                    _buildDropdownField(
                      value: _selectedGender,
                      items: _genders,
                      labelText: 'Pet Gender',
                      icon: Icons.transgender,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedGender = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select pet gender' : null,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _petBreedController,
                      labelText: 'Pet Breed',
                      icon: Icons.merge_type,
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter pet breed' : null,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _petWeightController,
                      labelText: 'Pet Weight (kg)',
                      icon: Icons.monitor_weight,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.isEmpty) return 'Please enter pet weight';
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildDateField(
                      context,
                      controller: _petBirthdateController,
                      labelText: 'Date of Birth',
                      icon: Icons.calendar_today,
                      validator: (value) =>
                          value!.isEmpty ? 'Please select pet birthdate' : null,
                    ),
                    const SizedBox(height: 10),
                    _buildDropdownField(
                      value: _selectedCageType,
                      items: _cageTypes,
                      labelText: 'Cage Type',
                      icon: Icons.home,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCageType = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select cage type' : null,
                    ),
                    const SizedBox(height: 20),
                    // Vaccination status banner
                    Builder(
                      builder: (context) {
                        final bool isVaccinated =
                            (_vaccinationRecordImageFile != null) ||
                            (_vaccinationRecordImageUrl != null &&
                                _vaccinationRecordImageUrl!.isNotEmpty);
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isVaccinated ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isVaccinated ? Icons.verified : Icons.warning,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isVaccinated
                                    ? 'Vaccinated (Record Provided)'
                                    : 'Not Vaccinated (No Record)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    _buildSectionTitle('Vaccination Record (Optional)'),
                    const SizedBox(height: 10),
                    Center(
                      child: Column(
                        children: [
                          if (_vaccinationRecordImageFile != null)
                            Stack(
                              children: [
                                Container(
                                  height: 150,
                                  width: 150,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: FileImage(
                                        _vaccinationRecordImageFile!,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 5,
                                  right: 5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _vaccinationRecordImageFile = null;
                                          _vaccinationRecordImageUrl = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else if (_vaccinationRecordImageUrl != null &&
                              _vaccinationRecordImageUrl!.isNotEmpty)
                            Stack(
                              children: [
                                Container(
                                  height: 150,
                                  width: 150,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: NetworkImage(
                                        _vaccinationRecordImageUrl!,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 5,
                                  right: 5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _vaccinationRecordImageUrl = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            const Text('No vaccination record image selected.'),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(
                              (file) => setState(() {
                                _vaccinationRecordImageFile = file;
                                _vaccinationRecordImageUrl = null;
                              }),
                              context,
                            ),
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload Vaccination Record'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('Feeding Details (Optional)'),
                    const SizedBox(height: 10),
                    // FIX START: Replacing the problematic DropdownButtonFormField
                    _buildDropdownField(
                      value: _selectedFoodBrand,
                      items: _foodBrands,
                      labelText: 'Preferred Food Brand',
                      icon: Icons.fastfood,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedFoodBrand = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a food brand' : null,
                    ),
                    // FIX END
                    const SizedBox(height: 10),
                    _buildCheckboxField(
                      'I will bring my pet\'s own food',
                      _bringOwnFood,
                      (bool? newValue) {
                        setState(() {
                          _bringOwnFood = newValue ?? false;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _numberOfMealsController,
                      labelText: 'Number of Meals per day',
                      icon: Icons.format_list_numbered,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.isNotEmpty &&
                            double.tryParse(value) == null) {
                          return 'Please enter a valid number, or leave empty.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildCheckboxField('Morning Feeding', _morningFeeding, (
                      bool? newValue,
                    ) {
                      setState(() {
                        _morningFeeding = newValue!;
                      });
                    }),
                    if (_morningFeeding) ...[
                      _buildTimeField(
                        context,
                        _morningTimeController,
                        'Morning Time',
                        Icons.access_time,
                      ),
                      const SizedBox(height: 10),
                      _buildFoodGramsField(
                        controller: _morningFoodGramsController,
                        labelText: 'Morning Food Grams',
                        icon: Icons.scale,
                        validator: (value) {
                          if (value!.isNotEmpty &&
                              double.tryParse(value) == null) {
                            return 'Please enter a valid number.';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildCheckboxField(
                      'Afternoon Feeding',
                      _afternoonFeeding,
                      (bool? newValue) {
                        setState(() {
                          _afternoonFeeding = newValue!;
                        });
                      },
                    ),
                    if (_afternoonFeeding) ...[
                      _buildTimeField(
                        context,
                        _afternoonTimeController,
                        'Afternoon Time',
                        Icons.access_time,
                      ),
                      const SizedBox(height: 10),
                      _buildFoodGramsField(
                        controller: _afternoonFoodGramsController,
                        labelText: 'Afternoon Food Grams',
                        icon: Icons.scale,
                        validator: (value) {
                          if (value!.isNotEmpty &&
                              double.tryParse(value) == null) {
                            return 'Please enter a valid number.';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildCheckboxField('Evening Feeding', _eveningFeeding, (
                      bool? newValue,
                    ) {
                      setState(() {
                        _eveningFeeding = newValue!;
                      });
                    }),
                    if (_eveningFeeding) ...[
                      _buildTimeField(
                        context,
                        _eveningTimeController,
                        'Evening Time',
                        Icons.access_time,
                      ),
                      const SizedBox(height: 10),
                      _buildFoodGramsField(
                        controller: _eveningFoodGramsController,
                        labelText: 'Evening Food Grams',
                        icon: Icons.scale,
                        validator: (value) {
                          if (value!.isNotEmpty &&
                              double.tryParse(value) == null) {
                            return 'Please enter a valid number.';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 30),
                    Center(
                      child: _isLoadingForm
                          ? const CircularProgressIndicator(
                              color: Colors.deepPurple,
                            )
                          : ElevatedButton(
                              onPressed: _submitPetForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 50,
                                  vertical: 15,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _editingPet == null
                                    ? 'Register Pet'
                                    : 'Update Pet',
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('petsp')
                  .where('ownerUserId', isEqualTo: _currentUser!.uid)
                  .orderBy('registeredAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                bool hasRegisteredPets =
                    snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                if (!hasRegisteredPets) {
                  return const SizedBox.shrink();
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var petDoc = snapshot.data!.docs[index];
                    var petData = petDoc.data() as Map<String, dynamic>;

                    final String petName =
                        petData['petName'] as String? ?? 'N/A';
                    final String petType =
                        petData['petType'] as String? ?? 'N/A';
                    final String petBreed =
                        petData['petBreed'] as String? ?? 'N/A';
                    final String petGender =
                        petData['petGender'] as String? ?? 'N/A';
                    final String petWeight =
                        petData['petWeight'] as String? ?? 'N/A';
                    final String petDob =
                        petData['dateOfBirth'] as String? ?? 'N/A';
                    final String cageType =
                        petData['cageType'] as String? ?? 'N/A';
                    final String foodBrand =
                        petData['foodBrand'] as String? ?? 'N/A';
                    final String numberOfMeals =
                        petData['numberOfMeals'] as String? ?? 'N/A';
                    final bool morningFeeding =
                        petData['morningFeeding'] as bool? ?? false;
                    final String morningTime =
                        petData['morningTime'] as String? ?? 'N/A';
                    final String morningFoodGrams =
                        petData['morningFoodGrams'] as String? ?? 'N/A';
                    final bool afternoonFeeding =
                        petData['afternoonFeeding'] as bool? ?? false;
                    final String afternoonTime =
                        petData['afternoonTime'] as String? ?? 'N/A';
                    final String afternoonFoodGrams =
                        petData['afternoonFoodGrams'] as String? ?? 'N/A';
                    final bool eveningFeeding =
                        petData['eveningFeeding'] as bool? ?? false;
                    final String eveningTime =
                        petData['eveningTime'] as String? ?? 'N/A';
                    final String eveningFoodGrams =
                        petData['eveningFoodGrams'] as String? ?? 'N/A';

                    final String vaccinationRecordImageUrl =
                        petData['vaccinationRecordImageUrl'] as String? ?? '';
                    final String petProfileImageUrl =
                        petData['petProfileImageUrl'] as String? ?? '';

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
                        onTap: () {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Viewing details for $petName'),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.deepPurple.shade100,
                                    backgroundImage:
                                        petProfileImageUrl.isNotEmpty
                                        ? NetworkImage(petProfileImageUrl)
                                        : null,
                                    child: petProfileImageUrl.isEmpty
                                        ? Icon(
                                            Icons.pets_rounded,
                                            color: Colors.deepPurple.shade700,
                                            size: 30,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          petName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '$petType - $petBreed',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color: Colors.blueGrey.shade600,
                                    ),
                                    onPressed: () {
                                      _prefillFormForEdit(petDoc);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      final bool?
                                      confirmDelete = await showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text(
                                            'Delete Pet Profile?',
                                          ),
                                          content: Text(
                                            'Are you sure you want to delete $petName\'s profile? This action cannot be undone.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              child: const Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmDelete == true) {
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('petsp')
                                              .doc(petDoc.id)
                                              .delete();
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${petName} deleted successfully!',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to delete ${petName}: ${e.toString()}',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
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
    );

    if (showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Pets'),
          backgroundColor: const Color(0xFFFFB64A),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: mainContent,
      );
    } else {
      return mainContent;
    }
  }
}
