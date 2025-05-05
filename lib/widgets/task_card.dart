import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:catzoteam/provider.dart';
import 'package:catzoteam/widgets/staff_selector_dialog.dart';

class TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final List<String> staffMembers;
  final bool isLoadingStaff;

  const TaskCard({
    Key? key,
    required this.task,
    required this.staffMembers,
    required this.isLoadingStaff,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 2, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task title and priority
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
              if (isPriority) Icon(priorityIcon, color: priorityColor, size: 20),
            ],
          ),

          const SizedBox(height: 6),

          // Optional cat name
          if ((task["name"] ?? '').toString().trim().isNotEmpty &&
              task["name"].toString().trim() != '-')
            Text(
              task["name"],
              style: const TextStyle(color: Colors.black54, fontSize: 14, fontStyle: FontStyle.italic),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          const SizedBox(height: 8),

          // Points + Assign Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${task["points"] ?? 0} pts",
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Consumer<TaskProvider>(
                builder: (context, taskProvider, child) {
                  return IconButton(
                    icon: Icon(Icons.person_add_rounded, color: Colors.green[600], size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      showStaffSelectorDialog(
                        context: context,
                        staffList: staffMembers,
                        onSelected: (selectedStaff) {
                          final taskToAssign = taskProvider.availableTasks.firstWhere(
                            (t) => t["taskID"] == task["taskID"],
                            orElse: () => throw Exception("Task not found"),
                          );
                          taskProvider.assignTask(taskToAssign, selectedStaff);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Assigned to $selectedStaff"),
                              backgroundColor: Colors.green[600],
                            ),
                          );
                        },
                      );
                    }
                  );
                },
              )
            ],
          ),
        ],
      ),
    );
  }
}
