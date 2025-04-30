import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:catzoteam/provider.dart';
import 'dart:async';

class AttendanceScreen extends StatefulWidget {
  final String userRole;
  final String userName;

  const AttendanceScreen({
    required this.userRole,
    required this.userName,
    super.key,
  });

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  Timer? _timer;
  Timer? _autoClockOutTimer;
  Duration _shiftDuration = Duration.zero;
  DateTime? _selectedDate;
  Future<List<Map<String, dynamic>>>? _attendanceDataFuture;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startAutoClockOutChecker();
    _fetchAttendanceData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoClockOutTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    if (taskProvider.isClockedIn(widget.userName)) {
      DateTime? startTime = taskProvider.getShiftStartTime(widget.userName);
      if (startTime != null) {
        _shiftDuration = DateTime.now().difference(startTime);
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _shiftDuration = DateTime.now().difference(startTime);
          });
        });
      }
    }
  }

  void _startAutoClockOutChecker() {
    _autoClockOutTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      if (taskProvider.isClockedIn(widget.userName)) {
        await taskProvider.checkAndAutoClockOut(widget.userName);
        if (!taskProvider.isClockedIn(widget.userName)) {
          setState(() {
            _statusMessage = 'Auto clocked out at ${DateFormat('hh:mm:ss a').format(DateTime.now())}';
            _shiftDuration = Duration.zero;
            _timer?.cancel();
            _fetchAttendanceData();
          });
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final isNegative = duration.isNegative;
    final absDuration = duration.abs();
    final hours = twoDigits(absDuration.inHours);
    final minutes = twoDigits(absDuration.inMinutes.remainder(60));
    final seconds = twoDigits(absDuration.inSeconds.remainder(60));
    return isNegative ? '-$hours:$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _fetchAttendanceData();
      });
    }
  }

  void _fetchAttendanceData() {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    if (_selectedDate != null) {
      // Fetch for a specific selected date
      final dateToFetch = _selectedDate!;
      _attendanceDataFuture = taskProvider
          .getUserClockRecords(widget.userName, date: dateToFetch)
          .first
          .then((records) {
            print('Fetched ${records.length} records for ${widget.userName} on ${DateFormat('yyyyMMdd').format(dateToFetch)}: $records');
            return records;
          })
          .catchError((error) {
            print('Error fetching attendance: $error');
            return <Map<String, dynamic>>[];
          });
    } else {
      // Fetch for the past 7 days
      final now = DateTime.now();
      final dates = List.generate(7, (index) => now.subtract(Duration(days: index)));
      _attendanceDataFuture = Future.wait(
        dates.map((date) => taskProvider
            .getUserClockRecords(widget.userName, date: date)
            .first
            .then((records) {
              print('Fetched ${records.length} records for ${widget.userName} on ${DateFormat('yyyyMMdd').format(date)}: $records');
              return records;
            })
            .catchError((error) {
              print('Error fetching attendance for ${DateFormat('yyyyMMdd').format(date)}: $error');
              return <Map<String, dynamic>>[];
            })),
      ).then((listOfRecords) {
        // Flatten and sort records by date descending
        final allRecords = listOfRecords.expand((records) => records).toList();
        allRecords.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
        return allRecords;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildClockInterface(),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 15),
              Text(
                _statusMessage,
                style: TextStyle(
                  color: _statusMessage.contains('Error') ? Colors.red : Colors.green,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 20),
            _buildSectionBox(
              "Attendance Log",
              Icons.history,
              _buildHistoryContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionBox(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.orange, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.orange),
                onPressed: () {
                  setState(() {
                    _fetchAttendanceData();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildClockInterface() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        bool isClockedIn = taskProvider.isClockedIn(widget.userName);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: isClockedIn
                  ? ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _showClockOutConfirmation(context),
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text('Clock Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _showClockInConfirmation(context),
                      icon: const Icon(Icons.login, size: 20),
                      label: const Text('Clock In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                    ),
            ),
            if (isClockedIn) ...[
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Shift Duration: ${_formatDuration(_shiftDuration)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showClockInConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: const Text(
            "Confirm Clock In",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          content: const Text(
            "Are you sure you want to clock in now?",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _clockIn();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                "Confirm",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showClockOutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: const Text(
            "Confirm Clock Out",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          content: const Text(
            "Are you sure you want to clock out now?",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _clockOut();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                "Confirm",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clockIn() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      await taskProvider.clockIn(widget.userName);
      _startTimer();
      setState(() {
        _statusMessage = 'Successfully clocked in!';
        _isLoading = false;
        _fetchAttendanceData();
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _clockOut() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      await taskProvider.clockOut(widget.userName);
      _timer?.cancel();
      _shiftDuration = Duration.zero;
      setState(() {
        _statusMessage = 'Successfully clocked out!';
        _isLoading = false;
        _fetchAttendanceData();
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildHistoryContent() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDate == null
                      ? 'Select Date'
                      : DateFormat('dd MMMM yyyy').format(_selectedDate!),
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedDate == null ? Colors.grey : Colors.black87,
                  ),
                ),
                const Icon(Icons.calendar_today, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        if (_selectedDate != null)
          TextButton(
            onPressed: () => setState(() {
              _selectedDate = null;
              _fetchAttendanceData();
            }),
            child: const Text(
              'Clear Date Filter',
              style: TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        const SizedBox(height: 15),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _attendanceDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final records = snapshot.data ?? [];

            if (records.isEmpty) {
              return const Center(
                child: Text(
                  'No clock history yet.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              );
            }

            final Map<String, List<Map<String, dynamic>>> groupedHistory = {};
            for (var record in records) {
              final date = DateFormat('dd MMMM yyyy').format(record['date']);
              groupedHistory.putIfAbsent(date, () => []).add(record);
            }

            return Column(
              children: groupedHistory.entries.map((entry) {
                final date = entry.key;
                final dayRecords = entry.value;

                Duration totalHoursWorked = Duration.zero;
                for (var record in dayRecords) {
                  final clockIn = record['clockIn'] as DateTime?;
                  final clockOut = record['clockOut'] as DateTime?;
                  if (clockIn != null && clockOut != null && clockOut.isAfter(clockIn)) {
                    totalHoursWorked += clockOut.difference(clockIn);
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...dayRecords.map((record) {
                      final clockIn = record['clockIn'] as DateTime?;
                      final clockOut = record['clockOut'] as DateTime?;
                      final isAutoClockOut = record['autoClockOut'] == true;
                      return Column(
                        children: [
                          if (clockIn != null)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green[50]!, Colors.grey[50]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 2,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.login, color: Colors.green, size: 20),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Clocked in',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          DateFormat('hh:mm:ss a').format(clockIn),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (clockOut != null)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red[50]!, Colors.grey[50]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 2,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.logout, color: Colors.red, size: 20),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isAutoClockOut ? 'Clocked out (Auto)' : 'Clocked out',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          DateFormat('hh:mm:ss a').format(clockOut),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                    if (totalHoursWorked != Duration.zero) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Total Hours Worked: ${_formatDuration(totalHoursWorked)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}