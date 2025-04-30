import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:catzoteam/provider.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {

  String _formatTimestamp(DateTime timestamp) {
    return "${timestamp.day.toString().padLeft(2, '0')} ${_monthName(timestamp.month)} ${timestamp.year} | "
           "${timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12}:${timestamp.minute.toString().padLeft(2, '0')}${timestamp.hour >= 12 ? 'pm' : 'am'}";
  }


  String _monthName(int month) {
    const List<String> months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[month - 1];
  }
  
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final inboxProvider = Provider.of<InboxProvider>(context);

    if (inboxProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final inboxItems = inboxProvider.inboxItems;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // if (inboxProvider.unreadCount > 0)
              //   Container(
              //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              //     decoration: BoxDecoration(
              //       color: Colors.orange[50],
              //       borderRadius: BorderRadius.circular(12),
              //       boxShadow: const [
              //         BoxShadow(
              //           color: Colors.black12,
              //           blurRadius: 5,
              //           spreadRadius: 2,
              //           offset: Offset(0, 3),
              //         ),
              //       ],
              //     ),
              //     child: Row(
              //       children: [
              //         const Icon(Icons.mark_email_unread, color: Colors.orange),
              //         const SizedBox(width: 10),
              //         Text(
              //           "${inboxProvider.unreadCount} new message${inboxProvider.unreadCount > 1 ? 's' : ''}",
              //           style: const TextStyle(
              //             fontSize: 16,
              //             fontWeight: FontWeight.w600,
              //             color: Colors.orange,
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // const SizedBox(height: 20),
              // if (inboxProvider.unreadCount > 0)
              //   Align(
              //     alignment: Alignment.centerRight,
              //     child: TextButton(
              //       onPressed: () {
              //         setState(() {
              //           for (var item in inboxItems) {
              //             item["isRead"] = true;
              //           }
              //           inboxProvider.setUnreadCount(0);
              //         });
              //       },
              //       child: const Text(
              //         "Mark all as read",
              //         style: TextStyle(
              //           color: Colors.orange,
              //         ),
              //       ),
              //     ),
              //   ),
              Column(
                children: inboxItems.map((item) {
                  int index = inboxItems.indexOf(item);
                  return GestureDetector(
                    onTap: () {
                      // inboxProvider.markAsRead(index);
                      showDialog(
                        context: context, 
                        builder: (context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inboxItems[index]["title"] ?? "",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  inboxItems[index]["timestamp"] != null
                                      ? _formatTimestamp(inboxItems[index]["timestamp"])
                                      : "",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                )
                              ],
                            ),
                            content: Text(
                              inboxItems[index]["subtitle"] ?? "",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context), 
                                child: const Text(
                                  'Close',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        // color: item["isRead"] ? Colors.grey[100] : Colors.orange[50],
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        boxShadow:const  [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item["isRead"] ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                            // color: item["isRead"] ? Colors.grey : Colors.orange,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item["title"],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          // color: item["isRead"] ? Colors.black54 : Colors.black87,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      item["timestamp"] != null
                                        ? _formatTimestamp(item["timestamp"])
                                        : "",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
