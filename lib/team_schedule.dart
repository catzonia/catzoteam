import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catzoteam/widgets/section_box.dart';
import 'package:provider/provider.dart';
import 'provider.dart'; 

class TeamScheduleScreen extends StatefulWidget {
  final String selectedBranchCode;
  
  const TeamScheduleScreen({required this.selectedBranchCode});

  @override
  _TeamScheduleScreenState createState() => _TeamScheduleScreenState();
}

class _TeamScheduleScreenState extends State<TeamScheduleScreen> {
  DateTime _selectedMonth = DateTime.now();
  Map<DateTime, List<Map<String, String>>> _schedules = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + (2 * delta), 1);
      _isLoading = true;
      _fetchSchedules();
    });
  }

  Future<void> _fetchSchedules() async {
    try {
      DateTime secondMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      String yearMonth1 = DateFormat('yyyy-MM').format(_selectedMonth);
      String yearMonth2 = DateFormat('yyyy-MM').format(secondMonth);

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('schedules')
          .where('branchId', isEqualTo: widget.selectedBranchCode)
          .where('yearMonth', whereIn: [yearMonth1, yearMonth2])
          .get();

      Map<DateTime, List<Map<String, String>>> tempSchedules = {};
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        DateTime date = DateFormat('yyyy-MM-dd').parse(data['date']);
        DateTime normalizedDate = DateTime(date.year, date.month, date.day);
        tempSchedules[normalizedDate] ??= [];
        tempSchedules[normalizedDate]!.add({
          'staffName': data['staffName'],
          'shift': data['shift'],
        });
      }

      setState(() {
        _schedules = tempSchedules;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching schedules: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showStaffDialog(DateTime date) {
    final staffList = _schedules[DateTime(date.year, date.month, date.day)] ?? [];
    final workingStaff = staffList.where((s) => s['shift'] == 'Morning' || s['shift'] == 'Evening' || s['shift'] == 'Full Day').map((s) => s['staffName']!).toList();
    final standbyStaff = staffList.where((s) => s['shift'] == 'Standby').map((s) => s['staffName']!).toList();
    final leaveStaff = staffList.where((s) => s['shift'] == 'Day Off').map((s) => s['staffName']!).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.all(20),
        title: Center(
          child: Text(
            'Staff on ${DateFormat('d MMMM').format(date)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        content: Container(
          width: 700,
          height: 250,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey[100]!, Colors.grey[200]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildStaffColumn('Working', Colors.green, workingStaff, Icons.person_rounded, date),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStaffColumn('On Standby', Colors.yellow[700]!, standbyStaff, Icons.person_rounded, date),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStaffColumn('On Leave', Colors.red, leaveStaff, Icons.person_rounded, date),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffColumn(String title, Color color, List<String> staff, IconData icon, DateTime date) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
        ),
        const SizedBox(height: 10),
        staff.isNotEmpty
            ? Column(
                children: staff.map((staffName) {
                  final username = taskProvider.fullNameToUsername[staffName] 
                                ?? taskProvider.fullNameToUsername.entries.firstWhere(
                                  (entry) => staffName.toLowerCase().contains(entry.key.toLowerCase()),
                                  orElse: () => MapEntry(staffName, staffName),
                                ).value;                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(icon, color: color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            username,
                            style: const TextStyle(fontSize: 14),
                            softWrap: true,
                            maxLines: null,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            : Text('None', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime secondMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionBox(
              title: "Schedule", 
              icon: Icons.calendar_today_rounded, 
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _buildCalendar(_selectedMonth, secondMonth)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(DateTime month1, DateTime month2) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Colors.orange),
              onPressed: () => _changeMonth(-1),
            ),
            Text(
              '${DateFormat('MMMM yyyy').format(month1)} - ${DateFormat('MMMM yyyy').format(month2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: Colors.orange),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _buildSingleMonthCalendar(month1)),
            Expanded(child: _buildSingleMonthCalendar(month2)),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleMonthCalendar(DateTime month) {
    final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final DateTime today = DateTime.now();
    DateTime firstDayOfMonth = DateTime(month.year, month.month, 1);
    int startingWeekday = firstDayOfMonth.weekday % 7;
    int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    int totalBoxes = startingWeekday + daysInMonth;
    int totalRows = (totalBoxes / 7).ceil();
    int gridItemCount = totalRows * 7;

    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: daysOfWeek
                .map((day) => Expanded(
                      child: Center(
                        child: Text(day, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: gridItemCount,
            itemBuilder: (context, index) {
              int dayNum = index - startingWeekday + 1;
              bool isValidDay = dayNum > 0 && dayNum <= daysInMonth;
              DateTime currentDate = DateTime(month.year, month.month, dayNum);
              final staffList = isValidDay ? _schedules[currentDate] ?? [] : [];
              int workingStaffCount = staffList.where((s) => s['shift'] == 'Morning' || s['shift'] == 'Evening' || s['shift'] == 'Full Day').length;
              int standbyStaffCount = staffList.where((s) => s['shift'] == 'Standby').length;
              int leaveStaffCount = staffList.where((s) => s['shift'] == 'Day Off').length;
              bool isToday = isValidDay &&
                  today.year == month.year &&
                  today.month == month.month &&
                  today.day == dayNum;

              return GestureDetector(
                onTap: isValidDay ? () => _showStaffDialog(currentDate) : null,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: isValidDay
                        ? LinearGradient(
                            colors: isToday
                                ? [Colors.orange[50]!, Colors.orange[100]!]
                                : [Colors.white, Colors.grey[100]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: !isValidDay ? Colors.grey[50] : null,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isValidDay
                        ? [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 6, spreadRadius: 1)]
                        : [],
                    border: isToday ? Border.all(color: Colors.orange[800]!, width: 2) : null,
                  ),
                  child: Stack(
                    children: [
                      if (isValidDay)
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isToday ? Colors.orange[900] : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      if (isValidDay)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (workingStaffCount > 0)
                                Row(children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$workingStaffCount', style: const TextStyle(fontSize: 10, color: Colors.green)),
                                ]),
                              if (standbyStaffCount > 0)
                                Row(children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(color: Colors.yellow[700], shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$standbyStaffCount', style: TextStyle(fontSize: 10, color: Colors.yellow[700])),
                                ]),
                              if (leaveStaffCount > 0)
                                Row(children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$leaveStaffCount', style: const TextStyle(fontSize: 10, color: Colors.red)),
                                ]),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}