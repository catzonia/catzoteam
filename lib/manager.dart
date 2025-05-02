import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:collection/collection.dart';
import 'package:catzoteam/provider.dart';
import 'dart:math';

class ManagerScreen extends StatefulWidget {
  final String selectedBranchCode;

  const ManagerScreen({required this.selectedBranchCode, Key? key}) : super(key: key);

  @override
  _ManagerScreenState createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  bool _isToAssignExpanded = false;
  bool _isInProgressExpanded = false;
  bool _isCompletedExpanded = false;

  DateTime selectedDate = DateTime.now();
  List<String> _selectedCategoryFilters = [];
  List<String> _selectedStaffFilters = [];
  List<String> staffMembers = [];
  bool _isLoadingStaff = true;
  String _errorMessage = '';

  String formatCatName(dynamic catName) {
    return (catName ?? "").toString().trim().isEmpty ? "-" : catName;
  }

  String _formatAssistant(dynamic value) {
    if (value == null) return "-";
    String text = value.toString().trim().toLowerCase();
    return (text.isEmpty || text == "none") ? "-" : value;
  }

  final List<Map<String, dynamic>> categories = [
    {"title": "Grooming", "value": "grooming", "color": Colors.orange[700], "initials": "GR"},
    {"title": "Sales & Booking", "value": "salesBooking", "color": Colors.orange[500], "initials": "SB"},
    {"title": "Media & Marketing", "value": "mediaMarketing", "color": Colors.orange[300], "initials": "MM"},
    {"title": "Housekeeping & General", "value": "housekeepingGeneral", "color": Colors.orange[100], "initials": "HG"},
  ];

  Map<String, List<Map<String, dynamic>>> groupTasksByCategory(List<Map<String, dynamic>> tasks, List<Map<String, dynamic>> categories) {
    final Map<String, List<Map<String, dynamic>>> grouped = {
      for (var category in categories) category["title"]: [],
      "Unknown": [],
    };

    for (var task in tasks) {
      final category = _getCategoryForTask(task);
      if (!grouped.containsKey(category)) {
        grouped["Unknown"]!.add(task);
      } else {
        grouped[category]!.add(task);
      }
    }

    for (var list in grouped.values) {
      list.sort((a, b) {
        try {
          final timeA = DateFormat("HH:mm:ss").parse(a["time"] ?? "00:00:00");
          final timeB = DateFormat("HH:mm:ss").parse(b["time"] ?? "00:00:00");
          return timeA.compareTo(timeB);
        } catch (_) {
          return 0;
        }
      });
    }

    return grouped;
  }

  @override
  void initState() {
    super.initState();
    _fetchStaffMembers();
    _debugListPointsDocuments();
    _debugListSchedulesDocuments();
  }

