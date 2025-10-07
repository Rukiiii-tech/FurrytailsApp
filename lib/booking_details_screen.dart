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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image upload failed: ${response.statusCode} $err'),
          ),
        );
        return null;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image upload error: $e')));
      return null;
    }
  }

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
                  Text(
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
                  Text(
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
                    onChanged: (v) => selectedPaymentMethod = v,
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

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();
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
          // FIX 1: Corrected DateFormat pattern from 'MMM dd, encamp hh:mm a'
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

    // Extracting main booking details
    final String serviceType = bookingData['serviceType'] ?? 'N/A';
    final String status = bookingData['status'] ?? 'Unknown';
    final String pendingReasonRaw = bookingData['pendingReason'] ?? '';
    // Vaccination presence influences incomplete state
    final Map<String, dynamic> vaccinationRecordForHeader =
        bookingData['vaccinationRecord'] ?? {};
    final String vaccinationImageUrlForHeader =
        vaccinationRecordForHeader['imageUrl'] ?? '';
    final bool missingVaccination =
        status == 'Pending' && (vaccinationImageUrlForHeader.isEmpty);
    final String effectivePendingReason = pendingReasonRaw.isNotEmpty
        ? pendingReasonRaw
        : (missingVaccination ? 'Missing vaccination record' : '');

    // FIX START: Corrected display logic to prevent hardcoding '(Reschedule)'
    // The display status should only show the core status (e.g., 'Approved').
    final String displayStatus =
        status == 'Pending' && effectivePendingReason.isNotEmpty
        ? 'Pending (Incomplete)'
        : status; // Use the raw status for all other cases
    // FIX END

    final Timestamp? timestamp = bookingData['timestamp'] as Timestamp?;
    final String bookingTime = bookingData['time'] ?? 'N/A';
    // FIX: More robust handling for adminNotes
    final dynamic rawAdminNotes = bookingData['adminNotes'];
    String adminNotes = 'N/A';
    if (rawAdminNotes != null) {
      if (rawAdminNotes is List) {
        adminNotes = rawAdminNotes.join('\n');
      } else if (rawAdminNotes is String) {
        adminNotes = rawAdminNotes;
      }
    }

    // Extracting nested owner information
    final Map<String, dynamic> ownerInfo =
        bookingData['ownerInformation'] ?? {};
    final String ownerFirstName = ownerInfo['firstName'] ?? 'N/A';
    final String ownerLastName = ownerInfo['lastName'] ?? 'N/A';
    final String ownerEmail = ownerInfo['email'] ?? 'N/A';
    final String ownerContactNo = ownerInfo['contactNo'] ?? 'N/A';
    final String ownerAddress = ownerInfo['address'] ?? 'N/A';

    // Extracting nested pet information
    final Map<String, dynamic> petInfo = bookingData['petInformation'] ?? {};
    final String petName = petInfo['petName'] ?? 'N/A';
    final String petType = petInfo['petType'] ?? 'N/A';
    final String petBreed = petInfo['petBreed'] ?? 'N/A';
    final String petGender = petInfo['petGender'] ?? 'N/A';
    final String petWeight = petInfo['petWeight'] ?? 'N/A';
    final String petDateOfBirth = petInfo['dateOfBirth'] ?? 'N/A';
    final String petProfileImageUrl = petInfo['petProfileImageUrl'] ?? '';

    // Extracting nested feeding details (might be present for Boarding)
    final Map<String, dynamic> feedingDetails =
        bookingData['feedingDetails'] ?? {};
    final String foodBrand = feedingDetails['foodBrand'] ?? 'N/A';
    final String numberOfMeals = feedingDetails['numberOfMeals'] ?? 'N/A';
    final bool morningFeeding = feedingDetails['morningFeeding'] ?? false;
    final String morningTime = feedingDetails['morningTime'] ?? 'N/A';
    final String morningFoodGrams =
        feedingDetails['morningFoodGrams'] ?? 'N/A'; // New: Morning Food Grams
    final bool afternoonFeeding = feedingDetails['afternoonFeeding'] ?? false;
    final String afternoonTime = feedingDetails['afternoonTime'] ?? 'N/A';
    final String afternoonFoodGrams =
        feedingDetails['afternoonFoodGrams'] ??
        'N/A'; // New: Afternoon Food Grams
    final bool eveningFeeding = feedingDetails['eveningFeeding'] ?? false;
    final String eveningTime = feedingDetails['eveningTime'] ?? 'N/A';
    final String eveningFoodGrams =
        feedingDetails['eveningFoodGrams'] ?? 'N/A'; // New: Evening Food Grams

    // Extracting nested vaccination record details
    final Map<String, dynamic> vaccinationRecord =
        bookingData['vaccinationRecord'] ?? {};
    final String vaccinationImageUrl = vaccinationRecord['imageUrl'] ?? '';

    // Extracting nested payment details (might be present for Boarding)
    final Map<String, dynamic> paymentDetails =
        bookingData['paymentDetails'] ?? {};
    final String paymentMethod = paymentDetails['method'] ?? 'N/A';
    final String accountNumber = paymentDetails['accountNumber'] ?? 'N/A';
    final String accountName = paymentDetails['accountName'] ?? 'N/A';
    final String receiptImageUrl = paymentDetails['receiptImageUrl'] ?? '';

    // Extracting nested boarding details
    final Map<String, dynamic> boardingDetails =
        bookingData['boardingDetails'] ?? {};
    final String checkInDateBoarding = boardingDetails['checkInDate'] ?? 'N/A';
    final String checkOutDateBoarding =
        boardingDetails['checkOutDate'] ?? 'N/A';
    final String selectedRoomType =
        boardingDetails['selectedRoomType'] ?? 'N/A';
    final bool boardingWaiverAgreed =
        boardingDetails['boardingWaiverAgreed'] ?? false;

    // Extracting nested grooming details
    final Map<String, dynamic> groomingDetails =
        bookingData['groomingDetails'] ?? {};
    final String groomingCheckInDate =
        groomingDetails['groomingCheckInDate'] ?? 'N/A';
    final bool groomingWaiverAgreed =
        groomingDetails['groomingWaiverAgreed'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: Colors.orange.shade300,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Pet Name and Status
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.orange.shade100,
                  // FIX: Direct NetworkImage if URL exists, else null
                  backgroundImage: petProfileImageUrl.isNotEmpty
                      ? NetworkImage(petProfileImageUrl)
                      : null,
                  child: petProfileImageUrl.isEmpty
                      ? Icon(
                          Icons.pets,
                          color: Colors.orange.shade700,
                          size: 24,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  petName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'Accepted' || status == 'Approved'
                        ? Colors.green.shade100
                        : status == 'Pending'
                        ? Colors.orange.shade100
                        : status == 'Rejected'
                        ? Colors.red.shade100
                        : status == 'Cancelled'
                        ? Colors
                              .red
                              .shade100 // Consistent color for cancelled
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: status == 'Accepted' || status == 'Approved'
                          ? Colors.green.shade700
                          : status == 'Pending'
                          ? Colors.orange.shade700
                          : status == 'Rejected'
                          ? Colors.red.shade700
                          : status == 'Cancelled'
                          ? Colors
                                .red
                                .shade700 // Consistent color for cancelled
                          : Colors.grey.shade700,
                    ),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                      color: status == 'Accepted' || status == 'Approved'
                          ? Colors.green.shade700
                          : status == 'Pending'
                          ? Colors.orange.shade700
                          : status == 'Rejected'
                          ? Colors.red.shade700
                          : status == 'Cancelled'
                          ? Colors.red.shade700
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main Booking Information
            _buildInfoCard(
              title: 'Booking Overview',
              icon: Icons.info_outline,
              children: [
                _buildDetailRow('Booking ID:', widget.bookingId),
                _buildDetailRow('Service Type:', serviceType),
                _buildDetailRow(
                  'Submitted On:',
                  timestamp != null
                      ? DateFormat(
                          'MMM dd, yyyy hh:mm a',
                        ).format(timestamp.toDate())
                      : 'N/A',
                ),
                _buildDetailRow('Booking Time:', bookingTime),
                _buildDetailRow('Admin Notes:', adminNotes),
                if (status == 'Pending' && effectivePendingReason.isNotEmpty)
                  _buildDetailRow('Pending For:', effectivePendingReason),
              ],
            ),
            const SizedBox(height: 20),

            // Owner Information Card
            _buildInfoCard(
              title: 'Owner Information',
              icon: Icons.person,
              children: [
                _buildDetailRow('First Name:', ownerFirstName),
                _buildDetailRow('Last Name:', ownerLastName),
                _buildDetailRow('Email:', ownerEmail),
                _buildDetailRow('Contact No:', ownerContactNo),
                _buildDetailRow('Address:', ownerAddress),
              ],
            ),
            const SizedBox(height: 20),

            // Pet Information Card
            _buildInfoCard(
              title: 'Pet Information',
              icon: Icons.pets,
              children: [
                _buildDetailRow('Pet Name:', petName),
                _buildDetailRow('Pet Type:', petType),
                _buildDetailRow('Breed:', petBreed),
                _buildDetailRow('Gender:', petGender),
                _buildDetailRow('Weight:', '$petWeight kg'),
                _buildDetailRow('Date of Birth:', petDateOfBirth),
                if (petProfileImageUrl.isNotEmpty)
                  _buildImageRow('Pet Profile Image:', petProfileImageUrl),
              ],
            ),
            const SizedBox(height: 20),

            // Service Type Specific Details
            if (serviceType == 'Boarding') ...[
              _buildInfoCard(
                title: 'Boarding Details',
                icon: Icons.hotel,
                children: [
                  _buildDetailRow('Check-in Date:', checkInDateBoarding),
                  _buildDetailRow('Check-out Date:', checkOutDateBoarding),
                  _buildDetailRow('Room Type:', selectedRoomType),
                  _buildDetailRow(
                    'Waiver Agreed:',
                    boardingWaiverAgreed ? 'Yes' : 'No',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildInfoCard(
                title: 'Feeding Details',
                icon: Icons.fastfood,
                children: [
                  _buildDetailRow('Food Brand:', foodBrand),
                  _buildDetailRow('Meals per day:', numberOfMeals),
                  if (morningFeeding) ...[
                    _buildDetailRow('Morning Feed:', morningTime),
                    _buildDetailRow(
                      'Morning Food Grams:',
                      '$morningFoodGrams grams',
                    ),
                  ],
                  if (afternoonFeeding) ...[
                    _buildDetailRow('Afternoon Feed:', afternoonTime),
                    _buildDetailRow(
                      'Afternoon Food Grams:',
                      '$afternoonFoodGrams grams',
                    ),
                  ],
                  if (eveningFeeding) ...[
                    _buildDetailRow('Evening Feed:', eveningTime),
                    _buildDetailRow(
                      'Evening Food Grams:',
                      '$eveningFoodGrams grams',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              _buildInfoCard(
                title: 'Payment Details',
                icon: Icons.payment,
                children: [
                  _buildDetailRow('Method:', paymentMethod),
                  _buildDetailRow('Account Number:', accountNumber),
                  _buildDetailRow('Account Name:', accountName),
                  if (receiptImageUrl.isNotEmpty)
                    _buildImageRow('Receipt Image:', receiptImageUrl),
                ],
              ),
              const SizedBox(height: 20),
            ] else if (serviceType == 'Grooming') ...[
              _buildInfoCard(
                title: 'Grooming Details',
                icon: Icons.clean_hands,
                children: [
                  _buildDetailRow('Check-in Date:', groomingCheckInDate),
                  _buildDetailRow(
                    'Waiver Agreed:',
                    groomingWaiverAgreed ? 'Yes' : 'No',
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Vaccination Record (common for both, but might be explicitly saved)
            _buildInfoCard(
              title: 'Vaccination Record',
              icon: Icons.medical_services,
              children: [
                if (vaccinationImageUrl.isNotEmpty)
                  _buildImageRow(
                    'Vaccination Record Image:',
                    vaccinationImageUrl,
                  )
                else
                  _buildDetailRow(
                    'Status:',
                    'Not provided for this booking (or linked from profile).',
                  ),
              ],
            ),
            const SizedBox(height: 30),

            // Action Buttons: Update and Cancel
            // FIX 2: Added 'Approved' status to allow rescheduling/updates
            if ((_currentBookingStatus == 'Pending' ||
                    _currentBookingStatus == 'Accepted' ||
                    _currentBookingStatus == 'Approved') &&
                !_isLoading) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showUpdateDialog(bookingData),
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label: const Text('Update Booking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _cancelBooking,
                      icon: const Icon(Icons.cancel, color: Colors.white),
                      label: const Text('Cancel Booking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  // Helper for consistent detail rows
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, // Fixed width for labels for alignment
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  // Helper to build a card for a section of information
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...children, // Spread the list of detail rows or other widgets
          ],
        ),
      ),
    );
  }

  // Helper to build a row that displays an image from a URL
  Widget _buildImageRow(String label, String imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(10),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 80,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Image failed to load.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              child: Image.network(
                imageUrl,
                height: 150, // Fixed height for display in card
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    children: [
                      const Icon(
                        Icons.broken_image,
                        color: Colors.red,
                        size: 50,
                      ),
                      const Text(
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
}
