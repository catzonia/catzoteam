import 'package:flutter/material.dart';

Future<void> showStaffSelectorDialog({
  required BuildContext context,
  required List<String> staffList,
  required Function(String) onSelected,
  String title = "Select Staff",
}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 300,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: staffList.length,
          itemBuilder: (_, index) {
            return ListTile(
              title: Text(staffList[index], overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                onSelected(staffList[index]);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ],
    ),
  );
}
