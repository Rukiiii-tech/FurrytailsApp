// booking_form_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customerap/booking_details_screen.dart';
import 'package:intl/intl.dart';
import 'package:customerap/my_pets_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BookingFormScreen extends StatefulWidget {
  final String? userEmail;
  final bool isModal;

  const BookingFormScreen({super.key, this.userEmail, this.isModal = false});

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // Cloudinary Configuration (YOUR ACTUAL CREDENTIALS)
  // CLOUD_NAME 'dlec25zve' was confirmed from your previous screenshot.
  // UPLOAD_PRESET 'pet_photo_preset' is the name you created and set to UNSIGNED.
  static const String CLOUDINARY_CLOUD_NAME = 'dlec25zve'; // Your Cloud Name
  static const String CLOUDINARY_UPLOAD_PRESET =
      'pet_photo_preset'; // Your UNSIGNED Upload Preset Name

  // Booking Limit Variables
  final int _bookingLimit = 25;
  int _activeBookingsCount = 0;
  DateTime? _nextAvailableDate;

  // List of registered pets for the dropdown
  List<DocumentSnapshot> _registeredPets = [];
  // List to hold multiple selected pets for this booking
  List<DocumentSnapshot> _selectedPetsToBook = [];
  // NEW: Map to hold editable details for EACH selected pet, keyed by petId
  Map<String, Map<String, dynamic>> _petsBookingDetails = {};
  // NEW: Map to store active booking status for each pet on a specific date (petId -> Map<Date, bool>)
  Map<String, Map<String, bool>> _petDailyBookingStatus = {};

  // Booking Details Controllers and Variables (top-level, apply to all pets in this booking)
  final TextEditingController checkInDateController = TextEditingController();
  final TextEditingController checkOutDateController = TextEditingController();
  final TextEditingController specificTimeController = TextEditingController();
  String? _selectedService;

  // Grooming Specifics
  final TextEditingController groomingCheckInDateController =
      TextEditingController();
  bool _groomingWaiverAgreed = false;

  // Boarding Waiver Specific
  bool _boardingWaiperAgreed = false; // Typo fix: Waiver

  // Payment Details Variables (apply to the entire booking)
  String? _selectedPaymentMethod;
  String? _paymentDetailsText;
  File? _paymentReceiptImage; // Holds the picked payment receipt image
  final TextEditingController referenceNumberController =
      TextEditingController(); // Added for reference number
  final TextEditingController downPaymentAmountController =
      TextEditingController(); // New: Down Payment Amount
  bool _downpaymentAgreementAgreed = false; // New: Non-refundable agreement

  // List of predefined options for dropdowns
  final List<String> _services = ['Boarding', 'Grooming'];
  final List<String> _roomTypes = ['Large Kennel', 'Small Kennel'];
  final List<String> _times = [
    '08:00 AM',
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
  ];

  // Map for payment options
  final Map<String, String> _paymentOptions = {
    'BDO': '0045-7016-1114',
    'BPI': '4639-2142-95',
    'UB': '1094-8006-3874',
    'GCASH': '0997-275-5181',
  };
  final String _accountName = 'ANGELO FIL ZUNIGA';
  final double _minimumDownPayment = 250.0; // Define minimum down payment

  @override
  void initState() {
    super.initState();
    _fetchRegisteredPets();
    _checkBookingAvailability();
  }

  @override
  void dispose() {
    checkInDateController.dispose();
    checkOutDateController.dispose();
    specificTimeController.dispose();
    groomingCheckInDateController.dispose();
    referenceNumberController.dispose(); // Dispose the new controller
    downPaymentAmountController.dispose(); // Dispose the new controller

    // Dispose all TextEditingControllers created for pet-specific details
    _petsBookingDetails.values.forEach((petDetails) {
      (petDetails['morningFoodGramsController'] as TextEditingController?)
          ?.dispose();
      (petDetails['afternoonFoodGramsController'] as TextEditingController?)
          ?.dispose();
      (petDetails['eveningFoodGramsController'] as TextEditingController?)
          ?.dispose();
    });
    super.dispose();
  }

  void _clearPetDetails() {
    setState(() {
      _selectedPetsToBook.clear();
      _petsBookingDetails.clear();
      _paymentReceiptImage = null;
      referenceNumberController.clear(); // Clear reference number
      downPaymentAmountController.clear(); // Clear down payment amount
    });
  }

  void _resetGroomingFields() {
    _groomingWaiverAgreed = false;
    groomingCheckInDateController.clear();
  }

  void _resetBoardingFields() {
    checkInDateController.clear();
    checkOutDateController.clear();
    _boardingWaiperAgreed = false; // Typo fix: Waiver
    _selectedPaymentMethod = null;
    _paymentDetailsText = null;
    _paymentReceiptImage = null;
    referenceNumberController.clear(); // Clear reference number
    downPaymentAmountController.clear(); // Clear down payment amount
    _downpaymentAgreementAgreed = false; // Reset agreement
  }

  Future<void> _checkBookingAvailability() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot activeBookingsSnapshot = await _firestore
          .collection('bookings')
          .where('status', whereIn: ['Pending', 'Accepted'])
          .get();

      if (mounted) {
        setState(() {
          _activeBookingsCount = activeBookingsSnapshot.docs.length;

          _petDailyBookingStatus.clear();
          for (var doc in activeBookingsSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final petId = data['petInformation']?['petId'];
            final bookingDate = data['date'];

            if (petId != null && bookingDate != null) {
              if (!_petDailyBookingStatus.containsKey(petId)) {
                _petDailyBookingStatus[petId] = {};
              }
              _petDailyBookingStatus[petId]![bookingDate as String] = true;
            }
          }

          DateTime? earliestCheckout;
          for (var doc in activeBookingsSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['serviceType'] == 'Boarding' &&
                data['boardingDetails'] != null) {
              String? checkOutDateStr = data['boardingDetails']['checkOutDate'];
              if (checkOutDateStr != null && checkOutDateStr.isNotEmpty) {
                try {
                  DateTime checkout = DateTime.parse(checkOutDateStr);
                  if (earliestCheckout == null ||
                      checkout.isBefore(earliestCheckout)) {
                    earliestCheckout = checkout;
                  }
                } catch (e) {
                  print(
                    'Error parsing checkout date from booking: $checkOutDateStr - $e',
                  );
                }
              }
            }
          }
          if (_activeBookingsCount >= _bookingLimit) {
            _nextAvailableDate =
                earliestCheckout != null &&
                    earliestCheckout.isBefore(DateTime.now())
                ? DateTime.now()
                : earliestCheckout;
          } else {
            _nextAvailableDate = null;
          }
          print(
            'DEBUG: _activeBookingsCount from Firestore: $_activeBookingsCount',
          );
          print('DEBUG: _petDailyBookingStatus: $_petDailyBookingStatus');
          print(
            'DEBUG: _nextAvailableDate (if capacity full): $_nextAvailableDate',
          );
          print(
            'DEBUG: UI Condition for "Capacity Reached": ${_activeBookingsCount >= _bookingLimit && (_nextAvailableDate == null || _nextAvailableDate!.isAfter(DateTime.now()))}',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error checking booking availability: ${e.toString()}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchRegisteredPets() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to fetch your pets.')),
        );
      }
      return;
    }

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('petsp')
          .where('ownerUserId', isEqualTo: currentUser.uid)
          .get();

      if (mounted) {
        setState(() {
          _registeredPets = snapshot.docs;
          final List<DocumentSnapshot> newSelectedPetsToBook = [];
          final Map<String, Map<String, dynamic>> newPetsBookingDetails = {};

          for (var petDoc in _selectedPetsToBook) {
            final foundPet = _registeredPets.firstWhere(
              (doc) => doc.id == petDoc.id,
              orElse: () => null as DocumentSnapshot,
            );

            if (foundPet != null) {
              newSelectedPetsToBook.add(foundPet);
              // Pass existing details to preserve controller instances
              newPetsBookingDetails[foundPet.id] = _initializePetBookingDetails(
                foundPet,
                _petsBookingDetails[foundPet.id],
              );
            }
          }

          // Dispose controllers for pets no longer selected
          _petsBookingDetails.forEach((petId, details) {
            if (!newPetsBookingDetails.containsKey(petId)) {
              (details['morningFoodGramsController'] as TextEditingController?)
                  ?.dispose();
              (details['afternoonFoodGramsController']
                      as TextEditingController?)
                  ?.dispose();
              (details['eveningFoodGramsController'] as TextEditingController?)
                  ?.dispose();
            }
          });

          _selectedPetsToBook = newSelectedPetsToBook;
          _petsBookingDetails = newPetsBookingDetails;
        });
        _checkBookingAvailability();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching pets: ${e.toString()}')),
        );
      }
    }
  }

  Map<String, dynamic> _initializePetBookingDetails(
    DocumentSnapshot petDoc, [
    Map<String, dynamic>? existingDetails,
  ]) {
    final petData = petDoc.data() as Map<String, dynamic>;

    // Initialize controllers or reuse existing ones
    final morningController =
        existingDetails?['morningFoodGramsController']
            as TextEditingController? ??
        TextEditingController();
    final afternoonController =
        existingDetails?['afternoonFoodGramsController']
            as TextEditingController? ??
        TextEditingController();
    final eveningController =
        existingDetails?['eveningFoodGramsController']
            as TextEditingController? ??
        TextEditingController();

    // Set initial text for new controllers from existing data or default
    morningController.text =
        (existingDetails?['morningFoodGrams'] ??
                petData['morningFoodGrams'] ??
                '')
            .toString();
    afternoonController.text =
        (existingDetails?['afternoonFoodGrams'] ??
                petData['afternoonFoodGrams'] ??
                '')
            .toString();
    eveningController.text =
        (existingDetails?['eveningFoodGrams'] ??
                petData['eveningFoodGrams'] ??
                '')
            .toString();

    // Add listeners to update the map whenever controller text changes
    morningController.addListener(() {
      _petsBookingDetails[petDoc.id]?['morningFoodGrams'] =
          morningController.text;
    });
    afternoonController.addListener(() {
      _petsBookingDetails[petDoc.id]?['afternoonFoodGrams'] =
          afternoonController.text;
    });
    eveningController.addListener(() {
      _petsBookingDetails[petDoc.id]?['eveningFoodGrams'] =
          eveningController.text;
    });

    return {
      'petName': petData['petName'] ?? '',
      'petType': petData['petType'] ?? '',
      'petBreed': petData['petBreed'] ?? '',
      'petGender': petData['petGender'] ?? '',
      'petWeight': petData['petWeight']?.toString() ?? '',
      'dateOfBirth': petData['dateOfBirth'] ?? '',
      'petProfileImageUrl': petData['petProfileImageUrl'] ?? '',
      'vaccinationRecordImageUrlFromProfile':
          petData['vaccinationRecordImageUrl'] ?? '',
      'foodBrand': petData['foodBrand'] ?? '',
      'numberOfMeals': petData['numberOfMeals']?.toString() ?? '',
      'morningFeeding': petData['morningFeeding'] ?? false,
      'morningTime': petData['morningTime'] ?? '',
      'afternoonFeeding': petData['afternoonFeeding'] ?? false,
      'afternoonTime': petData['afternoonTime'] ?? '',
      'eveningFeeding': petData['eveningFeeding'] ?? false,
      'eveningTime': petData['eveningTime'] ?? '',
      'selectedRoomType': petData['cageType'],
      'vaccinationRecordImageFileForBooking': null, // Initialize to null
      'morningFoodGramsController': morningController,
      'afternoonFoodGramsController': afternoonController,
      'eveningFoodGramsController': eveningController,
      // Initial values, will be kept updated by listeners
      'morningFoodGrams':
          existingDetails?['morningFoodGrams'] ??
          petData['morningFoodGrams'] ??
          '',
      'afternoonFoodGrams':
          existingDetails?['afternoonFoodGrams'] ??
          petData['afternoonFoodGrams'] ??
          '',
      'eveningFoodGrams':
          existingDetails?['eveningFoodGrams'] ??
          petData['eveningFoodGrams'] ??
          '',
    };
  }

  Future<void> _pickPaymentReceiptImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _paymentReceiptImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickVaccinationImageForPet(String petId) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _petsBookingDetails[petId]!['vaccinationRecordImageFileForBooking'] =
            File(pickedFile.path);
        // Ensure that if a new file is picked, the old URL from profile is disregarded for this booking instance
        _petsBookingDetails[petId]!['vaccinationRecordImageUrlFromProfile'] =
            null;
      });
    }
  }

  // Generic method to upload a File to Cloudinary
  Future<String?> _uploadImageToCloudinary(File? imageFile) async {
    if (imageFile == null) return null;

    // Added check for Cloudinary credentials
    if (CLOUDINARY_CLOUD_NAME == 'YOUR_ACTUAL_CLOUD_NAME' ||
        CLOUDINARY_UPLOAD_PRESET == 'YOUR_UNSIGNED_UPLOAD_PRESET_NAME') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cloudinary credentials not set up. Please update CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET in booking_form_screen.dart.',
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

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2028),
      );
      if (picked != null) {
        if (!mounted) return;
        setState(() {
          controller.text = DateFormat('yyyy-MM-dd').format(picked);
          _checkBookingAvailability();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open date picker: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _selectBookingTime(
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

  Future<void> _selectTime(
    BuildContext context,
    String petId,
    String timeKey,
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
        // Listener for controller already updates the map, so no need for direct map update here
      });
    }
  }

  void _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all required fields.');
      return;
    }

    if (_selectedPetsToBook.isEmpty) {
      _showSnackBar('Please select at least one pet to book.');
      return;
    }

    await _checkBookingAvailability();
    if (_activeBookingsCount + _selectedPetsToBook.length > _bookingLimit) {
      _showSnackBar(
        'Booking capacity will be exceeded with your selection. Available slots: ${_bookingLimit - _activeBookingsCount}. Please select fewer pets or try a different date.',
      );
      _setLoadingFalseAndReturn();
      return;
    }

    String selectedDateForBooking = '';
    if (_selectedService == 'Boarding') {
      selectedDateForBooking = checkInDateController.text.trim();
    } else if (_selectedService == 'Grooming') {
      selectedDateForBooking = groomingCheckInDateController.text.trim();
    }

    if (selectedDateForBooking.isEmpty) {
      _showSnackBar('Please select a booking date.');
      _setLoadingFalseAndReturn();
      return;
    }

    for (DocumentSnapshot petDoc in _selectedPetsToBook) {
      final petId = petDoc.id;
      final petName = (petDoc.data() as Map<String, dynamic>)['petName'];
      if (_petDailyBookingStatus.containsKey(petId) &&
          _petDailyBookingStatus[petId]!.containsKey(selectedDateForBooking)) {
        _showSnackBar(
          'Pet "${petName}" already has a pending or accepted booking on $selectedDateForBooking.',
        );
        _setLoadingFalseAndReturn();
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showSnackBar('User not logged in. Please log in to book.');
        _setLoadingFalseAndReturn();
        return;
      }

      if (_selectedService == null) {
        _showSnackBar('Please select either Pet Boarding or Pet Grooming.');
        _setLoadingFalseAndReturn();
        return;
      }

      if (_selectedService == 'Grooming' && !_groomingWaiverAgreed) {
        _showSnackBar('Please agree to the Pet Grooming Waiver to proceed.');
        _setLoadingFalseAndReturn();
        return;
      }
      if (_selectedService == 'Boarding' && !_boardingWaiperAgreed) {
        _showSnackBar('Please agree to the Pet Boarding Waiver to proceed.');
        _setLoadingFalseAndReturn();
        return;
      }
      if (_selectedService == 'Boarding' && _selectedPaymentMethod == null) {
        _showSnackBar('Please select a Mode of Payment for boarding.');
        _setLoadingFalseAndReturn();
        return;
      }

      if (_selectedService == 'Boarding') {
        for (DocumentSnapshot petDoc in _selectedPetsToBook) {
          final petId = petDoc.id;
          if (_petsBookingDetails[petId]!['selectedRoomType'] == null) {
            _showSnackBar(
              'Please select a Room Type for ${(_petsBookingDetails[petId]!['petName'] ?? 'a pet')}.',
            );
            _setLoadingFalseAndReturn();
            return;
          }
        }
      }

      if (specificTimeController.text.trim().isEmpty) {
        _showSnackBar('Please select a specific time for the booking.');
        _setLoadingFalseAndReturn();
        return;
      }

      if (_selectedService == 'Grooming' &&
          groomingCheckInDateController.text.trim().isEmpty) {
        _showSnackBar('Please select a check-in date for grooming.');
        _setLoadingFalseAndReturn();
        return;
      }

      if (_selectedService == 'Boarding') {
        if (checkInDateController.text.trim().isEmpty) {
          _showSnackBar('Please select a check-in date for boarding.');
          _setLoadingFalseAndReturn();
          return;
        }
        if (checkOutDateController.text.trim().isEmpty) {
          _showSnackBar('Please select a check-out date for boarding.');
          _setLoadingFalseAndReturn();
          return;
        }
        DateTime checkIn = DateTime.parse(checkInDateController.text);
        DateTime checkOut = DateTime.parse(checkOutDateController.text);
        if (checkOut.isBefore(checkIn)) {
          _showSnackBar('Check-out date cannot be before check-in date.');
          _setLoadingFalseAndReturn();
          return;
        }
        if (_paymentReceiptImage != null &&
            referenceNumberController.text.trim().isEmpty) {
          _showSnackBar('Please enter the reference number for your payment.');
          _setLoadingFalseAndReturn();
          return;
        }
        // Require agreement that down payment is non-refundable
        if (!_downpaymentAgreementAgreed) {
          _showSnackBar(
            'Please agree that the down payment is non-refundable.',
          );
          _setLoadingFalseAndReturn();
          return;
        }
        // Validate down payment amount
        if (double.tryParse(downPaymentAmountController.text.trim()) == null ||
            double.parse(downPaymentAmountController.text.trim()) <
                _minimumDownPayment) {
          _showSnackBar(
            'Please enter a valid down payment amount (minimum ${_minimumDownPayment.toStringAsFixed(0)} Php).',
          );
          _setLoadingFalseAndReturn();
          return;
        }
      }

      final ownerDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final Map<String, dynamic> ownerData =
          (ownerDoc.data() as Map<String, dynamic>?) ?? {};

      final ownerInformation = {
        'lastName': ownerData['lastName'] ?? '',
        'firstName': ownerData['firstName'] ?? '',
        'email': currentUser.email,
        'contactNo': ownerData['contactNo'] ?? '',
        'address': ownerData['address'] ?? '',
      };

      // Upload payment receipt image if available
      String? finalPaymentReceiptImageUrl;
      if (_paymentReceiptImage != null) {
        finalPaymentReceiptImageUrl = await _uploadImageToCloudinary(
          _paymentReceiptImage,
        );
        if (finalPaymentReceiptImageUrl == null) {
          _setLoadingFalseAndReturn();
          return;
        }
      }

      List<String> successfullyBookedIds = [];

      for (DocumentSnapshot petDoc in _selectedPetsToBook) {
        final petId = petDoc.id;
        final Map<String, dynamic> currentPetBookingDetails =
            _petsBookingDetails[petId]!;

        // Upload pet-specific vaccination record image if available for this booking
        String? vaccinationRecordImageUrlForBooking;
        File? petBookingVaccinationFile =
            currentPetBookingDetails['vaccinationRecordImageFileForBooking'];
        if (petBookingVaccinationFile != null) {
          vaccinationRecordImageUrlForBooking = await _uploadImageToCloudinary(
            petBookingVaccinationFile,
          );
          if (vaccinationRecordImageUrlForBooking == null) {
            _setLoadingFalseAndReturn();
            return;
          }
        } else {
          vaccinationRecordImageUrlForBooking =
              currentPetBookingDetails['vaccinationRecordImageUrlFromProfile'];
        }

        final petInformationForBooking = {
          'petId': petId,
          'petName': currentPetBookingDetails['petName'] ?? '',
          'petType': currentPetBookingDetails['petType'] ?? '',
          'petBreed': currentPetBookingDetails['petBreed'] ?? '',
          'petGender': currentPetBookingDetails['petGender'] ?? '',
          'petWeight': currentPetBookingDetails['petWeight']?.toString() ?? '',
          'dateOfBirth': currentPetBookingDetails['dateOfBirth'] ?? '',
          'petProfileImageUrl':
              currentPetBookingDetails['petProfileImageUrl'] ?? '',
        };

        // Extract food grams from the map, which are updated by controller listeners
        final feedingDetailsForBooking = {
          'morningFeeding': currentPetBookingDetails['morningFeeding'] ?? false,
          'morningTime': currentPetBookingDetails['morningTime'] ?? '',
          'morningFoodGrams':
              currentPetBookingDetails['morningFoodGrams'] ??
              '', // Retrieve morning food grams
          'afternoonFeeding':
              currentPetBookingDetails['afternoonFeeding'] ?? false,
          'afternoonTime': currentPetBookingDetails['afternoonTime'] ?? '',
          'afternoonFoodGrams':
              currentPetBookingDetails['afternoonFoodGrams'] ??
              '', // Retrieve afternoon food grams
          'eveningFeeding': currentPetBookingDetails['eveningFeeding'] ?? false,
          'eveningTime': currentPetBookingDetails['eveningTime'] ?? '',
          'eveningFoodGrams':
              currentPetBookingDetails['eveningFoodGrams'] ??
              '', // Retrieve evening food grams
          'foodBrand': currentPetBookingDetails['foodBrand'] ?? '',
          'numberOfMeals':
              currentPetBookingDetails['numberOfMeals']?.toString() ?? '',
        };

        final Map<String, dynamic> bookingData = {
          'userId': currentUser.uid,
          'serviceType': _selectedService,
          'status': 'Pending',
          'timestamp': FieldValue.serverTimestamp(),
          'adminNotes': [],
          'ownerInformation': ownerInformation,
          'petInformation': petInformationForBooking,
          'date': _selectedService == 'Boarding'
              ? checkInDateController.text.trim()
              : groomingCheckInDateController.text.trim(),
          'time': specificTimeController.text.trim(),
        };

        if (_selectedService == 'Boarding') {
          bookingData['boardingDetails'] = {
            'checkInDate': checkInDateController.text.trim(),
            'checkOutDate': checkOutDateController.text.trim(),
            'selectedRoomType': currentPetBookingDetails['selectedRoomType'],
            'boardingWaiverAgreed': _boardingWaiperAgreed,
          };
          bookingData['feedingDetails'] = feedingDetailsForBooking;
          bookingData['vaccinationRecord'] = {
            'imageUrl': vaccinationRecordImageUrlForBooking,
          };
          bookingData['paymentDetails'] = {
            'method': _selectedPaymentMethod,
            'accountNumber': _paymentOptions[_selectedPaymentMethod],
            'accountName': _accountName,
            'receiptImageUrl': finalPaymentReceiptImageUrl,
            'referenceNumber': referenceNumberController.text
                .trim(), // Added reference number
            'downPaymentAmount': double.parse(
              downPaymentAmountController.text.trim(),
            ), // New: Down Payment Amount
          };
        } else if (_selectedService == 'Grooming') {
          bookingData['groomingDetails'] = {
            'groomingWaiverAgreed': _groomingWaiverAgreed,
            'groomingCheckInDate': groomingCheckInDateController.text.trim(),
          };
          if (vaccinationRecordImageUrlForBooking != null &&
              vaccinationRecordImageUrlForBooking.isNotEmpty) {
            bookingData['vaccinationRecord'] = {
              'imageUrl': vaccinationRecordImageUrlForBooking,
            };
          }
        }

        DocumentReference docRef = await _firestore
            .collection('bookings')
            .add(bookingData);
        successfullyBookedIds.add(docRef.id);
      }

      if (mounted) {
        if (successfullyBookedIds.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BookingConfirmationScreen(
                bookingId: successfullyBookedIds.first,
              ),
            ),
          );
          _showSnackBar(
            'Successfully submitted ${successfullyBookedIds.length} bookings!',
          );
        } else {
          _showSnackBar('No bookings were submitted.');
        }
        _checkBookingAvailability();
      }
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'An authentication error occurred.';
      _showSnackBar('Authentication Error: $message');
    } on FirebaseException catch (e) {
      _showSnackBar('Failed to submit booking: ${e.message ?? e.toString()}');
    } catch (e) {
      _showSnackBar('An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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

  void _setLoadingFalseAndReturn() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget formContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _activeBookingsCount >= _bookingLimit
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 60,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Booking capacity reached!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We currently have $_activeBookingsCount active bookings. Please try again after ${_nextAvailableDate != null && _nextAvailableDate!.isAfter(DateTime.now()) ? DateFormat('MMM dd, encamp').format(_nextAvailableDate!) : 'a future date'}.',
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildSectionTitle('Select Service & Dates'),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedService = 'Boarding';
                              _resetGroomingFields();
                              _checkBookingAvailability();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedService == 'Boarding'
                                ? Colors.orange.shade700
                                : Colors.deepPurple.shade50,
                            foregroundColor: _selectedService == 'Boarding'
                                ? Colors.white
                                : Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: _selectedService == 'Boarding'
                                    ? Colors.orange.shade700
                                    : Colors.deepPurple,
                                width: 2,
                              ),
                            ),
                            elevation: _selectedService == 'Boarding' ? 5 : 1,
                          ),
                          child: const Text(
                            'Pet Boarding',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedService = 'Grooming';
                              _resetBoardingFields();
                              _checkBookingAvailability();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedService == 'Grooming'
                                ? Colors.orange.shade700
                                : Colors.deepPurple.shade50,
                            foregroundColor: _selectedService == 'Grooming'
                                ? Colors.white
                                : Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: _selectedService == 'Grooming'
                                    ? Colors.orange.shade700
                                    : Colors.deepPurple,
                                width: 2,
                              ),
                            ),
                            elevation: _selectedService == 'Grooming' ? 5 : 1,
                          ),
                          child: const Text(
                            'Pet Grooming',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_selectedService == 'Boarding') ...[
                    _buildDateField(
                      context,
                      controller: checkInDateController,
                      labelText: 'Check-in Date',
                      icon: Icons.calendar_today,
                      validator: (value) =>
                          value!.isEmpty ? 'Please select check-in date' : null,
                    ),
                    const SizedBox(height: 10),
                    _buildDateField(
                      context,
                      controller: checkOutDateController,
                      labelText: 'Check-out Date',
                      icon: Icons.calendar_today,
                      validator: (value) => value!.isEmpty
                          ? 'Please select check-out date'
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ] else if (_selectedService == 'Grooming') ...[
                    _buildDateField(
                      context,
                      controller: groomingCheckInDateController,
                      labelText: 'Grooming Check-in Date',
                      icon: Icons.calendar_today,
                      validator: (value) => value!.isEmpty
                          ? 'Please select grooming check-in date'
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_selectedService != null)
                    DropdownButtonFormField<String>(
                      value: specificTimeController.text.isNotEmpty
                          ? specificTimeController.text
                          : null,
                      items: _times
                          .map(
                            (t) => DropdownMenuItem<String>(
                              value: t,
                              child: Text(t),
                            ),
                          )
                          .toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          specificTimeController.text = newValue ?? '';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Specific Time',
                        labelStyle: const TextStyle(color: Colors.black),
                        prefixIcon: const Icon(
                          Icons.access_time,
                          color: Color(0xFFFFB74D),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.deepPurple.shade50,
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please select a specific time'
                          : null,
                    ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Choose Your Pet(s)'),
                  _registeredPets.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No pets registered yet. Please register a pet to proceed with a booking.',
                                style: TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const MyPetsScreen(isModal: false),
                                    ),
                                  );
                                  _fetchRegisteredPets();
                                },
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Add/Register New Pet',
                                  style: TextStyle(color: Colors.black),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade200,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._registeredPets.map((petDoc) {
                              final petData =
                                  petDoc.data() as Map<String, dynamic>;
                              final petId = petDoc.id;
                              final petName = petData['petName'] ?? 'N/A';
                              final petType = petData['petType'] ?? 'N/A';
                              final String petBreed =
                                  petData['petBreed'] as String? ?? 'N/A';

                              final bool hasActiveBookingOnDate =
                                  _petDailyBookingStatus[petId]?.containsKey(
                                    _selectedService == 'Boarding'
                                        ? checkInDateController.text.trim()
                                        : groomingCheckInDateController.text
                                              .trim(),
                                  ) ??
                                  false;
                              final bool isSelected = _selectedPetsToBook
                                  .contains(petDoc);

                              String topMessage = '';
                              if (hasActiveBookingOnDate) {
                                topMessage = '(Booked for this date)';
                              } else if (_selectedService == null ||
                                  (_selectedService == 'Boarding' &&
                                      checkInDateController.text.isEmpty) ||
                                  (_selectedService == 'Grooming' &&
                                      groomingCheckInDateController
                                          .text
                                          .isEmpty)) {
                                topMessage = '(Select service and date first)';
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Opacity(
                                  opacity:
                                      hasActiveBookingOnDate ||
                                          (topMessage.isNotEmpty &&
                                              !hasActiveBookingOnDate)
                                      ? 0.5
                                      : 1.0,
                                  child: CheckboxListTile(
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (topMessage.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4.0,
                                            ),
                                            child: Text(
                                              topMessage,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: hasActiveBookingOnDate
                                                    ? Colors.red
                                                    : Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          'Pet Name: $petName',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                hasActiveBookingOnDate ||
                                                    (topMessage.isNotEmpty &&
                                                        !hasActiveBookingOnDate)
                                                ? Colors.grey.shade600
                                                : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Type: $petType',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Breed: $petBreed',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    value: isSelected,
                                    onChanged: (bool? newValue) {
                                      if (newValue == true &&
                                          hasActiveBookingOnDate) {
                                        _showSnackBar(
                                          'Pet "${petName}" is already booked for this date.',
                                        );
                                        return;
                                      }
                                      if (newValue == true &&
                                          topMessage.isNotEmpty &&
                                          !hasActiveBookingOnDate) {
                                        _showSnackBar(
                                          'Please select a service and booking date first.',
                                        );
                                        return;
                                      }

                                      setState(() {
                                        if (newValue == true) {
                                          if (!_selectedPetsToBook.contains(
                                            petDoc,
                                          )) {
                                            _selectedPetsToBook.add(petDoc);
                                            _petsBookingDetails[petId] =
                                                _initializePetBookingDetails(
                                                  petDoc,
                                                );
                                          }
                                        } else {
                                          final details = _petsBookingDetails
                                              .remove(petId);
                                          // Dispose controllers when pet is deselected
                                          (details?['morningFoodGramsController']
                                                  as TextEditingController?)
                                              ?.dispose();
                                          (details?['afternoonFoodGramsController']
                                                  as TextEditingController?)
                                              ?.dispose();
                                          (details?['eveningFoodGramsController']
                                                  as TextEditingController?)
                                              ?.dispose();
                                          _selectedPetsToBook.remove(petDoc);
                                        }
                                        _formKey.currentState?.validate();
                                      });
                                    },
                                    activeColor: Colors.deepPurple,
                                  ),
                                ),
                              );
                            }).toList(),
                            if (_selectedPetsToBook.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(left: 16.0, top: 8.0),
                                child: Text(
                                  'Please select at least one pet.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const MyPetsScreen(isModal: false),
                                    ),
                                  );
                                  _fetchRegisteredPets();
                                },
                                icon: const Icon(Icons.add, color: Colors.blue),
                                label: const Text(
                                  'Add Another Pet',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 20),
                  if (_selectedPetsToBook.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Selected Pet(s) Booking Details'),
                        ..._selectedPetsToBook.map((petDoc) {
                          return _buildEditablePetCard(petDoc);
                        }).toList(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  if (_selectedService == 'Boarding') ...[
                    _buildSectionTitle('Mode of Payment'),
                    _buildDropdownField(
                      value: _selectedPaymentMethod,
                      items: _paymentOptions.keys.toList(),
                      labelText: 'Select Payment Method',
                      icon: Icons.payment,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedPaymentMethod = newValue;
                          if (newValue != null) {
                            _paymentDetailsText =
                                'Account Number: ${_paymentOptions[newValue]}\nAccount Name: $_accountName';
                          } else {
                            _paymentDetailsText = null;
                          }
                        });
                      },
                      validator: (value) => value == null
                          ? 'Please select a payment method'
                          : null,
                    ),
                    if (_paymentDetailsText != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.deepPurple),
                        ),
                        child: Text(
                          _paymentDetailsText!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                    if (_selectedPaymentMethod != null) ...[
                      const SizedBox(height: 20),
                      // Agreement note and checkbox
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: const Text(
                          'Note: The down payment is non-refundable.',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildCheckboxField(
                        'I understand the down payment is non-refundable',
                        _downpaymentAgreementAgreed,
                        (bool? newValue) {
                          setState(() {
                            _downpaymentAgreementAgreed = newValue ?? false;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildSectionTitle('Minimum Down Payment 250Php'),
                      _buildTextField(
                        controller: downPaymentAmountController,
                        labelText: 'Amount Paid (PHP)',
                        icon: Icons.money,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the amount paid.';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount < _minimumDownPayment) {
                            return 'Minimum down payment is ${_minimumDownPayment.toStringAsFixed(0)} Php.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            if (_paymentReceiptImage != null)
                              Stack(
                                children: [
                                  Container(
                                    height: 150,
                                    width: 150,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      image: DecorationImage(
                                        image: FileImage(_paymentReceiptImage!),
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
                                            _paymentReceiptImage = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              const Text('No payment receipt image selected.'),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _pickPaymentReceiptImage,
                              icon: const Icon(
                                Icons.upload_file,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Upload Payment Receipt',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: referenceNumberController,
                              labelText: 'Reference Number',
                              icon: Icons.confirmation_number,
                              validator: (value) {
                                if (_selectedService == 'Boarding' &&
                                    _paymentReceiptImage != null &&
                                    value!.isEmpty) {
                                  return 'Please enter the reference number for your payment.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20), // Added SizedBox
                    _buildSectionTitle('Pet Boarding Waiver'),
                    _buildCheckboxField(
                      'I agree to the Pet Boarding Waiver',
                      _boardingWaiperAgreed, // Typo fix: Waiver
                      (bool? newValue) {
                        setState(() {
                          _boardingWaiperAgreed = newValue!; // Typo fix: Waiver
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'I hereby commit not to abandon my pet under any circumstances. I certify that my pet is fully vaccinated, in good health, and protected against ticks and fleas through appropriate treatments.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'I also agree to ensure my pet wears a proper safety collar.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'I understand that Furry Tails Pet Care Services will take all reasonable precautions, but shall not be held liable for any unforeseen incidents. I authorize Furry Tails Pet Care Services to seek veterinary care for my pet, if necessary, at my own expense.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'I acknowledge the potential risks involved in group boarding, including stress-related conditions. These might include things like loss of appetite, temporary behavior changes, excessive barking or meowing, anxiety, vomiting, diarrhea (including stress-related), or other mild digestive issues.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'I agree to provide all necessary supplies, including food, medications, bedding, and any other items required for the care of my pet during their stay. I confirm that all information provided is true and accurate.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                  if (_selectedService == 'Grooming') ...[
                    _buildSectionTitle('Pet Grooming Waiver'),
                    _buildCheckboxField(
                      'I agree to the Pet Grooming Waiver',
                      _groomingWaiverAgreed,
                      (bool? newValue) {
                        setState(() {
                          _groomingWaiverAgreed = newValue!;
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'I commit not to abandon my pet and confirm that neither my pet nor I have any contagious diseases.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'I understand that Furry Tails Pet Care Services will take reasonable precautions but are not responsible for any unforeseen issues. I agree to the use of necessary tools and products during grooming and acknowledge that services may be refused if deemed unsafe for my pet.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'I understand that if my pet displays aggressive or dangerous behavior, Furry Tails reserves the right to refuse or discontinue services at any time.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'I authorize Furry Tails to seek veterinary care if necessary, at my own expense.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'I accept full responsibility for any issues that may arise. All information I have provided is accurate and up to date.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'I also grant Furry Tails permission to use photos or videos of my pet for promotional purposes, without compensation.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'I have read, understood, and agree to the terms outlined in this form.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                  Center(
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: () async {
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
                                _submitBooking();
                              }
                            },
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
                            child: const Text('Submit Booking'),
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );

    if (widget.isModal) {
      return formContent;
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Book a Service'),
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFFFB64A),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Builder(
          builder: (BuildContext innerContext) {
            try {
              return formContent;
            } catch (e, stack) {
              print(
                'ERROR in BookingFormScreen build (non-modal path): $e\n$stack',
              );
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 50,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'An error occurred loading the form. Please try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      );
    }
  }

  Widget _buildEditablePetCard(DocumentSnapshot petDoc) {
    final petId = petDoc.id;
    final Map<String, dynamic> petData = petDoc.data() as Map<String, dynamic>;
    if (!_petsBookingDetails.containsKey(petId)) {
      _petsBookingDetails[petId] = _initializePetBookingDetails(petDoc);
    }
    final Map<String, dynamic> currentPetBookingDetails =
        _petsBookingDetails[petId]!;

    // Initialize/retrieve controllers for standard fields
    final TextEditingController foodBrandController = TextEditingController(
      text: currentPetBookingDetails['foodBrand'],
    );
    final TextEditingController numberOfMealsController = TextEditingController(
      text: currentPetBookingDetails['numberOfMeals'],
    );
    final TextEditingController morningTimeController = TextEditingController(
      text: currentPetBookingDetails['morningTime'],
    );
    final TextEditingController afternoonTimeController = TextEditingController(
      text: currentPetBookingDetails['afternoonTime'],
    );
    final TextEditingController eveningTimeController = TextEditingController(
      text: currentPetBookingDetails['eveningTime'],
    );

    // Retrieve Food Grams Controllers from the map
    final TextEditingController morningFoodGramsController =
        currentPetBookingDetails['morningFoodGramsController'];
    final TextEditingController afternoonFoodGramsController =
        currentPetBookingDetails['afternoonFoodGramsController'];
    final TextEditingController eveningFoodGramsController =
        currentPetBookingDetails['eveningFoodGramsController'];

    // Add listeners to update the map for standard fields
    foodBrandController.addListener(() {
      currentPetBookingDetails['foodBrand'] = foodBrandController.text;
    });
    numberOfMealsController.addListener(() {
      currentPetBookingDetails['numberOfMeals'] = numberOfMealsController.text;
    });
    morningTimeController.addListener(() {
      currentPetBookingDetails['morningTime'] = morningTimeController.text;
    });
    afternoonTimeController.addListener(() {
      currentPetBookingDetails['afternoonTime'] = afternoonTimeController.text;
    });
    eveningTimeController.addListener(() {
      currentPetBookingDetails['eveningTime'] = eveningTimeController.text;
    });
    // Listeners for food grams are already added in _initializePetBookingDetails

    File? currentVaccinationFile =
        currentPetBookingDetails['vaccinationRecordImageFileForBooking'];
    String? currentVaccinationUrl =
        currentPetBookingDetails['vaccinationRecordImageUrlFromProfile'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Details for: ${petData['petName'] ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 15),
            _buildReadOnlyDetail('Pet Type', petData['petType'] ?? 'N/A'),
            _buildReadOnlyDetail('Breed', petData['petBreed'] ?? 'N/A'),
            _buildReadOnlyDetail('Gender', petData['petGender'] ?? 'N/A'),
            _buildReadOnlyDetail(
              'Weight (kg)',
              petData['petWeight']?.toString() ?? 'N/A',
            ),
            _buildReadOnlyDetail(
              'Date of Birth',
              petData['dateOfBirth'] ?? 'N/A',
            ),
            const SizedBox(height: 20),
            if (_selectedService == 'Boarding') ...[
              _buildDropdownField(
                value: currentPetBookingDetails['selectedRoomType'],
                items: _roomTypes,
                labelText: 'Room Type',
                icon: Icons.king_bed,
                onChanged: (String? newValue) {
                  setState(() {
                    currentPetBookingDetails['selectedRoomType'] = newValue;
                  });
                },
                validator: (value) {
                  if (_selectedService == 'Boarding' &&
                      (value == null || value.isEmpty)) {
                    return 'Please select a room type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              Text(
                'Feeding Details:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: foodBrandController,
                labelText: 'Food Brand',
                icon: Icons.fastfood,
                validator: (value) {
                  if (_selectedService == 'Boarding' && value!.isEmpty) {
                    return 'Please enter food brand';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              _buildTextField(
                controller: numberOfMealsController,
                labelText: 'Number of Meals per day',
                icon: Icons.format_list_numbered,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) {
                    if (_selectedService == 'Boarding')
                      return 'Please enter number of meals';
                  }
                  if (value.isNotEmpty && int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              _buildCheckboxField(
                'Morning Feeding',
                currentPetBookingDetails['morningFeeding'] ?? false,
                (bool? newValue) {
                  setState(() {
                    currentPetBookingDetails['morningFeeding'] = newValue!;
                  });
                },
              ),
              if (currentPetBookingDetails['morningFeeding'] == true) ...[
                _buildTimeFieldForPet(
                  context,
                  petId,
                  'morningTime',
                  morningTimeController,
                  'Morning Time',
                  Icons.access_time,
                ),
                const SizedBox(height: 10),
                _buildFoodGramsField(
                  controller: morningFoodGramsController,
                  labelText: 'Morning Food Grams',
                  icon: Icons.scale,
                  validator: (value) {
                    if (currentPetBookingDetails['morningFeeding'] == true &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter morning food grams';
                    }
                    if (value!.isNotEmpty && int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 10),
              _buildCheckboxField(
                'Afternoon Feeding',
                currentPetBookingDetails['afternoonFeeding'] ?? false,
                (bool? newValue) {
                  setState(() {
                    currentPetBookingDetails['afternoonFeeding'] = newValue!;
                  });
                },
              ),
              if (currentPetBookingDetails['afternoonFeeding'] == true) ...[
                _buildTimeFieldForPet(
                  context,
                  petId,
                  'afternoonTime',
                  afternoonTimeController,
                  'Afternoon Time',
                  Icons.access_time,
                ),
                const SizedBox(height: 10),
                _buildFoodGramsField(
                  controller: afternoonFoodGramsController,
                  labelText: 'Afternoon Food Grams',
                  icon: Icons.scale,
                  validator: (value) {
                    if (currentPetBookingDetails['afternoonFeeding'] == true &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter afternoon food grams';
                    }
                    if (value!.isNotEmpty && int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 10),
              _buildCheckboxField(
                'Evening Feeding',
                currentPetBookingDetails['eveningFeeding'] ?? false,
                (bool? newValue) {
                  setState(() {
                    currentPetBookingDetails['eveningFeeding'] = newValue!;
                  });
                },
              ),
              if (currentPetBookingDetails['eveningFeeding'] == true) ...[
                _buildTimeFieldForPet(
                  context,
                  petId,
                  'eveningTime',
                  eveningTimeController,
                  'Evening Time',
                  Icons.access_time,
                ),
                const SizedBox(height: 10),
                _buildFoodGramsField(
                  controller: eveningFoodGramsController,
                  labelText: 'Evening Food Grams',
                  icon: Icons.scale,
                  validator: (value) {
                    if (currentPetBookingDetails['eveningFeeding'] == true &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter evening food grams';
                    }
                    if (value!.isNotEmpty && int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),
            ],
            Text(
              'Vaccination Record (for ${petData['petName'] ?? 'N/A'})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  if (currentVaccinationFile != null)
                    Stack(
                      children: [
                        Container(
                          height: 150,
                          width: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: FileImage(currentVaccinationFile),
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
                                  currentPetBookingDetails['vaccinationRecordImageFileForBooking'] =
                                      null;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (currentVaccinationUrl != null &&
                      currentVaccinationUrl.isNotEmpty)
                    Stack(
                      children: [
                        Container(
                          height: 150,
                          width: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: NetworkImage(currentVaccinationUrl),
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
                                  currentPetBookingDetails['vaccinationRecordImageUrlFromProfile'] =
                                      null;
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
                    onPressed: () => _pickVaccinationImageForPet(petId),
                    icon: const Icon(Icons.upload_file, color: Colors.white),
                    label: const Text(
                      'Upload Vaccination Record',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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

  Widget _buildReadOnlyDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    // FIX: Ensure a widget is always returned
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

  Widget _buildTimePickerField(
    BuildContext context,
    TextEditingController controller,
    String labelText,
    IconData icon,
    String? Function(String?)? validator,
  ) {
    // FIX: Ensure a widget is always returned
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
      onTap: () => _selectBookingTime(context, controller),
      validator: validator,
    );
  }

  Widget _buildTimeFieldForPet(
    BuildContext context,
    String petId,
    String timeKey,
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
      onTap: () => _selectTime(context, petId, timeKey, controller),
    );
  }

  Widget _buildFoodGramsField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB74D)),
        suffixText: 'grams', // Add "grams" suffix
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
}

class BookingConfirmationScreen extends StatelessWidget {
  final String bookingId;

  const BookingConfirmationScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmation'),
        backgroundColor: Colors.orange.shade300,
        foregroundColor: Colors.black87,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 100,
              ),
              const SizedBox(height: 20),
              Text(
                'Booking Submitted Successfully!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your Booking ID is: $bookingId',
                style: const TextStyle(fontSize: 18, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(
                    context,
                    (route) =>
                        route.isFirst ||
                        route.settings.name == '/home_screen' ||
                        route.settings.name == '/services_screen',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
