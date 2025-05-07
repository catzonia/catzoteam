import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catzoteam/models/double.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';

class TaskProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _availableTasks = [];
  List<Map<String, dynamic>> _assignedTasks = [];
  List<Map<String, dynamic>> _completedTasks = [];
  List<Map<String, dynamic>> _clockRecords = [];

  Map<DateTime, List<String>> _staffSchedule = {};
  Map<DateTime, List<String>> _staffStandbySchedule = {};
  Map<DateTime, List<String>> _staffLeaveSchedule = {};

  Map<String, double> staffDailyPoints = {};
  Map<String, double> staffMonthlyPoints = {};
  Map<String, double> staffDailyDeficit = {};
  Map<String, String> staffSelectedTrenche = {};
  Map<String, DateTime?> staffLastDailyResetDate = {};
  Map<String, DateTime?> staffLastMonthlyResetDate = {};

  Map<String, Map<String, double>> staffBadges = {};
  Map<String, double> getStaffBadges(String staffName) {
    return staffBadges[staffName] ?? {
      'badge45': 0.0,
      'badge55': 0.0,
      'badge65': 0.0,
      'badge75': 0.0,
      'badge85': 0.0,
    };
  }

  Map<String, bool> _staffClockedIn = {};
  Map<String, DateTime?> _staffShiftStartTime = {};

  Map<String, String> _staffNrics = {};

  Map<String, String> _fullNameToUsername = {};
  Map<String, String> get fullNameToUsername => _fullNameToUsername;

  final Map<String, double> _trencheTargetPoints = {
    "35": 38.0,
    "40": 43.0,
    "45": 48.0,
    "50": 53.0,
    "55": 58.0,
    "60": 63.0,
  };

  static const List<String> priorityLevels = ["no", "low", "medium", "high"];

  String _branchId;
  String get branchId => _branchId;

  TaskProvider({required String branchId}) : _branchId = branchId {
    print('TaskProvider initialized with branch: $_branchId');
    _initializeStaffSchedule();
    _fetchTasksFromFirestore();
    _loadStaffNrics();
    // Delay reset check to avoid race conditions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAllStaffResets();
    });
  }

  void setBranchId(String newBranchId) {
    if (_branchId != newBranchId) {
      _branchId = newBranchId;

      // Clear all state
      _availableTasks.clear();
      _assignedTasks.clear();
      _completedTasks.clear();
      _staffNrics.clear();
      _staffClockedIn.clear();
      _staffShiftStartTime.clear();
      staffDailyPoints.clear();
      staffMonthlyPoints.clear();
      staffDailyDeficit.clear();
      staffSelectedTrenche.clear();
      staffLastDailyResetDate.clear();
      staffLastMonthlyResetDate.clear();
      staffBadges.clear();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
        _fetchTasksFromFirestore();
        _loadStaffNrics();
      });
    }
  }

  void _checkAllStaffResets() {
    for (String staff in _staffNrics.keys) {
      print('staffLastDailyResetDate for $staff: ${staffLastDailyResetDate[staff]}');
      _checkAndResetPoints(staff);
    }
  }

  Future<void> _loadStaffNrics() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('branch', isEqualTo: _branchId)
          .get();

      Map<String, String> tempStaffNrics = {};
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String username = data['username'] as String;
        _fullNameToUsername[data['fullname']] = username;
        String nric = doc.id;
        tempStaffNrics[capitalizeEachWord(username)] = nric;
      }

      _staffNrics = tempStaffNrics;
      print('Loaded staff NRICs: $_staffNrics');

      for (var staff in _staffNrics.keys) {
        _staffClockedIn[staff] = false;
        _staffShiftStartTime[staff] = null;
        
        // Only initialize if today's doc doesn't exist
        String nric = _staffNrics[staff] ?? 'unknown';
        String todayDocId = DateFormat('yyyyMMdd').format(DateTime.now());
        final ref = FirebaseFirestore.instance
            .collection('points')
            .doc('staff')
            .collection(todayDocId)
            .doc(nric);

        ref.get().then((snapshot) {
          if (!snapshot.exists) {
            print('No doc for $staff on startup, initializing...');
            _initializePointsForStaff(staff);
          } else {
            print('Points doc exists for $staff, skipping init');
          }
        });

        _listenToPointsData(staff);
      }
      await _loadClockData();
      notifyListeners();
    } catch (e) {
      print('Error loading staff NRICs: $e');
    }
  }

  String capitalizeEachWord(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  void _listenToPointsData(String staffName) {
    String nric = _staffNrics[staffName] ?? 'unknown';
    if (nric == 'unknown') {
      print('Warning: NRIC not found for $staffName');
      return;
    }

    String todayDocId = DateFormat('yyyyMMdd').format(DateTime.now());
    print('Setting up listener for $staffName at points/staff/$todayDocId/$nric');

    FirebaseFirestore.instance
        .collection('points')
        .doc('staff')
        .collection(todayDocId)
        .doc(nric)
        .snapshots()
        .listen((snapshot) {
          print('Received snapshot for $staffName at points/staff/$todayDocId/$nric');
          if (snapshot.exists) {
            print('[SNAPSHOT] Data exists for $staffName');
            var data = snapshot.data()!;
            // Update local state only if data exists
            staffDailyPoints[staffName] = data['dailyPoints']?.toDouble() ?? 0.0;
            staffMonthlyPoints[staffName] = data['monthlyPoints']?.toDouble() ?? 0.0;
            staffDailyDeficit[staffName] = data['dailyDeficit']?.toDouble() ?? 0.0;
            staffBadges[staffName] = {
              'badge45': data['badge45']?.toDouble() ?? 0.0,
              'badge55': data['badge55']?.toDouble() ?? 0.0,
              'badge65': data['badge65']?.toDouble() ?? 0.0,
              'badge75': data['badge75']?.toDouble() ?? 0.0,
              'badge85': data['badge85']?.toDouble() ?? 0.0,
            };
            staffSelectedTrenche[staffName] = data['selectedTrenche'] ?? "50";
            staffLastDailyResetDate[staffName] = data['lastDailyResetDate'] != null
                ? (data['lastDailyResetDate'] as Timestamp).toDate()
                : null;
            staffLastMonthlyResetDate[staffName] = data['lastMonthlyResetDate'] != null
                ? (data['lastMonthlyResetDate'] as Timestamp).toDate()
                : null;
            print('Updated $staffName: dailyPoints=${staffDailyPoints[staffName]}, monthlyPoints=${staffMonthlyPoints[staffName]}, dailyDeficit=${staffDailyDeficit[staffName]}');
            notifyListeners();
          } else {
            print('[SNAPSHOT] ❌ snapshot.exists == false for $staffName');
            print('No points document for $staffName, checking reset status...');
            _checkAndResetPoints(staffName);
          }
        }, onError: (e) {
          print('Error listening to points for $staffName: $e');
          if (e.toString().contains('PERMISSION_DENIED')) {
            print('Permission denied for $staffName at points/staff/$todayDocId/$nric');
          }
        });
  }

  Future<void> _initializePointsForStaff(String staffName) async {
    String nric = _staffNrics[staffName] ?? 'unknown';
    if (nric == 'unknown') {
      print('Cannot initialize points: NRIC not found for $staffName');
      return;
    }
    final now = DateTime.now();
    String todayDocId = DateFormat('yyyyMMdd').format(now);
    final ref = FirebaseFirestore.instance
        .collection('points')
        .doc('staff')
        .collection(todayDocId)
        .doc(nric);

    // Check if document already exists
    final snapshot = await ref.get();
    if (snapshot.exists) {
      print('Points document already exists for $staffName on $todayDocId. Skipping initialization.');
      return;
    }

    // Check if reset already happened today
    DateTime? lastReset = staffLastDailyResetDate[staffName];
    if  (lastReset != null &&
        lastReset.year == now.year &&
        lastReset.month == now.month &&
        lastReset.day == now.day) {
      print('Points already reset today for $staffName. Skipping initialization.');
      return;
    }

    DateTime yesterday = now.subtract(Duration(days: 1));
    String yesterdayDocId = DateFormat('yyyyMMdd').format(yesterday);
    final yesterdayRef = FirebaseFirestore.instance
        .collection('points')
        .doc('staff')
        .collection(yesterdayDocId)
        .doc(nric);

    double previousMonthlyPoints = 0.0;
    double previousDeficit = 0.0;
    bool isFirstDayOrMonth = now.day == 1;
    try {
      final yesterdaySnapshot = await yesterdayRef.get();
      if (yesterdaySnapshot.exists) {
        previousMonthlyPoints = yesterdaySnapshot.data()!['monthlyPoints']?.toDouble() ?? 0.0;
        previousDeficit = yesterdaySnapshot.data()!['dailyDeficit']?.toDouble() ?? 0.0;
        print('Fetched previous monthly points for $staffName: $previousMonthlyPoints, deficit: $previousDeficit');
      } else {
        isFirstDayOrMonth = true;
      }
    } catch (e) {
      print('Error fetching yesterday\'s points for $staffName: $e');
    }

    double initialDeficit = isFirstDayOrMonth
        ? (_trencheTargetPoints["50"] ?? 53.0)
        : previousDeficit + (_trencheTargetPoints["50"] ?? 53.0);

    try {
      await ref.set({
        'branch': _branchId,
        'fullname': staffName,
        'nric': nric,
        'dailyPoints': 0.0,
        'monthlyPoints': previousMonthlyPoints.toDouble(),
        'dailyDeficit': initialDeficit.toDouble(),
        'selectedTrenche': "50",
        'lastDailyResetDate': FieldValue.serverTimestamp(),
        'lastMonthlyResetDate': FieldValue.serverTimestamp(),
        'badge45': 0.0,
        'badge55': 0.0,
        'badge65': 0.0,
        'badge75': 0.0,
        'badge85': 0.0,
      }, SetOptions(merge: true));
      print('Initialized points for $staffName at points/staff/$todayDocId/$nric');
      print("Initializing $staffName with deficit: $initialDeficit (previous: $previousDeficit)");
      staffDailyPoints[staffName] = 0.0;
      staffMonthlyPoints[staffName] = previousMonthlyPoints;
      staffDailyDeficit[staffName] = initialDeficit;
      staffSelectedTrenche[staffName] = "50";
      staffLastDailyResetDate[staffName] = now;
      staffLastMonthlyResetDate[staffName] = now;
      notifyListeners();
    } catch (e) {
      print('Error initializing points for $staffName: $e');
      if (e.toString().contains('PERMISSION_DENIED')) {
        print('Permission denied. Ensure security rules allow creating subcollections under points/staff.');
      }
    }
  }

  Future<void> _loadClockData() async {
    final prefs = await SharedPreferences.getInstance();
    for (String staff in _staffNrics.keys) {
      _staffClockedIn[staff] = prefs.getBool('clockedIn_$staff') ?? false;
      String? shiftStartTimeString = prefs.getString('shiftStartTime_$staff');
      if (shiftStartTimeString != null) {
        _staffShiftStartTime[staff] = DateTime.parse(shiftStartTimeString);
      }

      String? clockRecordsJson = prefs.getString('clockRecords');
      if (clockRecordsJson != null) {
        final List<dynamic> decodedRecords = jsonDecode(clockRecordsJson);
        _clockRecords = decodedRecords.map((record) {
          return {
            'userName': record['userName'],
            'type': record['type'],
            'timestamp': DateTime.parse(record['timestamp']),
            'branchId': record['branchId'],
          };
        }).toList();
      }

      double? lastDailyPoints = prefs.getDouble('lastDailyPoints_$staff');
      double? lastDeficit = prefs.getDouble('lastDeficit_$staff');
      String? lastResetDateString = prefs.getString('lastResetDate_$staff');
      if (lastDailyPoints != null && lastDeficit != null && lastResetDateString != null) {
        try {
          DateTime lastResetDate = DateTime.parse(lastResetDateString);
          DateTime today = DateTime.now();
          DateTime todayNormalized = DateTime(today.year, today.month, today.day);
          DateTime lastResetNormalized = DateTime(lastResetDate.year, lastResetDate.month, lastResetDate.day);
          if (todayNormalized.isAfter(lastResetNormalized)) {
            print('Missed daily reset detected for $staff. Updating deficit...');
            double baseTarget = _trencheTargetPoints[staffSelectedTrenche[staff] ?? "50"] ?? 53.0;
            staffDailyDeficit[staff] = lastDeficit + baseTarget;
            print('Updated $staff dailyDeficit to ${staffDailyDeficit[staff]} due to missed reset');
            staffDailyPoints[staff] = 0.0;
            staffLastDailyResetDate[staff] = today;
            _updatePointsInFirestore(staff, _staffNrics[staff]!, DateFormat('yyyyMMdd').format(today));
            notifyListeners();
          }
        } catch (e) {
          print('Error processing missed reset for $staff: $e');
        }
      } else {
        print('No previous reset data found for $staff in SharedPreferences. Initializing...');
        staffLastDailyResetDate[staff] = DateTime.now().subtract(Duration(days: 1));
        _checkAndResetPoints(staff);
      }
    }
  }

  Future<void> _saveClockData(String staff) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('clockedIn_$staff', _staffClockedIn[staff] ?? false);
    if (_staffShiftStartTime[staff] != null) {
      await prefs.setString('shiftStartTime_$staff', _staffShiftStartTime[staff]!.toIso8601String());
    } else {
      await prefs.remove('shiftStartTime_$staff');
    }

    final clockRecordsToSave = _clockRecords.map((record) {
      return {
        'userName': record['userName'],
        'type': record['type'],
        'timestamp': (record['timestamp'] as DateTime).toIso8601String(),
        'branchId': record['branchId'],
      };
    }).toList();
    await prefs.setString('clockRecords', jsonEncode(clockRecordsToSave));
  }

  List<Map<String, dynamic>> get availableTasks => _availableTasks;
  List<Map<String, dynamic>> get assignedTasks => _assignedTasks;
  List<Map<String, dynamic>> get completedTasks => _completedTasks;
  List<Map<String, dynamic>> get displayedTasks => _availableTasks.where((task) => task["displayed"] == true).toList();
  List<Map<String, dynamic>> get clockRecords => _clockRecords;
  Map<DateTime, List<String>> get staffSchedule => _staffSchedule;
  Map<DateTime, List<String>> get staffStandbySchedule => _staffStandbySchedule;
  Map<DateTime, List<String>> get staffLeaveSchedule => _staffLeaveSchedule;

  void _fetchTasksFromFirestore() {
    String? parseTimestamp(dynamic value) {
      if (value == null) {
        print('parseTimestamp: Received null value');
        return null;
      }
      if (value is Timestamp) {
        return value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        final seconds = value['seconds'] as int?;
        final nanoseconds = value['nanoseconds'] as int?;
        if (seconds != null && nanoseconds != null) {
          return Timestamp(seconds, nanoseconds).toDate().toIso8601String();
        }
      }
      print('parseTimestamp: Invalid value format: $value');
      return null;
    }

    String? normalizeOrderID(dynamic bookingId) {
      if (bookingId == null || (bookingId is String && bookingId.trim().isEmpty)) {
        return null;
      }
      return bookingId.toString();
    }

    FirebaseFirestore.instance
        .collection('tasks')
        .where('status', isEqualTo: 'unassigned')
        .where('branchId', isEqualTo: _branchId)
        .snapshots()
        .listen((snapshot) {
          _availableTasks = snapshot.docs.map((doc) {
            var data = doc.data();
            return {
              "taskID": data['taskId'] ?? doc.id,
              "task": data['taskName'] ?? '',
              "orderID": normalizeOrderID(data['bookingId']),
              "catName": data['catName'] ?? '',
              "date": data['date'] ?? '',
              "time": data['time'] ?? '',
              "priority": data['priority'] ?? 'no',
              "displayed": data['displayed'] ?? false,
              "points": parsePoints(data['points']),
              "docId": doc.id,
            };
          }).toList();
          print('Unassigned tasks updated for branch $_branchId: $_availableTasks');
          notifyListeners();
        }, onError: (error) => print('Error fetching unassigned tasks: $error'));

    FirebaseFirestore.instance
        .collection('tasks')
        .where('status', isEqualTo: 'assigned')
        .where('branchId', isEqualTo: _branchId)
        .snapshots()
        .listen((snapshot) {
          _assignedTasks = snapshot.docs.map((doc) {
            var data = doc.data();
            return {
              "taskID": data['taskId'] ?? doc.id,
              "task": data['taskName'] ?? '',
              "orderID": normalizeOrderID(data['bookingId']),
              "catName": data['catName'] ?? '',
              "date": data['date'] ?? '',
              "time": data['time'] ?? '',
              "assignee": data['assigned'] ?? 'none',
              "assistant1": data['assistant1'] ?? 'none',
              "assistant2": data['assistant2'] ?? 'none',
              "priority": data['priority'] ?? 'no',
              "points": parsePoints(data['points']),
              "docId": doc.id,
            };
          }).toList();
          print('Assigned tasks updated for branch $_branchId: $_assignedTasks');
          notifyListeners();
        }, onError: (error) => print('Error fetching assigned tasks: $error'));

    FirebaseFirestore.instance
        .collection('tasks')
        .where('status', isEqualTo: 'completed')
        .where('branchId', isEqualTo: _branchId)
        .snapshots()
        .listen((snapshot) {
          final currentTaskIds = snapshot.docs.map((doc) => doc.id).toSet();
          final previouslyLoadedTaskIds = _completedTasks.map((task) => task['docId']).toSet();

          final deletedTasks = previouslyLoadedTaskIds.difference(currentTaskIds);

          for (String deletedId in deletedTasks) {
            final task = _completedTasks.firstWhere((t) => t['docId'] == deletedId, orElse: () => {});
            if (task.isNotEmpty) {
              final timestampStr = task['timestamp'];
              if (timestampStr != null && timestampStr.isNotEmpty) {
                final taskDate = DateTime.tryParse(timestampStr);
                if (taskDate != null) () async {
                  try {
                    await handleDeletedCompletedTask(
                      task['taskID'],
                      task['assignee'],
                      task['assistant1'],
                      task['assistant2'],
                      task['points'] ?? 0,
                      taskDate,
                    );
                  } catch (e) {
                    print('Error in handleDeletedCompletedTask: $e');
                  }
                }();
              }
            }
          }

          _completedTasks = snapshot.docs.map((doc) {
            var data = doc.data();
            return {
              "taskID": data['taskId'] ?? doc.id,
              "task": data['taskName'] ?? '',
              "orderID": normalizeOrderID(data['bookingId']),
              "catName": data['catName'] ?? '',
              "date": data['date'] ?? '',
              "time": data['time'] ?? '',
              "assignee": data['assigned'] ?? 'none',
              "assistant1": data['assistant1'] ?? 'none',
              "assistant2": data['assistant2'] ?? 'none',
              "completionDate": parseTimestamp(data['completionDate']) ?? '',
              "points": parsePoints(data['points']),
              "docId": doc.id,
            };
          }).toList();
          print('Completed tasks updated for branch $_branchId: $_completedTasks');
          notifyListeners();
        }, onError: (error) => print('Error fetching completed tasks: $error'));
  }

  Future<void> fixTaskCompletionDates() async {
    final tasks = await FirebaseFirestore.instance
        .collection('tasks')
        .where('status', isEqualTo: 'completed')
        .get();
    for (var doc in tasks.docs) {
      final data = doc.data();
      if (data['completionDate'] == null || data['completionDate'] == '') {
        print('Fixing task ${doc.id} with invalid completionDate');
        await doc.reference.update({
          'completionDate': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<List<String>> getFirestoreStandbyStaff(DateTime date, {String? excludeStaff}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    final snapshot = await FirebaseFirestore.instance
        .collection('schedules')
        .where('branchId', isEqualTo: _branchId)
        .where('date', isEqualTo: dateStr)
        .where('shift', isEqualTo: 'Standby')
        .get();

    List<String> standby = snapshot.docs
        .map((doc) => doc.data()['staffName'] as String)
        .where((name) => excludeStaff == null || name != excludeStaff)
        .toList();

    return standby;
  }

  void _initializeStaffSchedule() {
    final List<String> staffMembers = _staffNrics.keys.toList();
    for (int month = 1; month <= 12; month++) {
      int daysInMonth = DateTime(2025, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        DateTime date = DateTime(2025, month, day);
        List<String> availableStaff = List.from(staffMembers)..shuffle();

        List<String> leaveStaff = [];
        if (availableStaff.isNotEmpty && (day % 2 == 0 || day % 3 == 0)) {
          leaveStaff.add(availableStaff.removeAt(0));
        }
        _staffLeaveSchedule[date] = leaveStaff;

        List<String> workingStaff = [];
        int workingCount = (day % 2 == 0) ? 3 : 2;
        for (int i = 0; i < workingCount && availableStaff.isNotEmpty; i++) {
          workingStaff.add(availableStaff.removeAt(0));
        }
        _staffSchedule[date] = workingStaff;

        List<String> standbyStaff = [];
        int standbyCount = (availableStaff.length > 1) ? 2 : availableStaff.length;
        for (int i = 0; i < standbyCount && availableStaff.isNotEmpty; i++) {
          standbyStaff.add(availableStaff.removeAt(0));
        }
        _staffStandbySchedule[date] = standbyStaff;
      }
    }
    notifyListeners();
  }

  List<String> getStandbyStaffForDate(DateTime date, {String? excludeStaff}) {
    DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    List<String> standbyStaff = _staffStandbySchedule[normalizedDate] ?? [];
    if (excludeStaff != null) {
      standbyStaff = standbyStaff.where((staff) => staff != excludeStaff).toList();
    }
    return standbyStaff;
  }

  void _checkAndResetPoints(String staff) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonth = DateTime(now.year, now.month, 1);
    String nric = _staffNrics[staff] ?? 'unknown';
    if (nric == 'unknown') {
      print('Cannot check/reset points: NRIC not found for $staff');
      return;
    }

    String todayDocId = DateFormat('yyyyMMdd').format(today);
    final ref = FirebaseFirestore.instance
        .collection('points')
        .doc('staff')
        .collection(todayDocId)
        .doc(nric);
    final snapshot = await ref.get();
    if (snapshot.exists) {
      var data = snapshot.data()!;
      if (data['dailyPoints'] != null && data['dailyPoints'] > 0) {
        print('Points document exists for $staff with dailyPoints=${data['dailyPoints']}. Skipping reset.');
        return;
      } 
    } else {  
      print('Points document does not exist for $staff on $todayDocId. Initializing...');
      await _initializePointsForStaff(staff);
    }

    // Initialize reset dates if null
    if (staffLastDailyResetDate[staff] == null) {
      print('Initializing daily reset date for $staff');
      staffLastDailyResetDate[staff] = today.subtract(Duration(days: 1));
    }
    if (staffLastMonthlyResetDate[staff] == null) {
      print('Initializing monthly reset date for $staff');
      staffLastMonthlyResetDate[staff] = thisMonth;
    }

    // Monthly reset
    final lastMonthlyReset = DateTime(
        staffLastMonthlyResetDate[staff]!.year,
        staffLastMonthlyResetDate[staff]!.month,
        1);
    if (!thisMonth.isAtSameMomentAs(lastMonthlyReset)) {
      print('Resetting monthly points and deficit for $staff');
      staffMonthlyPoints[staff] = 0;
      staffDailyPoints[staff] = 0;
      staffDailyDeficit[staff] = _trencheTargetPoints[staffSelectedTrenche[staff] ?? "50"] ?? 53.0;
      staffLastMonthlyResetDate[staff] = thisMonth;
      staffLastDailyResetDate[staff] = today;
      staffSelectedTrenche[staff] = "50";
      _staffClockedIn[staff] = false;
      _staffShiftStartTime[staff] = null;
      await _updatePointsInFirestore(staff, nric, todayDocId);
      await _saveClockData(staff);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('lastDailyPoints_$staff', 0.0);
      await prefs.setDouble('lastDeficit_$staff', staffDailyDeficit[staff] ?? 0.0);
      await prefs.setString('lastResetDate_$staff', today.toIso8601String());
      print('Monthly reset completed for $staff: dailyPoints=0, monthlyPoints=0, deficit=${staffDailyDeficit[staff]}');
      notifyListeners();
      return;
    }

    // Daily reset
    final lastDailyReset = DateTime(
        staffLastDailyResetDate[staff]!.year,
        staffLastDailyResetDate[staff]!.month,
        staffLastDailyResetDate[staff]!.day);
    if (!today.isAtSameMomentAs(lastDailyReset)) {
      print('Performing daily reset for $staff');
      
      DateTime yesterday = today.subtract(Duration(days: 1));
      String yesterdayDocId = DateFormat('yyyyMMdd').format(yesterday);
      final yesterdayRef = FirebaseFirestore.instance
          .collection('points')
          .doc('staff')
          .collection(yesterdayDocId)
          .doc(nric);

      double previousDeficit = 0.0;
      double previousMonthlyPoints = staffMonthlyPoints[staff] ?? 0.0;
      try {
        final yesterdaySnapshot = await yesterdayRef.get();
        if (yesterdaySnapshot.exists) {
          var data = yesterdaySnapshot.data()!;
          previousDeficit = data['dailyDeficit']?.toDouble() ?? 0.0;
          previousMonthlyPoints = data['monthlyPoints']?.toDouble() ?? 0.0;
          print('Fetched yesterday\'s deficit for $staff: $previousDeficit, monthlyPoints=$previousMonthlyPoints');
        } else {
          print('No data found for $staff on $yesterdayDocId. Assuming zero deficit.');
        }
      } catch (e) {
        print('Error fetching yesterday\'s data for $staff: $e');
      }

      double baseTarget = _trencheTargetPoints[staffSelectedTrenche[staff] ?? "50"] ?? 53.0;
      staffDailyDeficit[staff] = previousDeficit + baseTarget;
      staffDailyPoints[staff] = 0;
      staffMonthlyPoints[staff] = previousMonthlyPoints; // Preserve monthly points
      staffLastDailyResetDate[staff] = today;
      _staffClockedIn[staff] = false;
      _staffShiftStartTime[staff] = null;
      await _updatePointsInFirestore(staff, nric, todayDocId);
      await _saveClockData(staff);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('lastDailyPoints_$staff', 0);
      await prefs.setDouble('lastDeficit_$staff', staffDailyDeficit[staff] ?? 0);
      await prefs.setString('lastResetDate_$staff', today.toIso8601String());
      print('Daily reset completed for $staff: dailyPoints=0, monthlyPoints=$previousMonthlyPoints, deficit=${staffDailyDeficit[staff]}');
      notifyListeners();
    } else {
      print('No reset needed for $staff: lastDailyReset=$lastDailyReset, today=$today');
    }
  }

  Future<void> _updatePointsInFirestore(String staff, String nric, String docId) async {
    final ref = FirebaseFirestore.instance
        .collection('points')
        .doc('staff')
        .collection(docId)
        .doc(nric);

    DateTime yesterday = DateTime.now().subtract(Duration(days: 1));
    String yesterdayDocId = DateFormat('yyyyMMdd').format(yesterday);
    final yesterdayRef = FirebaseFirestore.instance
        .collection('points')
        .doc('staff')
        .collection(yesterdayDocId)
        .doc(nric);

    double previousMonthlyPoints = staffMonthlyPoints[staff] ?? 0.0;
    try {
      final yesterdaySnapshot = await yesterdayRef.get();
      if (yesterdaySnapshot.exists) {
        previousMonthlyPoints = yesterdaySnapshot.data()!['monthlyPoints']?.toDouble() ?? 0.0;
        print('Fetched previous monthly points for $staff: $previousMonthlyPoints');
      }
    } catch (e) {
      print('Error fetching yesterday\'s points for $staff: $e');
    }

    const int maxRetries = 3;
    int attempt = 0;
    bool success = false;
    while (attempt < maxRetries && !success) {
      try {
        await ref.set({
          'branch': _branchId,
          'fullname': staff,
          'nric': nric,
          'dailyPoints': staffDailyPoints[staff] ?? 0.0,
          'monthlyPoints': previousMonthlyPoints + (staffDailyPoints[staff] ?? 0.0),
          'dailyDeficit': staffDailyDeficit[staff] ?? 0.0,
          'selectedTrenche': staffSelectedTrenche[staff] ?? "50",
          'lastDailyResetDate': Timestamp.fromDate(staffLastDailyResetDate[staff] ?? DateTime.now()),
          'lastMonthlyResetDate': Timestamp.fromDate(staffLastMonthlyResetDate[staff] ?? DateTime.now()),
        }, SetOptions(merge: true));
        print('Updated points for $staff at points/staff/$docId/$nric');
        staffMonthlyPoints[staff] = previousMonthlyPoints + (staffDailyPoints[staff] ?? 0.0);
        success = true;
        notifyListeners();
      } catch (e) {
        attempt++;
        print('Failed to update points for $staff (attempt $attempt/$maxRetries): $e');
        if (e.toString().contains('PERMISSION_DENIED')) {
          print('Permission denied. Check security rules and ensure authenticated user has write access.');
          break;
        }
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 2));
        } else {
          print('Max retries reached. Could not update points for $staff.');
        }
      }
    }
  }

  Future<void> incrementBadge(String staffName, double milestone) async {
    String nric = _staffNrics[staffName] ?? 'unknown';
    if (nric == 'unknown') return;

    String todayDocId = DateFormat('yyyyMMdd').format(DateTime.now());
    final ref = FirebaseFirestore.instance
        .collection('points')
        .doc('staff')
        .collection(todayDocId)
        .doc(nric);

    // Check if the document exists; if not, initialize it
    final docSnapshot = await ref.get();
    if (!docSnapshot.exists) {
      print('Points document for $staffName on $todayDocId does not exist. Initializing...');
      await _initializePointsForStaff(staffName);
    }

    String badgeField = 'badge${milestone.toStringAsFixed(0)}';
    try {
      await ref.update({badgeField: FieldValue.increment(1.0)});
      print('Incremented badge$milestone for $staffName');
      // Update local state
      staffBadges[staffName] ??= {
        'badge45': 0.0,
        'badge55': 0.0,
        'badge65': 0.0,
        'badge75': 0.0,
        'badge85': 0.0,
      };
      staffBadges[staffName]![badgeField] = (staffBadges[staffName]![badgeField] ?? 0.0) + 1.0;
      notifyListeners();
    } catch (e) {
      print('Error incrementing badge$milestone for $staffName: $e');
    }
  }

  Future<void> addTask(Map<String, dynamic> task) async {
    notifyListeners();
  }

  Future<void> assignTask(Map<String, dynamic> task, String assignee) async {
    if (task["taskID"] == null || task["taskID"].trim().isEmpty || assignee.trim().isEmpty) {
      print('Invalid taskID or assignee: ${task["taskID"]}, $assignee');
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance.collection('tasks').doc(task["docId"]);
      await docRef.update({
        'status': 'assigned',
        'assigned': assignee,
        'assistant1': task['assistant1'] ?? 'none',
        'assistant2': task['assistant2'] ?? 'none',
      });
      print('Task ${task["taskID"]} (docId: ${task["docId"]}) assigned to $assignee for branch $_branchId');
      notifyListeners();
    } catch (e) {
      print('Error assigning task ${task["taskID"]}: $e');
      rethrow;
    }
  }

  Future<void> assignAssistant(String taskID, String? assistant1, String? assistant2) async {
    try {
      final task = _assignedTasks.firstWhere((t) => t["taskID"] == taskID, orElse: () => {});
      if (task.isEmpty) {
        print('Task $taskID not found in assigned tasks');
        return;
      }
      final docRef = FirebaseFirestore.instance.collection('tasks').doc(task["docId"]);
      final doc = await docRef.get();
      if (doc.exists) {
        String? assignee = doc.data()?['assigned'] as String?;
        if (assistant1 != null && (assistant1 == assignee || assistant1 == assistant2)) assistant1 = null;
        if (assistant2 != null && (assistant2 == assignee || assistant2 == assistant1)) assistant2 = null;

        await docRef.update({
          'assistant1': assistant1 ?? 'none',
          'assistant2': assistant2 ?? 'none',
        });
        print('Assistants assigned to task $taskID (docId: ${task["docId"]}): $assistant1, $assistant2');
        notifyListeners();
      }
    } catch (e) {
      print('Error assigning assistants: $e');
    }
  }

  Future<void> displayTask(String taskID) async {
    try {
      final task = _availableTasks.firstWhere((t) => t["taskID"] == taskID, orElse: () => {});
      if (task.isEmpty) {
        print('Task $taskID not found in available tasks');
        return;
      }
      final docRef = FirebaseFirestore.instance.collection('tasks').doc(task["docId"]);
      final doc = await docRef.get();
      if (doc.exists) {
        bool currentDisplayed = doc.data()?['displayed'] ?? false;
        await docRef.update({'displayed': !currentDisplayed});
        print('Task $taskID (docId: ${task["docId"]}) display status toggled to ${!currentDisplayed}');
        notifyListeners();
      }
    } catch (e) {
      print('Error updating task display status: $e');
    }
  }

  Future<void> completeTask(String taskID) async {
    try {
      final task = _assignedTasks.firstWhere((t) => t["taskID"] == taskID, orElse: () => {});
      if (task.isEmpty) {
        print('Task $taskID not found in assigned tasks');
        return;
      }
      final docRef = FirebaseFirestore.instance.collection('tasks').doc(task["docId"]);
      final doc = await docRef.get();
      if (doc.exists) {
        var data = doc.data()!;
        print('Completing task ${task["taskID"]}');
        await docRef.update({
          'status': 'completed',
          'completionDate': FieldValue.serverTimestamp(),
        });
        print('Task ${task["taskID"]} marked as completed with server timestamp');

        String? assignee = data['assigned'] as String?;
        String? assistant1 = data['assistant1'] as String?;
        String? assistant2 = data['assistant2'] as String?;
        double points = parsePoints(data['points']);
        String todayDocId = DateFormat('yyyyMMdd').format(DateTime.now());

        Future<void> ensurePointsDoc(String staff) async {
          String normalizedStaff = capitalizeEachWord(staff);
          if (staff != 'none' && _staffNrics.containsKey(normalizedStaff)) {
            String nric = _staffNrics[normalizedStaff]!;
            final ref = FirebaseFirestore.instance
                .collection('points')
                .doc('staff')
                .collection(todayDocId)
                .doc(nric);
            final docSnapshot = await ref.get();
            if (!docSnapshot.exists) {
              print('Creating points document for $normalizedStaff (NRIC: $nric)...');
              try {
                await _initializePointsForStaff(normalizedStaff);
                print('Points document created for $normalizedStaff');
              } catch (e) {
                print('Failed to create points document for $normalizedStaff: $e');
                throw e;
              }
            } else {
              print('Points document already exists for $normalizedStaff on $todayDocId');
            }
          } else {
            print('Staff $normalizedStaff not found in _staffNrics or is "none"');
          }
        }

        Future<void> updatePointsInFirestore(String staff, double points) async {
          String normalizedStaff = capitalizeEachWord(staff);
          if (staff != 'none' && _staffNrics.containsKey(normalizedStaff)) {
            String nric = _staffNrics[normalizedStaff]!;
            final ref = FirebaseFirestore.instance
                .collection('points')
                .doc('staff')
                .collection(todayDocId)
                .doc(nric);
            print('Incrementing points for $normalizedStaff (NRIC: $nric) by $points on $todayDocId');
            try {
              await ref.update({
                'dailyPoints': FieldValue.increment(points),
                'monthlyPoints': FieldValue.increment(points),
              });
              print('Points updated for $normalizedStaff in Firestore on $todayDocId');
            } catch (e) {
              print('Failed to update points in Firestore for $normalizedStaff: $e');
              throw e;
            }
          }
        }

        if (assignee != null) await ensurePointsDoc(assignee);
        if (assistant1 != null) await ensurePointsDoc(assistant1);
        if (assistant2 != null) await ensurePointsDoc(assistant2);

        if (assignee != null) await updatePointsInFirestore(assignee, points);
        if (assistant1 != null && assistant1 != 'none') await updatePointsInFirestore(assistant1, points);
        if (assistant2 != null && assistant2 != 'none') await updatePointsInFirestore(assistant2, points);
        
        notifyListeners();
      }
    } catch (e) {
      print('Error completing task: $e');
    }
  }

  Future<void> debugPointsState(String staffName) async {
    print('Debugging points state for $staffName');
    String nric = _staffNrics[staffName] ?? 'unknown';
    print('NRIC: $nric');
    print('Local state:');
    print('  dailyPoints: ${staffDailyPoints[staffName]}');
    print('  monthlyPoints: ${staffMonthlyPoints[staffName]}');
    print('  dailyDeficit: ${staffDailyDeficit[staffName]}');
    print('  lastDailyResetDate: ${staffLastDailyResetDate[staffName]}');
    print('  lastMonthlyResetDate: ${staffLastMonthlyResetDate[staffName]}');

    String todayDocId = DateFormat('yyyyMMdd').format(DateTime.now());
    final ref = FirebaseFirestore.instance
        .collection('points')
        .doc('staff')
        .collection(todayDocId)
        .doc(nric);
    final snapshot = await ref.get();
    print('Firestore state:');
    if (snapshot.exists) {
      print('  Document exists: points/staff/$todayDocId/$nric');
      print('  Data: ${snapshot.data()}');
    } else {
      print('  Document does not exist: points/staff/$todayDocId/$nric');
    }
  }

  Future<void> handleDeletedCompletedTask(String taskID, String assignee, String? assistant1, String? assistant2, int points, DateTime taskDate) async {
    final dateDocId = DateFormat('yyyyMMdd').format(taskDate);

    Future<void> deductPoints(String staffName) async {
      String normalized = capitalizeEachWord(staffName);
      if (normalized == 'none' || !_staffNrics.containsKey(normalized)) return;

      final nric = _staffNrics[normalized]!;
      staffDailyPoints[normalized] = (staffDailyPoints[normalized] ?? 0.0) - points;
      staffMonthlyPoints[normalized] = (staffMonthlyPoints[normalized] ?? 0.0) - points;
      if (staffDailyPoints[normalized]! < 0) staffDailyPoints[normalized] = 0.0;
      if (staffMonthlyPoints[normalized]! < 0) staffMonthlyPoints[normalized] = 0.0;

      try {
        await FirebaseFirestore.instance
            .collection('points')
            .doc('staff')
            .collection(dateDocId)
            .doc(nric)
            .update({
          'dailyPoints': FieldValue.increment(-points),
          'monthlyPoints': FieldValue.increment(-points),
        });
        print('Points deducted for $normalized due to task deletion.');
      } catch (e) {
        print('Error deducting points for $normalized: $e');
      }

      await _updateDeficitAfterTask(normalized, nric, dateDocId);
      notifyListeners();
    }

    await deductPoints(assignee);
    if (assistant1 != null && assistant1 != 'none') await deductPoints(assistant1);
    if (assistant2 != null && assistant2 != 'none') await deductPoints(assistant2);

    _completedTasks.removeWhere((task) => task['taskID'] == taskID);
    notifyListeners();
  }

  Future<void> _updateDeficitAfterTask(String staff, String nric, String todayDocId) async {
    final ref = FirebaseFirestore.instance
        .collection('points')
        .doc('staff')
        .collection(todayDocId)
        .doc(nric);
    double currentDeficit = 0.0;
    try {
      final snapshot = await ref.get();
      if (snapshot.exists) {
        currentDeficit = snapshot.data()!['dailyDeficit']?.toDouble() ?? 0.0;
      }
    } catch (e) {
      print('Error fetching current deficit for $staff: $e');
    }

    double taskPoints = staffDailyPoints[staff] ?? 0.0;
    double updatedDeficit = currentDeficit - taskPoints;
    if (updatedDeficit < 0) updatedDeficit = 0.0;
    staffDailyDeficit[staff] = updatedDeficit;

    print('Mid-day deficit update for $staff: taskPoints=$taskPoints, currentDeficit=$currentDeficit, updatedDeficit=$updatedDeficit');

    try {
      await ref.update({
        'dailyDeficit': updatedDeficit,
      });
      print('Deficit updated for $staff to $updatedDeficit on $todayDocId');
    }   catch (e) {
      print('Error updating deficit for $staff: $e');
    }
  }

  Future<void> checkPoints(String staffName) async {
    String nric = _staffNrics[staffName] ?? 'unknown';
    if (nric == 'unknown') {
      print('NRIC not found for $staffName');
      return;
    }
    String todayDocId = DateFormat('yyyyMMdd').format(DateTime.now());
    final ref = FirebaseFirestore.instance
        .collection('points')
        .doc('staff')
        .collection(todayDocId)
        .doc(nric);

    try {
      final snapshot = await ref.get();
      if (snapshot.exists) {
        var data = snapshot.data()!;
        print('Firestore points for $staffName at points/staff/$todayDocId/$nric:');
        print('dailyPoints: ${data['dailyPoints']}');
        print('monthlyPoints: ${data['monthlyPoints']}');
        print('dailyDeficit: ${data['dailyDeficit']}');
        print('lastDailyResetDate: ${data['lastDailyResetDate'] != null ? (data['lastDailyResetDate'] as Timestamp).toDate() : null}');
      } else {
        print('No points data found in Firestore for $staffName at points/staff/$todayDocId/$nric');
      }
    } catch (e) {
      print('Error checking points for $staffName: $e');
    }
  }

  Future<void> togglePriority(String taskID) async {
    try {
      final task = _availableTasks.firstWhere((t) => t["taskID"] == taskID, orElse: () => {});
      if (task.isEmpty) {
        print('Task $taskID not found in available tasks');
        return;
      }
      final docRef = FirebaseFirestore.instance.collection('tasks').doc(task["docId"]);
      final doc = await docRef.get();
      if (doc.exists) {
        String currentPriority = doc.data()?['priority'] ?? 'no';
        int currentIndex = priorityLevels.indexOf(currentPriority);
        int nextIndex = (currentIndex + 1) % priorityLevels.length;
        String newPriority = priorityLevels[nextIndex];
        await docRef.update({'priority': newPriority});
        print('Task $taskID (docId: ${task["docId"]}) priority toggled to $newPriority');
      }
    } catch (e) {
      print('Error toggling priority: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getUserClockRecords(String userName, {DateTime? date}) {
    String docId = date != null ? DateFormat('yyyyMMdd').format(date) : DateFormat('yyyyMMdd').format(DateTime.now());
    String nric = _staffNrics[userName] ?? 'unknown';

    if (nric == 'unknown') {
      _getStaffNric(userName).then((fetchedNric) {
        if (fetchedNric != 'unknown') {
          _staffNrics[userName] = fetchedNric;
          notifyListeners();
        }
      });
    }

    return FirebaseFirestore.instance
        .collection('attendance')
        .doc(docId)
        .collection(_branchId)
        .doc(nric)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return [];
          }
          final data = snapshot.data()!;
          int year = int.parse(docId.substring(0, 4));
          int month = int.parse(docId.substring(4, 6));
          int day = int.parse(docId.substring(6, 8));
          DateTime recordDate = DateTime(year, month, day);

          return [
            {
              'nric': nric,
              'name': data['name'] ?? '',
              'clockIn': (data['clockIn'] as Timestamp?)?.toDate(),
              'clockOut': (data['clockOut'] as Timestamp?)?.toDate(),
              'date': recordDate,
            }
          ];
        });
  }

  Future<void> clockIn(String userName) async {
    if (_staffClockedIn[userName] == true) {
      print('User $userName is already clocked in at ${_staffShiftStartTime[userName]}');
      return;
    }

    final now = DateTime.now();
    final docId = DateFormat('yyyyMMdd').format(now);
    String nric = _staffNrics[userName] ?? await _getStaffNric(userName);
    if (nric == 'unknown') {
      throw Exception('NRIC not found for $userName');
    }
    final attendanceRef = FirebaseFirestore.instance
        .collection('attendance')
        .doc(docId)
        .collection(_branchId)
        .doc(nric);

    try {
      await attendanceRef.set({
        'name': userName,
        'clockIn': FieldValue.serverTimestamp(),
        'clockOut': null,
      }, SetOptions(merge: true));

      _staffClockedIn[userName] = true;
      _staffShiftStartTime[userName] = now;
      addClockRecord(userName, 'in');
      await _saveClockData(userName);
      print('Clocked in for $userName at attendance/$docId/$_branchId/$nric');
      notifyListeners();
    } catch (e) {
      print('Error clocking in: $e');
      rethrow;
    }
  }

  static const Duration maxShiftDuration = Duration(hours: 12);

  Future<void> checkAndAutoClockOut(String userName) async {
    if (!_staffClockedIn[userName]!) {
      return;
    }

    final now = DateTime.now();
    final shiftStart = _staffShiftStartTime[userName];
    if (shiftStart == null) {
      _staffClockedIn[userName] = false;
      await _saveClockData(userName);
      notifyListeners();
      return;
    }

    final shiftDuration = now.difference(shiftStart);
    final isSameDay = now.day == shiftStart.day &&
        now.month == shiftStart.month &&
        now.year == shiftStart.year;

    if (shiftDuration > maxShiftDuration || !isSameDay) {
      final autoClockOutTime = !isSameDay
          ? DateTime(shiftStart.year, shiftStart.month, shiftStart.day, 23, 59, 59)
          : now;

      await _performAutoClockOut(userName, autoClockOutTime);
    }
  }

  Future<void> _performAutoClockOut(String userName, DateTime clockOutTime) async {
    final docId = DateFormat('yyyyMMdd').format(clockOutTime);
    String nric = _staffNrics[userName] ?? await _getStaffNric(userName);
    if (nric == 'unknown') {
      print('NRIC not found for $userName during auto clock-out');
      return;
    }

    final attendanceRef = FirebaseFirestore.instance
        .collection('attendance')
        .doc(docId)
        .collection(_branchId)
        .doc(nric);

    try {
      final doc = await attendanceRef.get();
      if (!doc.exists || doc.data()!['clockOut'] != null) {
        print('No active shift or already clocked out for $userName on $docId');
        _staffClockedIn[userName] = false;
        _staffShiftStartTime[userName] = null;
        await _saveClockData(userName);
        notifyListeners();
        return;
      }

      await attendanceRef.update({
        'clockOut': Timestamp.fromDate(clockOutTime),
        'autoClockOut': true,
      });

      _staffClockedIn[userName] = false;
      _staffShiftStartTime[userName] = null;
      addClockRecord(userName, 'out (auto)');
      await _saveClockData(userName);
      print('Auto clocked out $userName at $clockOutTime for attendance/$docId/$_branchId/$nric');
      notifyListeners();
    } catch (e) {
      print('Error during auto clock-out for $userName: $e');
      rethrow;
    }
  }

  Future<void> clockOut(String userName) async {
    if (_staffClockedIn[userName] != true) {
      print('User $userName is not clocked in');
      return;
    }

    final now = DateTime.now();
    final docId = DateFormat('yyyyMMdd').format(now);
    String nric = _staffNrics[userName] ?? await _getStaffNric(userName);
    if (nric == 'unknown') {
      throw Exception('NRIC not found for $userName');
    }
    final attendanceRef = FirebaseFirestore.instance
        .collection('attendance')
        .doc(docId)
        .collection(_branchId)
        .doc(nric);

    try {
      final doc = await attendanceRef.get();
      if (!doc.exists || doc.data()!['clockOut'] != null) {
        print('No active shift found for $userName on $docId at branch $_branchId');
        _staffClockedIn[userName] = false;
        _staffShiftStartTime[userName] = null;
        await _saveClockData(userName);
        notifyListeners();
        return;
      }

      await attendanceRef.update({
        'clockOut': FieldValue.serverTimestamp(),
        'autoClockOut': false,
      });

      _staffClockedIn[userName] = false;
      _staffShiftStartTime[userName] = null;
      addClockRecord(userName, 'out');
      await _saveClockData(userName);
      print('Clocked out for $userName at attendance/$docId/$_branchId/$nric');
      notifyListeners();
    } catch (e) {
      print('Error clocking out: $e');
      rethrow;
    }
  }

  Future<String> _getStaffNric(String userName) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('username', isEqualTo: userName.toLowerCase())
          .where('branch', isEqualTo: _branchId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        String nric = snapshot.docs.first.id;
        _staffNrics[userName] = nric;
        return nric;
      }
      return 'unknown';
    } catch (e) {
      print('Error fetching NRIC for $userName: $e');
      return 'unknown';
    }
  }

  bool isClockedIn(String userName) {
    return _staffClockedIn[userName] ?? false;
  }

  DateTime? getShiftStartTime(String userName) {
    return _staffShiftStartTime[userName];
  }

  void addClockRecord(String userName, String type) {
    _clockRecords.add({
      'userName': userName,
      'type': type,
      'timestamp': DateTime.now(),
      'branchId': _branchId,
    });
    _clockRecords.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    if (_clockRecords.length > 10) {
      _clockRecords = _clockRecords.sublist(0, 10);
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> getUserClockRecordsLocal(String userName) {
    return _clockRecords.where((record) => record['userName'] == userName).toList();
  }

  double getTrencheTargetPoints(String trenche) {
    return _trencheTargetPoints[trenche] ?? 53.0;
  }

  void setSelectedTrenche(String staffName, String trenche) {
    if (_trencheTargetPoints.containsKey(trenche)) {
      staffSelectedTrenche[staffName] = trenche;
      String nric = _staffNrics[staffName] ?? 'unknown';
      if (nric != 'unknown') {
        String todayDocId = DateFormat('yyyyMMdd').format(DateTime.now());
        _updatePointsInFirestore(staffName, nric, todayDocId);
      }
      _checkAndResetPoints(staffName);
      notifyListeners();
    }
  }

  String getSelectedTrenche(String staffName) {
    return staffSelectedTrenche[staffName] ?? "50";
  }

  double getStaffInProgressPoints(String staffName, {DateTime? date}) {
    final filterDate = date ?? DateTime.now();
    return _assignedTasks.where((task) {
      if (task["assignee"] != staffName || task["date"] == null) return false;
      try {
        final taskDate = DateTime.parse(task["date"]);
        return taskDate.year == filterDate.year &&
               taskDate.month == filterDate.month &&
               taskDate.day == filterDate.day;
      } catch (_) {
        return false;
      }  
    }).fold<double>(0.0, (sum, task) => sum + (task["points"]?.toDouble() ?? 0.0));
  }

  double getStaffDailyPoints(String staffName, {DateTime? date}) {
    if (date != null) {
      return _completedTasks.where((task) {
        if (task["assignee"] != staffName || task["date"] == null) return false;
        try {
          final taskDate = DateTime.parse(task["date"]);
          return taskDate.year == date.year &&
                 taskDate.month == date.month &&
                 taskDate.day == date.day;
        } catch (_) {
          return false;
        }
      }).fold(0.0, (sum, task) => sum + (task["points"]?.toDouble() ?? 0.0));
    }
    return staffDailyPoints[staffName] ?? 0.0;
  }

  double getStaffMonthlyPoints(String staffName) {
    return staffMonthlyPoints[staffName] ?? 0.0;
  }

  double getStaffDailyDeficit(String staffName) {
    print('getStaffDailyDeficit for $staffName: ${staffDailyDeficit[staffName] ?? 0.0}');
    return staffDailyDeficit[staffName] ?? 0.0;
  }

  double getBaseTargetPoints(String staffName) {
    String trenche = staffSelectedTrenche[staffName] ?? "50";
    return _trencheTargetPoints[trenche] ?? 53.0;
  }

  double getTargetPoints(String staffName) {
    double baseTarget = getBaseTargetPoints(staffName);
    return baseTarget;
  }

  int getMonthlyTargetGrooming() {
    return 80;
  }

  int getStaffInProgressGrooming(String staffName, {DateTime? date}) {
    return _assignedTasks.where((task) {
      return (task['taskID']?.toString().startsWith('GR_') ?? false) &&
             task['assignee'] == staffName;
    }).length;
  } 

  int getStaffMonthlyGrooming(String staffName, {DateTime? date}) {
    final filterDate = date ?? DateTime.now();
    return _completedTasks.where((task) {
      if (task["assignee"] != staffName || !(task["taskID"]?.toString().startsWith('GR_') ?? false)) return false;
      final completionDateStr = task["completionDate"];
      if (completionDateStr == null || completionDateStr.isEmpty) return false;
      try {
        final parsedDate = DateTime.parse(completionDateStr);
        return parsedDate.year == filterDate.year && parsedDate.month == filterDate.month;
      } catch (_) {
        return false;
      }
    }).length;
  }

  int getBranchInProgressGrooming({DateTime? date}) {
    return _staffNrics.keys
        .map((staff) => getStaffInProgressGrooming(staff, date: date))
        .fold(0, (sum, count) => sum + count);
  }

  int getBranchDailyGrooming({DateTime? date}) {
    final filterDate = date ?? DateTime.now();
    return _completedTasks.where((task) {
      if (task["assignee"] == null || !(task["taskID"]?.toString().startsWith('GR_') ?? false)) return false;
      if (task["date"] == null) return false;
      try {
        final taskDate = DateTime.parse(task["date"]);
        return taskDate.year == filterDate.year &&
               taskDate.month == filterDate.month &&
               taskDate.day == filterDate.day;
      } catch (_) {
        return false;
      }
    }).length;
  }

  int getBranchMonthlyGrooming({DateTime? date}) {
    return _staffNrics.keys
        .map((staff) => getStaffMonthlyGrooming(staff, date: date))
        .fold(0, (sum, count) => sum + count);
  }

  int getBranchMonthlyTargetGrooming() {
    return _staffNrics.length * getMonthlyTargetGrooming();
  }

  List<Map<String, dynamic>> suggestTasks(String staffName, {int maxSuggestions = 3}) {
    double targetPoints = getTargetPoints(staffName);
    double currentPoints = getStaffDailyPoints(staffName);
    double remainingPoints = targetPoints - currentPoints;

    if (remainingPoints <= 0) {
      return [];
    }

    List<Map<String, dynamic>> available = _availableTasks
        .where((task) => task["displayed"] == true)
        .toList();

    available.sort((a, b) {
      int priorityA = priorityLevels.indexOf(a["priority"] ?? "no");
      int priorityB = priorityLevels.indexOf(b["priority"] ?? "no");
      if (priorityA != priorityB) {
        return priorityB.compareTo(priorityA);
      }
      return (int.tryParse(b["points"].toString()) ?? 0)
              .compareTo(int.tryParse(a["points"].toString()) ?? 0);
    });

    List<Map<String, dynamic>> suggestedTasks = [];
    int pointsAccumulated = 0;

    for (var task in available) {
      int taskPoints = int.tryParse(task["points"].toString()) ?? 0;
      if (pointsAccumulated < remainingPoints && suggestedTasks.length < maxSuggestions) {
        suggestedTasks.add(Map<String, dynamic>.from(task));
        pointsAccumulated += taskPoints;
      }
    }

    return suggestedTasks;
  }
}

class InboxProvider extends ChangeNotifier {
  final String staffId;
  final String branchCode;

  InboxProvider({required this.staffId, required this.branchCode}) {
    _listenToInboxItems();
  }

  int _unreadCount = 0;
  List<Map<String, dynamic>> _inboxItems = [];
  bool _isLoading = true;

  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get inboxItems => _inboxItems;

  void _listenToInboxItems() {
    _isLoading = true;
    notifyListeners();

    FirebaseFirestore.instance
      .collection('notices')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .listen((snapshot) {
        final now = DateTime.now();

        final List<Map<String, dynamic>> fetchedItems = snapshot.docs
            .where((doc) {
              final data = doc.data();
              final audience = data['targetAudience'] ?? 'all';
              final targetStaff = data['targetStaff'] ?? '';
              final targetBranch = data['targetBranch'] ?? '';

              if (audience == 'all') return true;
              if (audience == 'branch') return targetBranch == branchCode;
              if (audience == 'staff') return targetStaff == staffId;
              return false;
            })
            .map((doc) {
              final data = doc.data();
              final createdAt = (data["createdAt"] as Timestamp).toDate();
              bool isToday = createdAt.year == now.year &&
                            createdAt.month == now.month &&
                            createdAt.day == now.day;

              return {
                "id": doc.id,
                "title": data["title"] ?? "No Title",
                "subtitle": data["message"] ?? "No Content",
                "timestamp": createdAt,
                "isRead": !isToday, // default to unread for today
              };
            }).toList();

        _inboxItems = fetchedItems;
        _unreadCount = fetchedItems.where((item) => item["isRead"] == false).length;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        print('Error listening to inbox items: \$e');
        _isLoading = false;
        notifyListeners();
      });
  }

  void setUnreadCount(int count) {
    _unreadCount = count;
    notifyListeners();
  }

  void decreaseUnreadCount() {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
    }
  }

  void markAsRead(int index) {
    if (!_inboxItems[index]["isRead"]) {
      _inboxItems[index]["isRead"] = true;
      decreaseUnreadCount();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (int i = 0; i < _inboxItems.length; i++) {
      if (!_inboxItems[i]["isRead"]) {
        markAsRead(i);
      }
    }
  }
}
