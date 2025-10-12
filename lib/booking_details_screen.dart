// booking_details_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Assume BookingDetailsScreen receives a bookingId
class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;

  const BookingDetailsScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

extension on _BookingDetailsScreenState {
  // Reuse the same Cloudinary setup as in form screen
  static const String _cloudinaryCloudName = 'dlec25zve';
  static const String _cloudinaryUploadPreset = 'pet_photo_preset';

  Future<String?> _uploadImageToCloudinary(File? imageFile) async {
    if (imageFile == null) return null;
    if (_cloudinaryCloudName.isEmpty || _cloudinaryUploadPreset.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloudinary is not configured.')),
      );
      return null;
    }
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '$_cloudinaryCloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        final result = jsonDecode(utf8.decode(bytes));
        return result['secure_url'] as String?;
      } else {
        final err = await response.stream.bytesToString();
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image upload failed: ${response.statusCode} $err'),
          ),
        );
        return null;
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image upload error: $e')));
      return null;
    }
  }

  // Existing _showUpdateDialog method remains here...
  Future<void> _showUpdateDialog(Map<String, dynamic> bookingData) async {
    final String serviceType = bookingData['serviceType'] ?? 'N/A';
    final Map<String, dynamic> boardingDetails =
        bookingData['boardingDetails'] ?? {};
    final Map<String, dynamic> groomingDetails =
        bookingData['groomingDetails'] ?? {};
    final Map<String, dynamic> feedingDetails =
        bookingData['feedingDetails'] ?? {};
    final Map<String, dynamic> paymentDetails =
        bookingData['paymentDetails'] ?? {};
    final Map<String, dynamic> vaccinationRecord =
        bookingData['vaccinationRecord'] ?? {};

    final TextEditingController timeController = TextEditingController(
      text: bookingData['time'] ?? '',
    );
    final TextEditingController checkInController = TextEditingController(
      text: serviceType == 'Boarding'
          ? (boardingDetails['checkInDate'] ?? '')
          : (groomingDetails['groomingCheckInDate'] ?? ''),
    );
    final TextEditingController checkOutController = TextEditingController(
      text: serviceType == 'Boarding'
          ? (boardingDetails['checkOutDate'] ?? '')
          : '',
    );

    String? selectedRoomType = serviceType == 'Boarding'
        ? (boardingDetails['selectedRoomType'] as String?)
        : null;

    // Feeding details (Boarding)
    final TextEditingController foodBrandController = TextEditingController(
      text: feedingDetails['foodBrand'] ?? '',
    );
    final TextEditingController numberOfMealsController = TextEditingController(
      text: (feedingDetails['numberOfMeals'] ?? '').toString(),
    );
    bool morningFeeding = feedingDetails['morningFeeding'] ?? false;
    final TextEditingController morningTimeController = TextEditingController(
      text: feedingDetails['morningTime'] ?? '',
    );
    final TextEditingController morningGramsController = TextEditingController(
      text: (feedingDetails['morningFoodGrams'] ?? '').toString(),
    );
    bool afternoonFeeding = feedingDetails['afternoonFeeding'] ?? false;
    final TextEditingController afternoonTimeController = TextEditingController(
      text: feedingDetails['afternoonTime'] ?? '',
    );
    final TextEditingController afternoonGramsController =
        TextEditingController(
          text: (feedingDetails['afternoonFoodGrams'] ?? '').toString(),
        );
    bool eveningFeeding = feedingDetails['eveningFeeding'] ?? false;
    final TextEditingController eveningTimeController = TextEditingController(
      text: feedingDetails['eveningTime'] ?? '',
    );
    final TextEditingController eveningGramsController = TextEditingController(
      text: (feedingDetails['eveningFoodGrams'] ?? '').toString(),
    );

    // Waivers
    bool boardingWaiverAgreed =
        boardingDetails['boardingWaiverAgreed'] ?? false;
    bool groomingWaiverAgreed =
        groomingDetails['groomingWaiverAgreed'] ?? false;

    // Payment (Boarding)
    String? selectedPaymentMethod = paymentDetails['method'] as String?;
    final TextEditingController referenceNumberController =
        TextEditingController(
          text: (paymentDetails['referenceNumber'] ?? '').toString(),
        );
    final TextEditingController downPaymentAmountController =
        TextEditingController(
          text: paymentDetails['downPaymentAmount'] != null
              ? (paymentDetails['downPaymentAmount']).toString()
              : '',
        );

    // Vaccination record image
    final ImagePicker picker = ImagePicker();
    File? vaccinationImageFile; // newly picked
    String? vaccinationImageUrl =
        vaccinationRecord['imageUrl'] as String?; // existing

    Future<void> pickDate(TextEditingController controller) async {
      final now = DateTime.now();
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: (controller.text.isNotEmpty)
            ? DateTime.tryParse(controller.text) ?? now
            : now,
        firstDate: now,
        lastDate: DateTime(now.year + 3),
      );
      if (picked != null) {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    }

    Future<void> pickTime(TextEditingController controller) async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked != null) {
        // ignore: use_build_context_synchronously
        controller.text = picked.format(context);
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Update Booking'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: timeController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Time',
                    prefixIcon: const Icon(Icons.access_time),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: () => pickTime(timeController),
                    ),
                  ),
                  onTap: () => pickTime(timeController),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: checkInController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: serviceType == 'Boarding'
                        ? 'Check-in Date'
                        : 'Grooming Date',
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  onTap: () => pickDate(checkInController),
                ),
                if (serviceType == 'Boarding') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: checkOutController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Check-out Date',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () => pickDate(checkOutController),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRoomType,
                    items: const [
                      DropdownMenuItem(
                        value: 'Large Kennel',
                        child: Text('Large Kennel'),
                      ),
                      DropdownMenuItem(
                        value: 'Small Kennel',
                        child: Text('Small Kennel'),
                      ),
                    ],
                    onChanged: (v) => selectedRoomType = v,
                    decoration: const InputDecoration(
                      labelText: 'Room Type',
                      prefixIcon: Icon(Icons.king_bed),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Vaccination Record',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      children: [
                        if (vaccinationImageFile != null)
                          Stack(
                            children: [
                              Container(
                                height: 150,
                                width: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  image: DecorationImage(
                                    image: FileImage(vaccinationImageFile!),
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
                                      vaccinationImageFile = null;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (vaccinationImageUrl != null &&
                            vaccinationImageUrl!.isNotEmpty)
                          Stack(
                            children: [
                              Container(
                                height: 150,
                                width: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  image: DecorationImage(
                                    image: NetworkImage(vaccinationImageUrl!),
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
                                      vaccinationImageUrl = null;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          const Text('No vaccination image selected'),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final XFile? picked = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (picked != null) {
                              vaccinationImageFile = File(picked.path);
                              // ignore: use_build_context_synchronously
                              (ctx as Element).markNeedsBuild();
                            }
                          },
                          icon: const Icon(
                            Icons.upload_file,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Upload Vaccination Record',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Feeding Details',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: foodBrandController,
                    decoration: const InputDecoration(
                      labelText: 'Food Brand',
                      prefixIcon: Icon(Icons.fastfood),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: numberOfMealsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Meals per day',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Morning Feeding'),
                    value: morningFeeding,
                    onChanged: (v) {
                      // ignore: use_build_context_synchronously
                      (ctx as Element).markNeedsBuild();
                      morningFeeding = v;
                    },
                  ),
                  if (morningFeeding) ...[
                    TextField(
                      controller: morningTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Morning Time',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      onTap: () => pickTime(morningTimeController),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: morningGramsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Morning Food Grams',
                        prefixIcon: Icon(Icons.scale),
                        suffixText: 'grams',
                      ),
                    ),
                  ],
                  SwitchListTile(
                    title: const Text('Afternoon Feeding'),
                    value: afternoonFeeding,
                    onChanged: (v) {
                      // ignore: use_build_context_synchronously
                      (ctx as Element).markNeedsBuild();
                      afternoonFeeding = v;
                    },
                  ),
                  if (afternoonFeeding) ...[
                    TextField(
                      controller: afternoonTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Afternoon Time',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      onTap: () => pickTime(afternoonTimeController),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: afternoonGramsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Afternoon Food Grams',
                        prefixIcon: Icon(Icons.scale),
                        suffixText: 'grams',
                      ),
                    ),
                  ],
                  SwitchListTile(
                    title: const Text('Evening Feeding'),
                    value: eveningFeeding,
                    onChanged: (v) {
                      // ignore: use_build_context_synchronously
                      (ctx as Element).markNeedsBuild();
                      eveningFeeding = v;
                    },
                  ),
                  if (eveningFeeding) ...[
                    TextField(
                      controller: eveningTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Evening Time',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      onTap: () => pickTime(eveningTimeController),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: eveningGramsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Evening Food Grams',
                        prefixIcon: Icon(Icons.scale),
                        suffixText: 'grams',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Agree to Boarding Waiver'),
                    value: boardingWaiverAgreed,
                    onChanged: (v) {
                      // ignore: use_build_context_synchronously
                      (ctx as Element).markNeedsBuild();
                      boardingWaiverAgreed = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMethod,
                    items: const [
                      DropdownMenuItem(value: 'BDO', child: Text('BDO')),
                      DropdownMenuItem(value: 'BPI', child: Text('BPI')),
                      DropdownMenuItem(value: 'UB', child: Text('UB')),
                      DropdownMenuItem(value: 'GCASH', child: Text('GCASH')),
                    ],
                    onChanged: (v) {
                      // ignore: use_build_context_synchronously
                      (ctx as Element).markNeedsBuild();
                      selectedPaymentMethod = v;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      prefixIcon: Icon(Icons.payment),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: downPaymentAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Down Payment Amount (PHP)',
                      prefixIcon: Icon(Icons.money),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: referenceNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Reference Number',
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                  ),
                ],
                if (serviceType == 'Grooming') ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Agree to Grooming Waiver'),
                    value: groomingWaiverAgreed,
                    onChanged: (v) {
                      // ignore: use_build_context_synchronously
                      (ctx as Element).markNeedsBuild();
                      groomingWaiverAgreed = v;
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Basic validation
                if (timeController.text.trim().isEmpty ||
                    checkInController.text.trim().isEmpty ||
                    (serviceType == 'Boarding' &&
                        (checkOutController.text.trim().isEmpty ||
                            (selectedRoomType == null ||
                                selectedRoomType!.isEmpty)))) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields.'),
                    ),
                  );
                  return;
                }
                // Optional date consistency check for boarding
                if (serviceType == 'Boarding') {
                  try {
                    final inDate = DateTime.parse(checkInController.text);
                    final outDate = DateTime.parse(checkOutController.text);
                    if (outDate.isBefore(inDate)) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Check-out date cannot be before check-in date.',
                          ),
                        ),
                      );
                      return;
                    }
                  } catch (_) {}
                }
                // ignore: use_build_context_synchronously
                Navigator.of(ctx).pop();
                setState(() => _isLoading = true);
                try {
                  final Map<String, dynamic> updateData = {
                    'time': timeController.text.trim(),
                  };
                  if (serviceType == 'Boarding') {
                    updateData['date'] = checkInController.text.trim();
                    updateData['boardingDetails.checkInDate'] =
                        checkInController.text.trim();
                    updateData['boardingDetails.checkOutDate'] =
                        checkOutController.text.trim();
                    updateData['boardingDetails.selectedRoomType'] =
                        selectedRoomType;
                    updateData['boardingDetails.boardingWaiverAgreed'] =
                        boardingWaiverAgreed;
                    updateData['feedingDetails.foodBrand'] = foodBrandController
                        .text
                        .trim();
                    updateData['feedingDetails.numberOfMeals'] =
                        numberOfMealsController.text.trim();
                    updateData['feedingDetails.morningFeeding'] =
                        morningFeeding;
                    updateData['feedingDetails.morningTime'] =
                        morningTimeController.text.trim();
                    updateData['feedingDetails.morningFoodGrams'] =
                        morningGramsController.text.trim();
                    updateData['feedingDetails.afternoonFeeding'] =
                        afternoonFeeding;
                    updateData['feedingDetails.afternoonTime'] =
                        afternoonTimeController.text.trim();
                    updateData['feedingDetails.afternoonFoodGrams'] =
                        afternoonGramsController.text.trim();
                    updateData['feedingDetails.eveningFeeding'] =
                        eveningFeeding;
                    updateData['feedingDetails.eveningTime'] =
                        eveningTimeController.text.trim();
                    updateData['feedingDetails.eveningFoodGrams'] =
                        eveningGramsController.text.trim();
                    if (selectedPaymentMethod != null &&
                        selectedPaymentMethod!.isNotEmpty) {
                      updateData['paymentDetails.method'] =
                          selectedPaymentMethod;
                    }
                    if (downPaymentAmountController.text.trim().isNotEmpty) {
                      updateData['paymentDetails.downPaymentAmount'] =
                          double.tryParse(
                            downPaymentAmountController.text.trim(),
                          ) ??
                          paymentDetails['downPaymentAmount'];
                    }
                    updateData['paymentDetails.referenceNumber'] =
                        referenceNumberController.text.trim();
                  } else if (serviceType == 'Grooming') {
                    updateData['date'] = checkInController.text.trim();
                    updateData['groomingDetails.groomingCheckInDate'] =
                        checkInController.text.trim();
                    updateData['groomingDetails.groomingWaiverAgreed'] =
                        groomingWaiverAgreed;
                  }
                  // Upload vaccination image if newly picked
                  String? uploadedVaccinationUrl;
                  if (vaccinationImageFile != null) {
                    // ignore: use_build_context_synchronously
                    uploadedVaccinationUrl = await _uploadImageToCloudinary(
                      vaccinationImageFile,
                    );
                    if (uploadedVaccinationUrl == null) {
                      throw Exception('Vaccination image upload failed');
                    }
                  }
                  if (uploadedVaccinationUrl != null) {
                    updateData['vaccinationRecord.imageUrl'] =
                        uploadedVaccinationUrl;
                  } else if (vaccinationImageUrl == null) {
                    // Explicitly cleared in dialog
                    updateData['vaccinationRecord.imageUrl'] = '';
                  }
                  // Ensure status reflects completeness vs. missing vaccination
                  final String newVaccinationUrl =
                      (uploadedVaccinationUrl ?? vaccinationImageUrl ?? '')
                          .toString();
                  if (newVaccinationUrl.isEmpty) {
                    updateData['status'] = 'Pending';
                    updateData['pendingReason'] = 'Missing vaccination record';
                  } else {
                    // NOTE: If updating an Accepted booking, status should stay Accepted,
                    // but if a Pending booking now has a vaccination, it stays Pending
                    // until admin accepts.
                    if (bookingData['status'] != 'Accepted' &&
                        bookingData['status'] != 'Approved') {
                      updateData['status'] = 'Pending';
                    }
                    updateData['pendingReason'] = FieldValue.delete();
                  }
                  await _firestore
                      .collection('bookings')
                      .doc(widget.bookingId)
                      .update(updateData);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Booking updated successfully.'),
                      ),
                    );
                    await _fetchBookingDetails();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update booking: $e')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentSnapshot? _bookingDoc;
  bool _isLoading = true;
  String _currentBookingStatus = '';

  // *** FIX 1: Add the excluded statuses list to control button visibility ***
  // CORRECTED: Changed 'Checked In' to 'Check In' to match the status in the screenshot.
  final List<String> _excludedEditStatuses = const [
    'Check In',
    'Checked Out',
    'Feeding Schedule',
    'Completed',
    'Cancelled',
    'Rejected',
  ];
  // *** END FIX 1 ***

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();
  }

  Stream<String?> _getFacilitatorImageStream() {
    if (widget.bookingId.isEmpty) return Stream.value(null);
    try {
      // Query feedingHistory using bookingId, order by scheduledAt (or a reliable timestamp field)
      return _firestore
          .collection('feedingHistory') // <--- Correct collection
          .where('bookingId', isEqualTo: widget.bookingId)
          .orderBy(
            'scheduledAt',
            descending: true,
          ) // Assuming 'scheduledAt' is a reliable timestamp to get the latest
          .limit(1)
          .snapshots() // Use snapshots() for real-time updates
          .map((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              return snapshot.docs.first.data()['photoUrl'] as String?;
            }
            // If no document is found or the photoUrl field is missing/deleted, return null
            return null;
          });
    } catch (e) {
      print('Error setting up facilitator image stream: $e');
      return Stream.value(null);
    }
  }

  Future<void> _fetchBookingDetails() async {
    try {
      final doc = await _firestore
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (mounted) {
        setState(() {
          _bookingDoc = doc;
          // Ensure _currentBookingStatus is updated from the fetched document
          _currentBookingStatus =
              (_bookingDoc?.data() as Map<String, dynamic>?)?['status'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching booking details: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelBooking() async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Cancellation'),
          content: const Text(
            'Are you sure you want to cancel this booking? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _firestore.collection('bookings').doc(widget.bookingId).update({
          'status': 'Cancelled',
          'adminNotes':
              'Cancelled by user at ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled successfully!')),
          );
          _fetchBookingDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel booking: $e')),
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
  }

  // MODIFIED: Reusable function to show a full-screen zoomable image dialog
  void _showZoomableImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(), // Tap anywhere to dismiss
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.9),
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.red.withOpacity(0.3),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 80,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Image failed to load.',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // MODIFIED: Helper widget for displaying images (like vaccination record)
  Widget _buildImageDisplay(String? imageUrl, String title) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'No image available.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: GestureDetector(
              onTap: () {
                _showZoomableImageDialog(context, imageUrl);
              },
              child: Image.network(
                imageUrl,
                height: 150, // Fixed height for display in card
                width: double.infinity, // Use full width in card
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    children: [
                      Icon(Icons.broken_image, color: Colors.red, size: 50),
                      Text(
                        'Image failed to load.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MODIFIED: Helper widget to build a single feeding history item
  // Image is now wide and placed below the date/time/food details.
  Widget _buildFeedingHistoryItem(
    String petName,
    String time,
    String foodBrand,
    String? photoUrl,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 16.0,
      ), // Increased spacing below each item
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time and Food Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fed $petName',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                // Status icon placeholder
                const Icon(Icons.check_circle_outline, color: Colors.green),
              ],
            ),

            // --- Divider before image ---
            const SizedBox(height: 12),

            // Photo Display (Below time, now wide with Click-to-Zoom)
            if (photoUrl != null && photoUrl.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Photo Confirmation (Tap to Zoom):',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      _showZoomableImageDialog(
                        context,
                        photoUrl,
                      ); // Click to zoom
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        photoUrl,
                        height: 180, // Increased height for wide display
                        width:
                            double.infinity, // Made wide (full width of card)
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 180,
                            width: double.infinity,
                            color: Colors.red[100],
                            child: const Center(child: Text('Load Error')),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Chip(
                  label: Text(
                    'No Photo Record',
                    style: TextStyle(color: Colors.black54),
                  ),
                  avatar: Icon(Icons.camera_alt_outlined, size: 18),
                  backgroundColor: Colors.amber,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Booking Details'),
          backgroundColor: Colors.orange.shade300,
          foregroundColor: Colors.black87,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_bookingDoc == null || !_bookingDoc!.exists) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Booking Details'),
          backgroundColor: Colors.orange.shade300,
          foregroundColor: Colors.black87,
        ),
        body: const Center(child: Text('Booking not found.')),
      );
    }

    final bookingData = _bookingDoc!.data() as Map<String, dynamic>;

    // Data extraction variables
    final serviceType = bookingData['serviceType'] ?? 'N/A';
    final foodBrand = bookingData['feedingDetails']?['foodBrand'] ?? 'N/A';
    final mealsPerDay =
        bookingData['feedingDetails']?['numberOfMeals'] ?? 'N/A';
    final morningTime = bookingData['feedingDetails']?['morningTime'] ?? '';
    final morningGrams =
        bookingData['feedingDetails']?['morningFoodGrams'] ?? '';
    final afternoonTime = bookingData['feedingDetails']?['afternoonTime'] ?? '';
    final afternoonGrams =
        bookingData['feedingDetails']?['afternoonFoodGrams'] ?? '';
    final eveningTime = bookingData['feedingDetails']?['eveningTime'] ?? '';
    final eveningGrams =
        bookingData['feedingDetails']?['eveningFoodGrams'] ?? '';
    final vaccinationRecordImageUrl =
        bookingData['vaccinationRecord']?['imageUrl'] as String?;
    final pendingReason = bookingData['pendingReason'] as String?;
    final downPaymentAmount =
        bookingData['paymentDetails']?['downPaymentAmount'];
    final referenceNumber =
        bookingData['paymentDetails']?['referenceNumber'] ?? 'N/A';
    final paymentMethod = bookingData['paymentDetails']?['method'] ?? 'N/A';
    final petName = bookingData['petName'] ?? 'Your Pet';

    // Get the current status for conditional checks
    final status = _currentBookingStatus;

    // *** FIX 2: Define conditional flags in build method ***
    // 1. Logic to determine if editing is allowed. This is false for Checked In/Out/Completed/Cancelled/Rejected.
    final bool canEdit = !_excludedEditStatuses.contains(status);

    // 2. Logic to determine if cancellation is allowed.
    // It must be generally editable (canEdit = true) AND not already Cancelled/Rejected.
    // This allows cancellation for Accepted/Pending, but blocks it for Checked In.
    final bool canCancel =
        canEdit && !['Cancelled', 'Rejected'].contains(status);
    // *** END FIX 2 ***

    // Booking Details Section
    Widget _buildDetailRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: Colors.orange.shade300,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking Status Card (Existing)
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Booking Status',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        Icon(
                          status == 'Accepted' || status == 'Approved'
                              ? Icons.check_circle_outline
                              : status == 'Pending'
                              ? Icons.pending
                              : Icons.cancel,
                          color: status == 'Accepted' || status == 'Approved'
                              ? Colors.green
                              : status == 'Pending'
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildDetailRow('Status', status),
                    if (pendingReason != null && pendingReason.isNotEmpty)
                      _buildDetailRow('Reason', pendingReason!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // --- Action Buttons (Conditional Visibility FIX) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // *** FIX 3: Apply canCancel condition to Cancel button ***
                if (canCancel)
                  OutlinedButton.icon(
                    onPressed: _cancelBooking,
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('Cancel Booking'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          Colors.red, // Sets text/icon color to red
                      side: const BorderSide(
                        color: Colors.red,
                        width: 1.5,
                      ), // The visible frame
                    ),
                  ),
                const SizedBox(width: 8),
                // *** FIX 4: Apply canEdit condition to Edit button ***
                if (canEdit)
                  ElevatedButton.icon(
                    onPressed: () => _showUpdateDialog(bookingData),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Booking'),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Feeding History Section (For Customer Monitoring)
            if (serviceType == 'Boarding')
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Feeding History & Updates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const Divider(),
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('feedingHistory')
                            .where('bookingId', isEqualTo: widget.bookingId)
                            .orderBy('scheduledAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return Text(
                              'Error loading history: ${snapshot.error}',
                            );
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'No feeding records available yet.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              final doc = snapshot.data!.docs[index];
                              final data = doc.data() as Map<String, dynamic>;

                              // Format the scheduled time
                              String scheduledTime = 'N/A';
                              if (data.containsKey('scheduledAt') &&
                                  data['scheduledAt'] is Timestamp) {
                                scheduledTime = DateFormat('MMM d, hh:mm a')
                                    .format(
                                      (data['scheduledAt'] as Timestamp)
                                          .toDate()
                                          .toLocal(),
                                    );
                              }

                              String recordPetName =
                                  data['petName'] ??
                                  petName; // Use actual pet name or fallback
                              String recordFoodBrand =
                                  data['foodBrand'] ??
                                  foodBrand; // Use actual food or fallback

                              return _buildFeedingHistoryItem(
                                recordPetName,
                                scheduledTime,
                                recordFoodBrand,
                                data['photoUrl'] as String?,
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Feeding Instructions (Existing)
            if (serviceType == 'Boarding')
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Feeding Instructions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Divider(),
                      _buildDetailRow('Food Brand', foodBrand),
                      _buildDetailRow('Meals Per Day', mealsPerDay),
                      if (morningTime.isNotEmpty)
                        _buildDetailRow(
                          'Morning Feed',
                          '$morningTime (${morningGrams}g)',
                        ),
                      if (afternoonTime.isNotEmpty)
                        _buildDetailRow(
                          'Afternoon Feed',
                          '$afternoonTime (${afternoonGrams}g)',
                        ),
                      if (eveningTime.isNotEmpty)
                        _buildDetailRow(
                          'Evening Feed',
                          '$eveningTime (${eveningGrams}g)',
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Payment Details (Existing)
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Divider(),
                    _buildDetailRow('Method', paymentMethod),
                    _buildDetailRow(
                      'Down Payment',
                      'PHP ${downPaymentAmount ?? '0.00'}',
                    ),
                    _buildDetailRow('Reference Number', referenceNumber),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Vaccination Record (Existing - now with click-to-zoom)
            if (serviceType == 'Boarding')
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageDisplay(
                        vaccinationRecordImageUrl,
                        'Vaccination Record (Tap image to zoom)',
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
