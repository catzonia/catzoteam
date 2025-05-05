import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catzoteam/provider.dart';
import 'package:catzoteam/widgets/section_box.dart';
import 'package:catzoteam/widgets/task_card.dart';
import 'package:catzoteam/models/task_category.dart'; 
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

  final List<Map<String, dynamic>> categories = kTaskCategories.map((cat) {
    return {
      "title": cat.title,
      "initials": cat.initials,
      "color": cat.color,
      "tasks": <Map<String, dynamic>>[],
    };
  }).toList();

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
              SectionBox(
                title: "Available Tasks",
                icon: Icons.folder_open_rounded,
                child: _buildTaskRow(),
              )
            ],
          ),
        ),
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
          final matchesDate = taskDateStr == todayStr;
          final matchesBranch = task["taskID"]?.toString().contains(widget.selectedBranchCode) ?? false;
          return matchesDate && matchesBranch;
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
                    children: taskSlice.map((task) => TaskCard(
                                task: task,
                                staffMembers: staffMembers,
                                isLoadingStaff: _isLoadingStaff,
                              )).toList(),
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
}