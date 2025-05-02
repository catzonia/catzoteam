import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catzoteam/provider.dart';
import 'package:intl/intl.dart';
class TeamScreen extends StatefulWidget {
  final String selectedBranchCode;

  const TeamScreen({required this.selectedBranchCode});

  @override
  _TeamScreenState createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<String> staffMembers = [];
  bool _isLoadingStaff = true;

  final List<Map<String, dynamic>> categories = [
    {"title": "Grooming", "color": Colors.orange[700], "initials": "GR", "tasks": <Map<String, dynamic>>[]},
    {"title": "Sales & Booking", "color": Colors.orange[500], "initials": "SB", "tasks": <Map<String, dynamic>>[]},
    {"title": "Media & Marketing", "color": Colors.orange[300], "initials": "MM", "tasks": <Map<String, dynamic>>[]},
    {"title": "Housekeeping & General", "color": Colors.orange[100], "initials": "HG", "tasks": <Map<String, dynamic>>[]},
  ];

  final Map<String, PageController> _pageControllers = {};
  final Map<String, int> _currentPages = {};

  @override
  void initState() {
    super.initState();
    _fetchStaffMembers();
  }

  String capitalizeEachWord(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  Future<void> _fetchStaffMembers() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('staff').where('branch', isEqualTo: widget.selectedBranchCode).get();

      List<String> names = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return capitalizeEachWord(data['username'] as String);
      }).toList();

      setState(() {
        staffMembers = names;
        _isLoadingStaff = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStaff = false;
      });
      print('Error fetching staff: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionBox("Available Tasks", Icons.folder_open_rounded, _buildTaskRow()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionBox(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2, offset: Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTaskRow() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        List<Map<String, dynamic>> updatedCategories = categories.map((category) {
          return {"title": category["title"], "color": category["color"], "initials": category["initials"], "tasks": <Map<String, dynamic>>[]};
        }).toList();

        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

        for (var task in taskProvider.displayedTasks.where((task) {
          final taskDateStr = task["date"]?.toString() ?? '';
          return taskDateStr == todayStr;
        })) {
          String taskId = task["taskID"] ?? '';
          String initials = taskId.isNotEmpty && taskId.contains('_') ? taskId.split('_')[0] : '';

          var formattedTask = {
            "title": task["task"] ?? "Unknown Task",
            "points": task["points"] ?? 0,
            "name": task["catName"]?.isNotEmpty == true ? task["catName"] : "",
            "taskID": taskId,
            "priority": task["priority"] ?? "no",
          };

          int categoryIndex = updatedCategories.indexWhere((cat) => cat["initials"] == initials);
          if (categoryIndex != -1) {
            updatedCategories[categoryIndex]["tasks"].add(formattedTask);
          } else {
            updatedCategories[3]["tasks"].add(formattedTask);
            print('Task $taskId has unknown initials "$initials", assigned to Housekeeping & General');
          }
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: updatedCategories.map((category) {
            return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: _buildCategoryBox(category)));
          }).toList(),
        );
      },
    );
  }

  Widget _buildCategoryBox(Map<String, dynamic> category) {
    String title = category["title"];
  List<Map<String, dynamic>> tasks = category["tasks"];
  int pageCount = (tasks.length / 2).ceil();
  final controller = _pageControllers.putIfAbsent(title, () => PageController());
  final currentPage = _currentPages[title] ?? 0;

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        color: category["color"] as Color, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 2, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(category["title"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          
          if (tasks.isNotEmpty)
            SizedBox(
              height: 280,
              child: PageView.builder(
                controller: controller,
                itemCount: pageCount,
                scrollDirection: Axis.horizontal,
                onPageChanged: (index) {
                  setState(() {
                    _currentPages[title] = index;
                  });
                },
                itemBuilder: (context, index) {
                  final start = index * 2;
                  final end = (start + 2 > tasks.length) ? tasks.length : start + 2;
                  final taskSlice = tasks.sublist(start, end);

                  return Column(
                    children: taskSlice.map((task) => _buildTaskCard(task)).toList(),
                  );
                },
              ),
            )
          else
            const SizedBox(
                height: 280,
                child:  Center(child: Text("No tasks available", style: TextStyle(color: Colors.black54, fontSize: 14))),
            ),
            
          if (pageCount > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pageCount, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentPage == index ? Colors.white : Colors.white60,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    String priority = task["priority"] ?? "no";
    bool isPriority = priority == "high";
    Color priorityColor;
    IconData priorityIcon;
    switch (priority) {
      case "high":
        priorityColor = Colors.red[700]!;
        priorityIcon = Icons.flag_rounded;
        break;
      default:
        priorityColor = Colors.grey[700]!;
        priorityIcon = Icons.outlined_flag_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 2, offset: Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  task["title"] ?? "Unknown Task",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPriority) 
                Icon(priorityIcon, color: priorityColor, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          if ((task["name"] ?? '').toString().trim().isNotEmpty &&
          task["name"].toString().trim() != '-')
          Text(
            task["name"],
            style: const TextStyle(color: Colors.black54, fontSize: 14, fontStyle: FontStyle.italic),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
                    child: Text("${task["points"] ?? 0} pts", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 3),
                  Consumer<TaskProvider>(
                    builder: (context, taskProvider, child) {
                      return IconButton(
                        icon: Icon(Icons.person_add_rounded, color: Colors.green[600], size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
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
                                            title: Text(staffMembers[index], overflow: TextOverflow.ellipsis),
                                            onTap: () {
                                              final taskToAssign = taskProvider.availableTasks.firstWhere(
                                                (t) => t["taskID"] == task["taskID"],
                                                orElse: () => throw Exception("Task not found"),
                                              );
                                              taskProvider.assignTask(taskToAssign, staffMembers[index]);
                                              Navigator.pop(dialogContext);
                                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                                SnackBar(
                                                  content: Text("Task '${task["title"]}' assigned to ${staffMembers[index]}."),
                                                  backgroundColor: Colors.orange,
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(task["taskID"], style: const TextStyle(color: Colors.black54, fontSize: 12), overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}