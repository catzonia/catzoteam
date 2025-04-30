import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:catzoteam/provider.dart';

class LeaveApplicationScreen extends StatefulWidget {
  final String userRole;
  final String userName;

  const LeaveApplicationScreen({required this.userRole, required this.userName, super.key});

  @override
  _LeaveApplicationScreenState createState() => _LeaveApplicationScreenState();
}

class _LeaveApplicationScreenState extends State<LeaveApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _leaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isMorningLeave = false;
  bool _isEveningLeave = false;
  Map<DateTime, String?> _replacements = {};
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _leaveTypes = [
    'Annual',
    'Emergency',
    'Leave In Lieu',
    'Medical',
    'Public Holiday',
    'Unpaid',
  ];

  final List<String> _halfDayLeaveTypes = [
    'Annual',
    'Leave In Lieu',
    'Public Holiday',
    'Unpaid',
  ];

  double get _totalDays {
    if (_startDate == null || _endDate == null) return 0.0;
    final difference = _endDate!.difference(_startDate!).inDays + 1;
    if (_startDate!.year == _endDate!.year &&
        _startDate!.month == _endDate!.month &&
        _startDate!.day == _endDate!.day) {
      if (_isMorningLeave || _isEveningLeave) {
        return 0.5;
      }
    }
    return difference.toDouble();
  }

  bool get _isSingleDay {
    if (_startDate == null || _endDate == null) return false;
    return _startDate!.year == _endDate!.year &&
        _startDate!.month == _endDate!.month &&
        _startDate!.day == _endDate!.day;
  }

  bool get _supportsHalfDay {
    return _leaveType != null && _halfDayLeaveTypes.contains(_leaveType);
  }

  List<DateTime> get _leaveDates {
    if (_startDate == null || _endDate == null) return [];
    List<DateTime> dates = [];
    for (int i = 0; i <= _endDate!.difference(_startDate!).inDays; i++) {
      dates.add(_startDate!.add(Duration(days: i)));
    }
    return dates;
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.orange,
            colorScheme: const ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
            ),
            dialogBackgroundColor: Colors.white,
            textTheme: const TextTheme(
              headlineMedium: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          _startDateController.text = '${picked.day}/${picked.month}/${picked.year}';
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
            _endDateController.text = '';
          }
        } else {
          _endDate = picked;
          _endDateController.text = '${picked.day}/${picked.month}/${picked.year}';
        }
        if (!_isSingleDay || !_supportsHalfDay) {
          _isMorningLeave = false;
          _isEveningLeave = false;
        }
        _replacements.clear();
        for (var date in _leaveDates) {
          _replacements[date] = null;
        }
      });
    }
  }

  void _submitLeaveApplication() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      final leaveApplication = {
        'userRole': widget.userRole,
        'applicant': widget.userName,
        'leaveType': _leaveType,
        'startDate': _startDate?.toIso8601String(),
        'endDate': _endDate?.toIso8601String(),
        'isMorningLeave': _isMorningLeave,
        'isEveningLeave': _isEveningLeave,
        'replacements': _replacements.map((date, staff) => MapEntry(date.toIso8601String(), staff)),
        'totalDays': _totalDays,
        'reason': _reasonController.text,
        'status': 'Pending',
        'submissionDate': DateTime.now().toIso8601String(),
      };

      try {
        final taskProvider = Provider.of<TaskProvider>(context, listen: false);
        await taskProvider.submitLeaveApplication(leaveApplication);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _leaveType = null;
          _startDate = null;
          _endDate = null;
          _startDateController.text = '';
          _endDateController.text = '';
          _isMorningLeave = false;
          _isEveningLeave = false;
          _replacements.clear();
          _reasonController.clear();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit leave application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                color: Colors.white, // Set Card background to white
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.article_rounded, color: Colors.orange, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Leave Application Form',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        margin: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _leaveType,
                              items: _leaveTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(
                                    type,
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _leaveType = value;
                                  if (!_supportsHalfDay) {
                                    _isMorningLeave = false;
                                    _isEveningLeave = false;
                                  }
                                });
                              },
                              validator: (value) => value == null ? 'Please select a leave type' : null,
                              decoration: InputDecoration(
                                labelText: 'Leave Type',
                                labelStyle: TextStyle(
                                  color: _leaveType == null ? Colors.grey : Colors.orange,
                                  fontWeight: _leaveType == null ? FontWeight.normal : FontWeight.bold,
                                ),
                                floatingLabelStyle: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.orange),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Start Date and End Date
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _startDateController,
                                    readOnly: true,
                                    onTap: () => _selectDate(context, true),
                                    style: const TextStyle(color: Colors.orange),
                                    decoration: InputDecoration(
                                      labelText: 'Start Date',
                                      hintText: 'Select Start Date',
                                      hintStyle: const TextStyle(color: Colors.grey),
                                      labelStyle: TextStyle(
                                        color: _startDate == null ? Colors.grey : Colors.orange,
                                        fontWeight: _startDate == null ? FontWeight.normal : FontWeight.bold,
                                      ),
                                      floatingLabelStyle: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Colors.orange),
                                      ),
                                    ),
                                    validator: (value) => value!.isEmpty ? 'Please select a start date' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _endDateController,
                                    readOnly: true,
                                    onTap: () => _selectDate(context, false),
                                    style: const TextStyle(color: Colors.orange),
                                    decoration: InputDecoration(
                                      labelText: 'End Date',
                                      hintText: 'Select End Date',
                                      hintStyle: const TextStyle(color: Colors.grey),
                                      labelStyle: TextStyle(
                                        color: _endDate == null ? Colors.grey : Colors.orange,
                                        fontWeight: _endDate == null ? FontWeight.normal : FontWeight.bold,
                                      ),
                                      floatingLabelStyle: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Colors.orange),
                                      ),
                                    ),
                                    validator: (value) => value!.isEmpty ? 'Please select an end date' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (_isSingleDay && _supportsHalfDay) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _isMorningLeave,
                                          onChanged: (value) {
                                            setState(() {
                                              _isMorningLeave = value ?? false;
                                              if (_isMorningLeave) {
                                                _isEveningLeave = false;
                                              }
                                            });
                                          },
                                        ),
                                        const Text('Morning Leave'),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _isEveningLeave,
                                          onChanged: (value) {
                                            setState(() {
                                              _isEveningLeave = value ?? false;
                                              if (_isEveningLeave) {
                                                _isMorningLeave = false;
                                              }
                                            });
                                          },
                                        ),
                                        const Text('Evening Leave'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    readOnly: true,
                                    controller: TextEditingController(
                                      text: _totalDays == 0.0 ? '' : _totalDays.toString(),
                                    ),
                                    style: const TextStyle(color: Colors.orange),
                                    decoration: InputDecoration(
                                      labelText: 'Total Day(s)',
                                      labelStyle: TextStyle(
                                        color: _totalDays == 0.0 ? Colors.grey : Colors.orange,
                                        fontWeight: _totalDays == 0.0 ? FontWeight.normal : FontWeight.bold,
                                      ),
                                      floatingLabelStyle: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Colors.orange),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Days',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // "Find Replacement" Section
                            if (_startDate == null || _endDate == null) ...[
                              DropdownButtonFormField<String>(
                                value: null,
                                items: const [],
                                onChanged: null, // Disabled
                                decoration: InputDecoration(
                                  labelText: 'Find Replacement',
                                  labelStyle: const TextStyle(
                                    color: Colors.grey, // Grey label
                                    fontWeight: FontWeight.normal,
                                  ),
                                  hintStyle: const TextStyle(color: Colors.grey),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey[300]!), // Grey border
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                              ),
                            ] else ...[
                              ..._leaveDates.map((date) {
                                return FutureBuilder<List<String>>(
                                  future: taskProvider.getFirestoreStandbyStaff(date, excludeStaff: widget.userName),
                                  builder: (context, snapshot) {
                                    List<String> standbyStaff = snapshot.data ?? [];

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${date.day}/${date.month}/${date.year}',
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: DropdownButtonFormField<String>(
                                              value: _replacements[date],
                                              items: standbyStaff.map((staff) {
                                                return DropdownMenuItem<String>(
                                                  value: staff,
                                                  child: Text(
                                                    staff,
                                                    style: const TextStyle(
                                                      color: Colors.orange,
                                                      fontWeight: FontWeight.normal,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _replacements[date] = value;
                                                });
                                              },
                                              decoration: InputDecoration(
                                                labelText: 'Select',
                                                labelStyle: TextStyle(
                                                  color: _replacements[date] == null ? Colors.grey : Colors.orange,
                                                  fontWeight: _replacements[date] == null ? FontWeight.normal : FontWeight.bold,
                                                ),
                                                floatingLabelStyle: const TextStyle(
                                                  color: Colors.orange,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: const BorderSide(color: Colors.orange),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              })
                            ],
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _reasonController,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.orange),
                              decoration: InputDecoration(
                                labelText: 'Leave Reason',
                                hintText: 'Enter your reason for leave...',
                                hintStyle: const TextStyle(color: Colors.grey),
                                labelStyle: TextStyle(
                                  color: _reasonController.text.isEmpty ? Colors.grey : Colors.orange,
                                  fontWeight: _reasonController.text.isEmpty ? FontWeight.normal : FontWeight.bold,
                                ),
                                floatingLabelStyle: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.orange),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please provide a reason for your leave';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting || _startDate == null || _endDate == null ? null : _submitLeaveApplication,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _startDate == null || _endDate == null ? Colors.grey : Colors.orange,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Apply ${_totalDays == 0.0 ? '0' : _totalDays} Day(s) Leave',
                                        style: const TextStyle(fontSize: 16, color: Colors.white),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}