  final ThemeData _orangePickerTheme = ThemeData.light().copyWith(
    primaryColor: Colors.orange,
    colorScheme: const ColorScheme.light(
      primary: Colors.orange,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.orange),
    ),
    dialogBackgroundColor: Colors.white,
  );

  Future<void> _debugListPointsDocuments() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('points').get();
      if (snapshot.docs.isNotEmpty) {
        print('Documents in points collection:');
        for (var doc in snapshot.docs) {
          print('Document ID: ${doc.id}');
          print('Data: ${doc.data()}');
          print('---');
        }
      } else {
        print('No documents found in points collection');
      }
    } catch (e) {
      print('Error fetching points documents: $e');
    }
  }

  Future<void> _debugListSchedulesDocuments() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('schedules').limit(5).get();
      if (snapshot.docs.isNotEmpty) {
        print('Documents in schedules collection:');
        for (var doc in snapshot.docs) {
          print('Document ID: ${doc.id}');
          print('Data: ${doc.data()}');
          print('---');
        }
      } else {
        print('No documents found in schedules collection');
      }
    } catch (e) {
      print('Error fetching schedules documents: $e');
    }
  }

  String capitalizeEachWord(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  Future<void> _fetchStaffMembers() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('branch', isEqualTo: widget.selectedBranchCode)
          .get();

      List<String> names = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return capitalizeEachWord(data['username'] as String);
      }).toList();

      setState(() {
        staffMembers = names;
        _isLoadingStaff = false;
        _errorMessage = names.isEmpty ? 'No staff found for this branch' : '';
      });
    } catch (e) {
      setState(() {
        _isLoadingStaff = false;
        _errorMessage = 'Error fetching staff: $e';
      });
    }
  }

  OverlayEntry? _futurePopup;
  Offset _popupOffset = const Offset(50, 100);

  void _showFuturePlanningProgress(TaskProvider taskProvider) {
    final DateTime date = selectedDate;
    final totalStaff = staffMembers.length;
    final totalTargetPoints = totalStaff * 30;
    final totalPlannedPoints = taskProvider.assignedTasks.where((task) {
      if (task["date"] == null) return false;
      try {
        final taskDate = DateTime.parse(task["date"]);
        return taskDate.year == date.year &&
               taskDate.month == date.month &&
               taskDate.day == date.day;
      } catch (_) {
        return false;
      }
    }).fold<int>(0, (sum, task) => sum + (int.tryParse(task["points"].toString()) ?? 0));

    final percentage = totalTargetPoints > 0
        ? (totalPlannedPoints / totalTargetPoints).clamp(0.0, 1.0)
        : 0.0;

    if (_futurePopup?.mounted ?? false) {
      _futurePopup?.remove();
    }

    _futurePopup = OverlayEntry(
      builder: (context) => Positioned(
        left: _popupOffset.dx,
        top: _popupOffset.dy,
        child: Draggable(
          feedback: _buildFloatingPopup(percentage, totalPlannedPoints, totalTargetPoints),
          childWhenDragging: Container(),
          onDragEnd: (details) {
            _popupOffset = details.offset;
            _showFuturePlanningProgress(taskProvider);
          },
          child: _buildFloatingPopup(percentage, totalPlannedPoints, totalTargetPoints),
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_futurePopup!);
  }

  Widget _buildFloatingPopup(double percentage, int planned, int target) {
    return Material(
      elevation: 10,
      color: Colors.transparent,
      child: Stack(
        children: [
          Container(
            width: 165,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20), 
                const Text(
                  "Future Planning",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: percentage,
                        strokeWidth: 10,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                    Text("${(percentage * 100).toStringAsFixed(0)}%"),
                  ],
                ),
                const SizedBox(height: 10),
                Text("$planned / $target pts"),
              ],
            ),
          ),
          // Positioned close icon at top right
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              onPressed: () => _futurePopup?.remove(),
              icon: const Icon(Icons.close_rounded, size: 18),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryForTask(Map<String, dynamic> task) {
    String taskId = task["taskID"] ?? '';
    if (taskId.isEmpty) {
      print('Task has no taskID');
      return "Unknown";
    }

    List<String> parts = taskId.split('_');
    if (parts.length < 2) {
      print('Task $taskId has invalid format');
      return "Unknown";
    }

    String initials = parts[0];
    var category = categories.firstWhere(
      (cat) => cat["initials"] == initials,
      orElse: () => {"title": "Unknown"},
    );
    return category["title"] as String;
  }

  void _showNewTaskDialog(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    String? selectedCategory;
    String? selectedTask;
    String? selectedSubtask;
    int basePoints = 0;
    final TextEditingController catNameController = TextEditingController();
    final ValueNotifier<String?> taskNameNotifier = ValueNotifier<String?>(null);
    DateTime selectedDate = this.selectedDate;
    TimeOfDay selectedTime = TimeOfDay.now();
    String priority = "normal";
    int points = 0;
    String generatedTaskId = '';

    List<Map<String, dynamic>> categoriesList = [];
    Map<String, List<Map<String, dynamic>>> tasks = {};
    Map<String, Map<String, List<Map<String, dynamic>>>> subtasks = {};
    bool isLoadingPoints = true;
    String pointsError = '';

    Future<void> fetchPointsData() async {
      try {
        QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('points').get();
        if (snapshot.docs.isNotEmpty) {
          for (var doc in snapshot.docs) {
            String categoryKey = doc.id;
            var categoryData = doc.data() as Map<String, dynamic>?;

            if (categoryData == null || categoryData['categoryName'] == null) {
              print('Skipping category $categoryKey: categoryData or categoryName is null');
              continue;
            }

            categoriesList.add({
              "title": categoryData['categoryName'] as String,
              "value": categoryKey,
            });

            List<Map<String, dynamic>> categoryTasks = [];
            Map<String, List<Map<String, dynamic>>> categorySubtasks = {};

            if (categoryData['tasks'] != null) {
              for (var task in categoryData['tasks']) {
                if (task['taskName'] == null) {
                  print('Skipping task in category $categoryKey: taskName is null');
                  continue;
                }

                dynamic pointValue = task['point'];
                int point = pointValue is num ? pointValue.toInt() : (int.tryParse(pointValue?.toString() ?? '0') ?? 0);

                categoryTasks.add({
                  "title": task['taskName'] as String,
                  "points": point,
                });

                List<Map<String, dynamic>> subtaskList = [];
                if (task['subTasks'] != null) {
                  for (var subtask in task['subTasks']) {
                    if (subtask['name'] == null) {
                      print('Skipping subtask in task ${task['taskName']}: name is null');
                      continue;
                    }

                    dynamic additionalPtsValue = subtask.containsKey('additionalPts') ? subtask['additionalPts'] : 0;
                    int additionalPts = additionalPtsValue is num ? additionalPtsValue.toInt() : (int.tryParse(additionalPtsValue?.toString() ?? '0') ?? 0);

                    subtaskList.add({
                      "title": subtask['name'] as String,
                      "points": additionalPts,
                    });
                  }
                }
                subtaskList.insert(0, {"title": "None", "points": 0});
                categorySubtasks[task['taskName'] as String] = subtaskList;
              }
            }

            tasks[categoryKey] = categoryTasks;
            subtasks[categoryKey] = categorySubtasks;
          }

          selectedCategory = categoriesList.isNotEmpty ? categoriesList[0]['title'] as String? : null;
        } else {
          pointsError = 'No points categories found.';
        }
      } catch (e) {
        pointsError = 'Error fetching points: $e';
      } finally {
        isLoadingPoints = false;
      }
    }

    void updateTaskNameAndPoints() {
      if (selectedCategory != null && selectedTask != null) {
        final categoryKey = categoriesList.firstWhereOrNull((cat) => cat['title'] == selectedCategory)?['value'] as String?;
        if (categoryKey == null) {
          taskNameNotifier.value = null;
          points = 0;
          return;
        }

        final taskData = tasks[categoryKey]?.firstWhereOrNull((task) => task["title"] == selectedTask);
        if (taskData == null) {
          taskNameNotifier.value = null;
          points = 0;
          return;
        }

        basePoints = taskData["points"] as int;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          taskNameNotifier.value = selectedTask;
        });

        if (selectedSubtask != null && selectedSubtask != "None") {
          final subtaskData = subtasks[categoryKey]?[selectedTask]?.firstWhereOrNull((subtask) => subtask["title"] == selectedSubtask);
          if (subtaskData != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              taskNameNotifier.value = subtaskData["title"] as String;
            });
            points = basePoints + (subtaskData["points"] as int);
          } else {
            points = basePoints;
          }
        } else {
          points = basePoints;
        }
      } else {
        taskNameNotifier.value = null;
        points = 0;
      }
    }

    void updateGeneratedTaskId() {
      if (selectedCategory != null) {
        String categoryInitials;
        switch (selectedCategory) {
          case 'Grooming':
            categoryInitials = 'GR';
            break;
          case 'Housekeeping & General':
            categoryInitials = 'HG';
            break;
          case 'Media & Marketing':
            categoryInitials = 'MM';
            break;
          case 'Sales & Booking':
            categoryInitials = 'SB';
            break;
          default:
            categoryInitials = 'UN';
        }
        final random = Random();
        final randomDigits = (random.nextInt(900000) + 100000).toString();
        generatedTaskId = '${categoryInitials}_${widget.selectedBranchCode}$randomDigits';
      } else {
        generatedTaskId = '';
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder(
          future: fetchPointsData(),
          builder: (context, snapshot) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Add New Task",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    updateTaskNameAndPoints();
                    updateGeneratedTaskId();

                    if (isLoadingPoints) {
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (pointsError.isNotEmpty) {
                      return SizedBox(
                        height: 200,
                        child: Center(child: Text(pointsError, style: const TextStyle(color: Colors.red))),
                      );
                    }

                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Create a new task for staff to complete.",
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Text(
                                "Category",
                                style: TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "*",
                                style: TextStyle(fontSize: 16, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            decoration: InputDecoration(
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
                            items: categoriesList.map((category) {
                              return DropdownMenuItem<String>(
                                value: category["title"] as String,
                                child: Text(category["title"] as String),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCategory = value;
                                selectedTask = null;
                                selectedSubtask = null;
                                updateGeneratedTaskId();
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Text(
                                "Task",
                                style: TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "*",
                                style: TextStyle(fontSize: 16, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedTask,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: "Select task",
                              hintStyle: TextStyle(color: Colors.grey[400]),
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
                            items: selectedCategory != null
                                ? tasks[categoriesList.firstWhereOrNull((cat) => cat['title'] == selectedCategory)?['value'] as String?]
                                    ?.map((task) {
                                    return DropdownMenuItem<String>(
                                      value: task["title"] as String,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(task["title"] as String),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.green),
                                            ),
                                            child: Text(
                                              "${task["points"]} pts",
                                              style: const TextStyle(fontSize: 12, color: Colors.green),
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  }).toList()
                                : [],
                            onChanged: (value) {
                              setState(() {
                                selectedTask = value;
                                selectedSubtask = null;
                                updateTaskNameAndPoints();
                              });
                            },
                          ),
                          if (selectedCategory != null &&
                              selectedTask != null &&
                              (subtasks[categoriesList.firstWhereOrNull((cat) => cat['title'] == selectedCategory)?['value'] as String?]
                                      ?[selectedTask] !=
                                  null)) ...[
                            const SizedBox(height: 16),
                            const Text(
                              "Subtask",
                              style: TextStyle(fontSize: 16, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedSubtask,
                              isExpanded: true,
                              decoration: InputDecoration(
                                hintText: "Select subtask",
                                hintStyle: TextStyle(color: Colors.grey[400]),
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
                              items: subtasks[categoriesList.firstWhereOrNull((cat) => cat['title'] == selectedCategory)?['value'] as String?]
                                      ?[selectedTask]
                                  ?.map((subtask) {
                                    return DropdownMenuItem<String>(
                                      value: subtask["title"] as String,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(subtask["title"] as String),
                                          if ((subtask["points"] ?? 0) > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green[50],
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.green),
                                              ),
                                              child: Text(
                                                "${subtask["points"]} pts",
                                                style: const TextStyle(fontSize: 12, color: Colors.green),
                                              ),
                                            )
                                        ],
                                      ),
                                    );
                                  }).toList() ??
                                  [],
                              onChanged: (value) {
                                setState(() {
                                  selectedSubtask = value;
                                  updateTaskNameAndPoints();
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Text(
                                "Task Name",
                                style: TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "*",
                                style: TextStyle(fontSize: 16, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<String?>(
                            valueListenable: taskNameNotifier,
                            builder: (context, value, _) {
                              return TextField(
                                readOnly: true,
                                controller: TextEditingController(text: value ?? ""),
                                decoration: InputDecoration(
                                  hintText: value ?? "Enter task name",
                                  hintStyle: TextStyle(color: Colors.grey[400]),
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
                              );
                            },
                          ),

                          const SizedBox(height: 16),
                          const Text(
                            "Cat Name",
                            style: TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: catNameController,
                            decoration: InputDecoration(
                              hintText: "Enter cat name",
                              hintStyle: TextStyle(color: Colors.grey[400]),
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
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Text(
                                "Date",
                                style: TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "*",
                                style: TextStyle(fontSize: 16, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                builder: (BuildContext context, Widget? child) {
                                  return Theme(data: _orangePickerTheme, child: child!);
                                }
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  selectedDate = pickedDate;
                                  updateGeneratedTaskId();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('yyyy-MM-dd').format(selectedDate),
                                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Text(
                                "Time",
                                style: TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "*",
                                style: TextStyle(fontSize: 16, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final TimeOfDay? pickedTime = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                                builder: (BuildContext context, Widget? child) {
                                  return Theme(data: _orangePickerTheme, child: child!);
                                },
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  selectedTime = pickedTime;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    selectedTime.format(context),
                                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Text(
                                "Priority",
                                style: TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "*",
                                style: TextStyle(fontSize: 16, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: priority,
                            decoration: InputDecoration(
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
                            items: ["normal", "high"].map((value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value[0].toUpperCase() + value.substring(1)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                priority = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Text(
                                "Points",
                                style: TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "*",
                                style: TextStyle(fontSize: 16, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: "Points will be calculated",
                              hintStyle: TextStyle(color: Colors.grey[400]),
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
                            controller: TextEditingController(text: points.toString()),
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Text(
                                "Generated Task ID",
                                style: TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "*",
                                style: TextStyle(fontSize: 16, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: "Select a category to generate Task ID",
                              hintStyle: TextStyle(color: Colors.grey[400]),
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
                            controller: TextEditingController(text: generatedTaskId),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: taskNameNotifier,
                  builder: (context, value, _) {
                    bool isAddTaskEnabled = value != null;

                    return ElevatedButton(
                      onPressed: isAddTaskEnabled
                          ? () async {
                              // Your existing task creation logic stays the same
                              final categoryKey = categoriesList.firstWhereOrNull((cat) => cat['title'] == selectedCategory)?['value'] as String?;
                              if (categoryKey == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Invalid category selected."),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              final newTask = {
                                "taskId": generatedTaskId,
                                "taskName": value,
                                "catName": catNameController.text.isNotEmpty ? catNameController.text : null,
                                "date": DateFormat('yyyy-MM-dd').format(selectedDate),
                                "time": "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00",
                                "branchId": widget.selectedBranchCode,
                                "priority": priority,
                                "status": "unassigned",
                                "points": points,
                                "assigned": "none",
                                "assistant1": "none",
                                "assistant2": "none",
                                "createdBy": "manager",
                                "pointCategoryId": categoryKey,
                                "pointTaskName": selectedTask,
                                "pointSubTaskName": selectedSubtask != "None" ? selectedSubtask : null,
                                "displayed": false,
                              };

                              try {
                                await FirebaseFirestore.instance.collection('tasks').doc(generatedTaskId).set(newTask);
                                taskProvider.addTask({
                                  "taskID": generatedTaskId,
                                  "task": value,
                                  "orderID": null,
                                  "catName": catNameController.text,
                                  "points": points,
                                  "priority": priority,
                                  "timestamp": DateTime.now().toIso8601String(),
                                  "displayed": false,
                                  "docId": generatedTaskId,
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Task '$value' created successfully with ID: $generatedTaskId"),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.pop(context);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Error creating task: $e"),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAddTaskEnabled ? Colors.orange : Colors.grey[300],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        "Add Task",
                        style: TextStyle(
                          color: isAddTaskEnabled ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTaskDialog(BuildContext context, Map<String, dynamic> task) {
    final TextEditingController catNameController = TextEditingController(text: task["catName"]);
    final TextEditingController taskNameController = TextEditingController(text: task["task"] ?? "");
    DateTime selectedDate = DateTime.tryParse(task["date"] ?? "") ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(DateFormat("HH:mm:ss").parse(task["time"] ?? "09:00:00"));
    String selectedPriority = task["priority"] ?? "normal";
    String selectedAssignee = task["assignee"] ?? "";
    String selectedAssistant1 = task["assistant1"] ?? "none";
    String selectedAssistant2 = task["assistant2"] ?? "none";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)
          ),
          backgroundColor: Colors.white,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Edit Task",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Task ID: ${task["taskID"]}",
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Text(
                            "Task Name",
                            style: TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                          SizedBox(width: 4),
                          Text(
                            "*",
                            style: TextStyle(fontSize: 16, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: taskNameController,
                        decoration:InputDecoration(
                          hintStyle: TextStyle(color: Colors.grey[400]),
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
                      
                      const SizedBox(height: 16),
                      const Text(
                        "Cat Name",
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: catNameController,
                        decoration: InputDecoration(
                          hintStyle: TextStyle(color: Colors.grey[400]),
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
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Text(
                            "Date",
                            style: TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                          SizedBox(width: 4),
                          Text(
                            "*",
                            style: TextStyle(fontSize: 16, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (BuildContext context, Widget? child) {
                              return Theme(data: _orangePickerTheme, child: child!);
                            }
                          );
                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('yyyy-MM-dd').format(selectedDate),
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Text(
                            "Time",
                            style: TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                          SizedBox(width: 4),
                          Text(
                            "*",
                            style: TextStyle(fontSize: 16, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                            builder: (BuildContext context, Widget? child) {
                              return Theme(data: _orangePickerTheme, child: child!);
                            },
                          );
                          if (pickedTime != null) {
                            setState(() {
                              selectedTime = pickedTime;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                selectedTime.format(context),
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Text(
                            "Priority",
                            style: TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                          SizedBox(width: 4),
                          Text(
                            "*",
                            style: TextStyle(fontSize: 16, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedPriority,
                        decoration: InputDecoration(
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
                        items: ["normal", "high"].map((value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value[0].toUpperCase() + value.substring(1)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedPriority = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Text(
                            "Assignee",
                            style: TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                          SizedBox(width: 4),
                          Text(
                            "*",
                            style: TextStyle(fontSize: 16, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: staffMembers.contains(selectedAssignee) ? selectedAssignee : null,
                        decoration: InputDecoration(
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
                        items: staffMembers.map((name) {
                          return DropdownMenuItem(
                            value: name, 
                            child: Text(name)
                          );
                        }).toList(), 
                        onChanged: (value) {
                          setState(() {
                            selectedAssignee = value ?? "none";
                          }); 
                        }, 
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Assitant 1",
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: staffMembers.contains(selectedAssistant1) ? selectedAssistant1 : null,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: staffMembers.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                        onChanged: (value) => setState(() => selectedAssistant1 = value ?? "none"),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Assitant 2",
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: staffMembers.contains(selectedAssistant2) ? selectedAssistant2 : null,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: staffMembers.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                        onChanged: (value) => setState(() => selectedAssistant2 = value ?? "none"),
                      ),
                        ],
                      ),
                    );
                  }
                ),
              ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final taskID = task["taskID"];
                  await FirebaseFirestore.instance.collection("tasks").doc(taskID).update({
                    "catName": catNameController.text,
                    "task": taskNameController.text,
                    "date": DateFormat('yyyy-MM-dd').format(selectedDate),
                    "time": "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00",
                    "priority": selectedPriority,
                    "assigned": selectedAssignee,
                    "assistant1": selectedAssistant1,
                    "assistant2": selectedAssistant2,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Task updated successfully.")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    List<String> tempCategoryFilters = List.from(_selectedCategoryFilters);
    List<String> tempStaffFilters = List.from(_selectedStaffFilters);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: const Text("Filter Tasks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Categories", style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 6,
                    children: categories.map((category) {
                      final title = category["title"];
                      final selected = tempCategoryFilters.contains(title);
                      return FilterChip(
                        label: Text(title),
                        selected: selected,
                        onSelected: (bool value) {
                          setState(() {
                            if (value) {
                              tempCategoryFilters.add(title);
                            } else {
                              tempCategoryFilters.remove(title);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  const Text("Staff", style: TextStyle(fontWeight: FontWeight.bold)),
                  _isLoadingStaff
                      ? const CircularProgressIndicator()
                      : Wrap(
                          spacing: 6,
                          children: staffMembers.map((staff) {
                            final selected = tempStaffFilters.contains(staff);
                            return FilterChip(
                              label: Text(staff),
                              selected: selected,
                              onSelected: (bool value) {
                                setState(() {
                                  if (value) {
                                    tempStaffFilters.add(staff);
                                  } else {
                                    tempStaffFilters.remove(staff);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                ],
              );
            },
          ),
          actions: [
            if (_selectedCategoryFilters.isNotEmpty || _selectedStaffFilters.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategoryFilters.clear();
                    _selectedStaffFilters.clear();
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("All filters cleared."),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                child: const Text("Clear All", style: TextStyle(color: Colors.red, fontSize: 16)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedCategoryFilters = tempCategoryFilters;
                  _selectedStaffFilters = tempStaffFilters;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Filters applied: Category - ${_selectedCategoryFilters.isEmpty ? 'All' : _selectedCategoryFilters.join(', ')}, Staff - ${_selectedStaffFilters.isEmpty ? 'All' : _selectedStaffFilters.join(', ')}"),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Apply", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

    final today = selectedDate;
    bool isSameDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return false;
      try {
        final parsed = DateTime.parse(dateStr);
        return parsed.year == today.year && parsed.month == today.month && parsed.day == today.day;
      } catch (_) {
        return false;
      }
    }

    final filteredUnassigned = taskProvider.availableTasks.where((task) {
      final matchesCategory = _selectedCategoryFilters.isEmpty || _selectedCategoryFilters.contains(_getCategoryForTask(task));
      final matchesDate = isSameDate(task["date"]);
      return matchesCategory && matchesDate;
    }).toList();

    final filteredInProgress = taskProvider.assignedTasks.where((task) {
      final matchesCategory = _selectedCategoryFilters.isEmpty || _selectedCategoryFilters.contains(_getCategoryForTask(task));
      final matchesStaff = _selectedStaffFilters.isEmpty ||
        _selectedStaffFilters.contains(task["assignee"]) ||
        _selectedStaffFilters.contains(task["assistant1"]) ||
        _selectedStaffFilters.contains(task["assistant2"]);
      final matchesDate = isSameDate(task["date"]);
      return matchesCategory && matchesStaff && matchesDate;
    }).toList();

    final filteredCompleted = taskProvider.completedTasks.where((task) {
      final matchesCategory = _selectedCategoryFilters.isEmpty || _selectedCategoryFilters.contains(_getCategoryForTask(task));
      final matchesStaff = _selectedStaffFilters.isEmpty ||
        _selectedStaffFilters.contains(task["assignee"]) ||
        _selectedStaffFilters.contains(task["assistant1"]) ||
        _selectedStaffFilters.contains(task["assistant2"]);
      final matchesDate = isSameDate(task["date"]);
      return matchesCategory && matchesStaff && matchesDate;
    }).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStaffProgressSection(),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Tasks",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 22),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (BuildContext context, Widget? child) {
                            return Theme(data: _orangePickerTheme, child: child!);
                          }
                        );
                        if (picked != null && picked != selectedDate) {
                          setState(() {
                            selectedDate = picked;
                          });

                          final now = DateTime.now();
                          if (picked.isAfter(DateTime(now.year, now.month, now.day))) {
                            final taskProvider = Provider.of<TaskProvider>(context, listen: false);
                            _showFuturePlanningProgress(taskProvider);
                          } else {
                            if (_futurePopup?.mounted ?? false) {
                              _futurePopup?.remove();
                            }
                          }
                        }
                      },
                      child: const Text("Date"),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        _showFilterDialog(context);
                      },
                      child: const Text("Filter"),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        _showNewTaskDialog(context);
                      },
                      child: const Text("New Task"),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            Column(
              children: [
                _buildFolderSection(
                  icon: Icons.assignment_outlined,
                  title: "To Assign",
                  taskCountLabel: "${filteredUnassigned.length} task(s) unassigned",
                  isExpanded: _isToAssignExpanded,
                  onTap: () {
                    setState(() {
                      _isToAssignExpanded = !_isToAssignExpanded;
                      _isInProgressExpanded = false;
                      _isCompletedExpanded = false;
                    });
                  },
                  content: _buildToAssignContent(context),
                ),
                const SizedBox(height: 10),
                _buildFolderSection(
                  icon: Icons.hourglass_empty_rounded,
                  title: "In Progress",
                  taskCountLabel: "${filteredInProgress.length} task(s) pending",
                  isExpanded: _isInProgressExpanded,
                  onTap: () {
                    setState(() {
                      _isInProgressExpanded = !_isInProgressExpanded;
                      _isToAssignExpanded = false;
                      _isCompletedExpanded = false;
                    });
                  },
                  content: _buildInProgressContent(),
                ),
                const SizedBox(height: 10),
                _buildFolderSection(
                  icon: Icons.check_circle_outline_rounded,
                  title: "Completed",
                  taskCountLabel: "${filteredCompleted.length} task(s) complete",
                  isExpanded: _isCompletedExpanded,
                  onTap: () {
                    setState(() {
                      _isCompletedExpanded = !_isCompletedExpanded;
                      _isToAssignExpanded = false;
                      _isInProgressExpanded = false;
                    });
                  },
                  content: _buildCompletedContent(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffProgressSection() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        // Initialize PageController to manage swipe navigation
        final PageController pageController = PageController();
        // Track current page for indicator
        ValueNotifier<int> currentPage = ValueNotifier<int>(0);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2, offset: Offset(0, 2)),
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
                      const Icon(Icons.device_hub_rounded, color: Colors.orange, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        "Branch's Progress",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  // Page indicator (dots)
                  ValueListenableBuilder<int>(
                    valueListenable: currentPage,
                    builder: (context, page, _) {
                      return Row(
                        children: [
                          _buildPageDot(page == 0, "Points", pageController, 0),
                          const SizedBox(width: 8),
                          _buildPageDot(page == 1, "Grooming", pageController, 1),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _isLoadingStaff
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      height: 250,
                      child: PageView(
                        controller: pageController,
                        onPageChanged: (index) {
                          currentPage.value = index;
                        },
                        children: [
                          // Page 1: Points Progress Page
                          _buildPointsProgressGrid(taskProvider),
                          // Page 2: Grooming Progress Page
                          _buildBranchGroomingProgress(taskProvider),
                        ],
                      ),
                    )
            ],
          ),
        );
      },
    );
  }

  Widget _buildPointsProgressGrid(TaskProvider taskProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            "Daily Points",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 4,
          ),
          itemCount: staffMembers.length,
          itemBuilder: (context, index) {
            String staffName = staffMembers[index];
            int currentPoints = taskProvider.getStaffDailyPoints(staffName, date: selectedDate);
            int inProgressPoints = taskProvider.getStaffInProgressPoints(staffName, date: selectedDate);
            int targetPoints = taskProvider.getTargetPoints(staffName);

            print('Staff: $staffName, Daily Points: $currentPoints, Target: $targetPoints');

            double completedPercentage = targetPoints > 0 ? (currentPoints / targetPoints).clamp(0.0, 1.0) : 0.0;
            double inProgressPercentage = targetPoints > 0 ? (inProgressPoints / targetPoints).clamp(0.0, 1.0) : 0.0;
            int pointsLeft = (targetPoints - currentPoints).clamp(0, targetPoints);

            return Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (currentPoints >= targetPoints) ...[
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.elasticOut,
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  "🐱 Cat Hero!",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Text(staffName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ],
                        )
                      ),
                      Text(
                        "$pointsLeft points left",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 16,
                    child: CustomPaint(
                      painter: DualProgressPainter(
                        completedPercentage: completedPercentage,
                        inProgressPercentage: inProgressPercentage,
                      ),
                      child: Container(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$currentPoints pts completed",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green[700]),
                      ),
                      Text(
                        "$inProgressPoints pts in progress",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.yellow[700]),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBranchGroomingProgress(TaskProvider taskProvider) {
    final int monthlyCompleted = taskProvider.getBranchMonthlyGrooming(date: selectedDate);
    final int monthlyInProgress = taskProvider.getBranchInProgressGrooming(date: selectedDate);
    final int monthlyTarget = taskProvider.getBranchMonthlyTargetGrooming();

    final double monthlyCompletedPercentage = monthlyTarget > 0 ? (monthlyCompleted / monthlyTarget).clamp(0.0, 1.0) : 0.0;
    final double monthlyInProgressPercentage = monthlyTarget > 0 ? (monthlyInProgress / monthlyTarget).clamp(0.0, 1.0) : 0.0;
    final int monthlyLeft = (monthlyTarget - monthlyCompleted).clamp(0, monthlyTarget);

    final int dailyCompleted = taskProvider.getBranchDailyGrooming(date: selectedDate);
    final int dailyInProgress = taskProvider.getBranchInProgressGrooming(date: selectedDate);
    int dailyTarget = 10;

    final double dailyCompletedPercentage = dailyTarget > 0 ? (dailyCompleted / dailyTarget).clamp(0.0, 1.0) : 0.0;
    final double dailyInProgressPercentage = dailyTarget > 0 ? (dailyInProgress / dailyTarget).clamp(0.0, 1.0) : 0.0;
    final int dailyLeft = (dailyTarget - dailyCompleted).clamp(0, dailyTarget);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // Monthly Grooming Section
                const Center(
                  child: Text(
                    "Monthly Grooming",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(height: 4),
                // if (monthlyCompleted >= monthlyTarget) ...[
                //   AnimatedContainer(
                //     duration: const Duration(milliseconds: 500),
                //     curve: Curves.elasticOut,
                //     padding: const EdgeInsets.all(10),
                //     child: const Text(
                //       "🏆 Branch Goal Achieved!",
                //       style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                //     ),
                //   ),
                //   const SizedBox(height: 10),
                // ],
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "$monthlyLeft grooming left",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 16,
                  child: CustomPaint(
                    painter: DualProgressPainter(
                      completedPercentage: monthlyCompletedPercentage,
                      inProgressPercentage: monthlyInProgressPercentage,
                    ),
                    child: Container(),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$monthlyCompleted grooming completed",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green[700]),
                    ),
                    Text(
                      "$monthlyInProgress grooming in progress",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.yellow[700]),
                    ),
                  ],
                ),
                const Divider(height: 20, thickness: 1.2),
              ],
            )
          ),

          Expanded(
            flex: 1,
            child: Column(
              children: [
                // Daily Grooming Section
                const Center(
                  child: Text(
                    "Daily Grooming",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "$dailyLeft grooming left",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 16,
                  child: CustomPaint(
                    painter: DualProgressPainter(
                      completedPercentage: dailyCompletedPercentage,
                      inProgressPercentage: dailyInProgressPercentage,
                    ),
                    child: Container(),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$dailyCompleted grooming completed",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green[700]),
                    ),
                    Text(
                      "$dailyInProgress grooming in progress",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.yellow[700]),
                    ),
                  ],
                ),
              ],
            )
          ),
        ],
      ),
    );
  }

  Widget _buildPageDot(bool isActive, String label, PageController pageController, int pageIndex) {
    return GestureDetector(
      onTap: () {
        pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(5), 
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isActive ? 12 : 8,
              height: isActive ? 12 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.orange : Colors.grey,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.black87 : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderSection({
    required IconData icon,
    required String title,
    required String taskCountLabel,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.orange, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 50),
                      Text(
                        taskCountLabel,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1),
              ],
            ),
            child: content,
          ),
        ],
      ],
    );
  }

  Widget _buildToAssignContent(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        List<Map<String, dynamic>> filteredTasks = taskProvider.availableTasks.where((task) {
          bool matchesCategory =  _selectedCategoryFilters.isEmpty || _selectedCategoryFilters.contains(_getCategoryForTask(task));
          bool matchesDate = true;
          if (task["date"] != null && task["date"].isNotEmpty) {
            try {
              final taskDate = DateTime.parse(task["date"]);
              matchesDate = taskDate.year == selectedDate.year &&
                            taskDate.month == selectedDate.month &&
                            taskDate.day == selectedDate.day;
            } catch (_) {}
          }
          return matchesCategory && matchesDate;
        }).toList();

        final grouped = groupTasksByCategory(filteredTasks, categories);

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _getTableHeaders(),
              ),
            ),
            const SizedBox(height: 8),
            ...grouped.entries.expand((entry) {
              return [
                ...entry.value.map((task) => _buildTaskRow(task, taskProvider, context))
              ];
            }).toList(),
          ],
        );
      },
    );
  }

  List<Widget> _getTableHeaders() {
    List<String> headers = ["Task ID", "Task", "Order ID", "Cat Name", "Date", "Time", "Points", "Priority", "Action"];
    return [
      Expanded(flex: 1, child: _tableHeaderText(headers[0])),
      const SizedBox(width: 3),
      Expanded(flex: 2, child: _tableHeaderText(headers[1])),
      const SizedBox(width: 3),
      Expanded(flex: 1, child: _tableHeaderText(headers[2])),
      const SizedBox(width: 3),
      Expanded(flex: 1, child: _tableHeaderText(headers[3])),
      const SizedBox(width: 3),
      Expanded(flex: 1, child: _tableHeaderText(headers[4])),
      const SizedBox(width: 3),
      Expanded(flex: 1, child: _tableHeaderText(headers[5])),
      const SizedBox(width: 3),
      Expanded(flex: 1, child: _tableHeaderText(headers[6])),
      const SizedBox(width: 3),
      Expanded(flex: 1, child: _tableHeaderText(headers[7])),
      const SizedBox(width: 3),
      Expanded(flex: 1, child: _tableHeaderText(headers[8])),
    ];
  }

  Widget _tableHeaderText(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTaskRow(Map<String, dynamic> task, TaskProvider taskProvider, BuildContext context) {
    Color taskColor = _getTaskColor(task);
    String priority = task["priority"] ?? "normal";
    Color priorityColor;
    IconData priorityIcon;
    switch (priority) {
      case "high":
        priorityColor = Colors.red[800]!;
        priorityIcon = Icons.flag_rounded;
        break;
      case "normal":
      default:
        priorityColor = Colors.grey[700]!;
        priorityIcon = Icons.outlined_flag_rounded;
    }

    String date = task["date"] ?? "-";
    String time = "-";
    if (task["time"] != null && task["time"] != "") {
      try {
        final parsedTime = DateFormat("HH:mm:ss").parse(task["time"]);
        time = DateFormat.jm().format(parsedTime);
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Slidable(
        key: ValueKey(task["taskID"]),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.10,
          children: [
            SlidableAction(
              onPressed: (context) {
                _showEditTaskDialog(context, task);
              },
              backgroundColor: Colors.grey[600]!,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit',
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: taskColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 1, child: _tableCell(task["taskID"])),
              const SizedBox(width: 3),
              Expanded(flex: 2, child: _tableCell(task["task"])),
              const SizedBox(width: 3),
              Expanded(flex: 1, child: _tableCell(task["orderID"] ?? "-")),
              const SizedBox(width: 3),
              Expanded(flex: 1, child: _tableCell(formatCatName(task["catName"]))),
              const SizedBox(width: 3),
              Expanded(flex: 1, child: _tableCell(date)),
              const SizedBox(width: 3),
              Expanded(flex: 1, child: _tableCell(time)),
              const SizedBox(width: 3),
              Expanded(flex: 1, child: _tableCell(task["points"].toString())),
              const SizedBox(width: 3),
              Expanded(
                flex: 1,
                child: IconButton(
                  icon: Icon(priorityIcon, color: priorityColor, size: 22),
                  onPressed: () => taskProvider.togglePriority(task["taskID"]),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        task["displayed"] == true ? Icons.visibility_rounded : Icons.visibility_outlined,
                        color: task["displayed"] == true ? Colors.blue[800] : Colors.grey[700],
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () async {
                        await taskProvider.displayTask(task["taskID"]);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              task["displayed"] == true
                                  ? "Task '${task["task"]}' hidden from Team page."
                                  : "Task '${task["task"]}' displayed on Team page.",
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.person_add, color: Colors.green[800], size: 22),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text("Select Staff", style: TextStyle(fontWeight: FontWeight.bold)),
                            content: SizedBox(
                              width: 300,
                              child: _isLoadingStaff
                                  ? const Center(child: CircularProgressIndicator())
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: staffMembers.length,
                                      itemBuilder: (context, index) {
                                        return ListTile(
                                          title: Text(staffMembers[index]),
                                          onTap: () async {
                                            try {
                                              await taskProvider.assignTask(task, staffMembers[index]);
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text("Task '${task["task"]}' assigned to ${staffMembers[index]}."),
                                                  backgroundColor: Colors.orange,
                                                ),
                                              );
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text("Failed to assign task: $e"),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildInProgressContent() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        List<Map<String, dynamic>> filteredTasks = taskProvider.assignedTasks.where((task) {
          bool matchesCategory =  _selectedCategoryFilters.isEmpty || _selectedCategoryFilters.contains(_getCategoryForTask(task));
          bool matchesDate = true;
          if (task["date"] != null && task["date"].isNotEmpty) {
            try {
              final taskDate = DateTime.parse(task["date"]);
              matchesDate = taskDate.year == selectedDate.year &&
                            taskDate.month == selectedDate.month &&
                            taskDate.day == selectedDate.day;
            } catch (_) {}
          }
          bool matchesStaff = _selectedStaffFilters.isEmpty ||
              _selectedStaffFilters.contains(task["assignee"]) ||
              _selectedStaffFilters.contains(task["assistant1"]) ||
              _selectedStaffFilters.contains(task["assistant2"]);
          return matchesCategory && matchesStaff && matchesDate;
        }).toList();

        final grouped = groupTasksByCategory(filteredTasks, categories);

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _tableHeaderText("Task ID")),
                  Expanded(child: _tableHeaderText("Task")),
                  Expanded(child: _tableHeaderText("Order ID")),
                  Expanded(child: _tableHeaderText("Cat Name")),
                  Expanded(child: _tableHeaderText("Date")),
                  Expanded(child: _tableHeaderText("Time")),
                  Expanded(child: _tableHeaderText("Points")),
                  Expanded(child: _tableHeaderText("Assignee")),
                  Expanded(child: _tableHeaderText("Assistant 1")),
                  Expanded(child: _tableHeaderText("Assistant 2")),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...grouped.entries.expand((entry) {
              return [
                ...entry.value.map((task) => _buildInProgressRow(task, taskProvider))
              ];
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildInProgressRow(Map<String, dynamic> task, TaskProvider taskProvider) {
    Color taskColor = _getTaskColor(task);

    String date = task["date"] ?? "-";
    String time = "-";
    if (task["time"] != null && task["time"] != "") {
      try {
        final parsedTime = DateFormat("HH:mm:ss").parse(task["time"]);
        time = DateFormat.jm().format(parsedTime);
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Slidable(
        key: ValueKey(task["taskID"]),
        closeOnScroll: true,
        endActionPane: ActionPane(
          motion: DrawerMotion(),
          extentRatio: 0.20,
          children: [
            SlidableAction(
              onPressed: (context) {
                _showEditTaskDialog(context, task);
              },
              backgroundColor: Colors.grey[600]!,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit',
            ),
            SlidableAction(
              onPressed: (context) {
                // Ensure task["date"] is set to today
                final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                if (task["date"] == null || task["date"].toString().isEmpty) {
                  task["date"] = today;
                }
                print("Completing task ${task["taskID"]}, date=${task["date"]}");

                taskProvider.completeTask(task["taskID"]);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Task '${task["task"]}' completed."),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: Icons.check_rounded,
              label: 'Complete',
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: taskColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _tableCell(task["taskID"])),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(task["task"])),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(task["orderID"] ?? "-")),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(formatCatName(task["catName"]))),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(date)),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(time)),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(task["points"].toString())),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(task["assignee"])),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(_formatAssistant(task["assistant1"]))),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(_formatAssistant(task["assistant2"]))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedContent() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        List<Map<String, dynamic>> filteredTasks = taskProvider.completedTasks.where((task) {
          bool matchesCategory =  _selectedCategoryFilters.isEmpty || _selectedCategoryFilters.contains(_getCategoryForTask(task));
          bool matchesDate = true;
          if (task["date"] != null && task["date"].isNotEmpty) {
            try {
              final taskDate = DateTime.parse(task["date"]);
              matchesDate = taskDate.year == selectedDate.year &&
                            taskDate.month == selectedDate.month &&
                            taskDate.day == selectedDate.day;
            } catch (_) {}
          }
          bool matchesStaff = _selectedStaffFilters.isEmpty ||
              _selectedStaffFilters.contains(task["assignee"]) ||
              _selectedStaffFilters.contains(task["assistant1"]) ||
              _selectedStaffFilters.contains(task["assistant2"]);
          return matchesCategory && matchesStaff && matchesDate;
        }).toList();

        final grouped = groupTasksByCategory(filteredTasks, categories);

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _tableHeaderText("Task ID")),
                  Expanded(child: _tableHeaderText("Task")),
                  Expanded(child: _tableHeaderText("Order ID")),
                  Expanded(child: _tableHeaderText("Cat Name")),
                  Expanded(child: _tableHeaderText("Date")),
                  Expanded(child: _tableHeaderText("Time")),
                  Expanded(child: _tableHeaderText("Points")),
                  Expanded(child: _tableHeaderText("Assignee")),
                  Expanded(child: _tableHeaderText("Assistant 1")),
                  Expanded(child: _tableHeaderText("Assistant 2")),
                ],
              ),
            ),
            const SizedBox(height: 8),
              ...grouped.entries.expand((entry) {
              return [  
                ...entry.value.map((task) => _buildCompletedRow(task))
              ];
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildCompletedRow(Map<String, dynamic> task) {
    Color taskColor = _getTaskColor(task);

    String date = task["date"] ?? "-";
    String time = "-";
    if (task["time"] != null && task["time"] != "") {
      try {
        final parsedTime = DateFormat("HH:mm:ss").parse(task["time"]);
        time = DateFormat.jm().format(parsedTime);
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Slidable(
        key: ValueKey(task["taskID"]),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.18,
          children: [
            SlidableAction(
              onPressed: (context) {
                _showEditTaskDialog(context, task);
              },
              backgroundColor: Colors.grey[600]!,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit',
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: taskColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _tableCell(task["taskID"])),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(task["task"])),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(task["orderID"] ?? "-")),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(formatCatName(task["catName"]))),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(date)),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(time)),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(task["points"].toString())),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(task["assignee"])),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(_formatAssistant(task["assistant1"]))),
              const SizedBox(width: 8),
              Expanded(child: _tableCell(_formatAssistant(task["assistant2"]))),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTaskColor(Map<String, dynamic> task) {
    String taskId = task["taskID"] ?? '';
    if (taskId.isEmpty) {
      print('Task has no taskID, defaulting to grey');
      return Colors.grey[300]!;
    }

    List<String> parts = taskId.split('_');
    if (parts.length < 2) {
      print('Task $taskId has invalid format, defaulting to grey');
      return Colors.grey[300]!;
    }

    String initials = parts[0];
    var category = categories.firstWhere(
      (cat) => cat["initials"] == initials,
      orElse: () => {"color": Colors.grey[300]},
    );
    Color color = category["color"] as Color;
    print('Task $taskId initials: $initials, color: $color');
    return color;
  }
}

class DualProgressPainter extends CustomPainter {
  final double completedPercentage;
  final double inProgressPercentage;

  DualProgressPainter({
    required this.completedPercentage,
    required this.inProgressPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint backgroundPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.fill;

    Paint completedPaint = Paint()
      ..color = Colors.green[700]!
      ..style = PaintingStyle.fill;

    Paint inProgressPaint = Paint()
      ..color = Colors.yellow[700]!
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(10),
      ),
      backgroundPaint,
    );

    double inProgressWidth = size.width * (completedPercentage + inProgressPercentage).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, inProgressWidth, size.height),
        const Radius.circular(10),
      ),
      inProgressPaint,
    );

    double completedWidth = size.width * completedPercentage;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, completedWidth, size.height),
        const Radius.circular(10),
      ),
      completedPaint,
    );
  }

  @override
  bool shouldRepaint(DualProgressPainter oldDelegate) {
    return oldDelegate.completedPercentage != completedPercentage || oldDelegate.inProgressPercentage != inProgressPercentage;
  }
}