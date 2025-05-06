import 'package:flutter/material.dart';

class TaskCategory {
  final String title;
  final String initials;
  final Color color;

  const TaskCategory(this.title, this.initials, this.color);
}

List<TaskCategory> kTaskCategories = [
  TaskCategory("Grooming", "GR", Colors.orange[700]!),
  TaskCategory("Sales & Booking", "SB", Colors.orange[500]!),
  TaskCategory("Media & Marketing", "MM", Colors.orange[300]!),
  TaskCategory("Housekeeping & General", "HG", Colors.orange[100]!),
];
