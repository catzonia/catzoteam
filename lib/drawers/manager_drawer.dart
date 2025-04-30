import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:catzoteam/provider.dart';

class ManagerDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const ManagerDrawer({required this.selectedIndex, required this.onItemSelected, super.key});

  @override
  _ManagerDrawerState createState() => _ManagerDrawerState();
}

class _ManagerDrawerState extends State<ManagerDrawer> {
  late int _selectedSubIndex;

  @override
  void initState() {
    super.initState();
    _selectedSubIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(ManagerDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      setState(() {
        _selectedSubIndex = widget.selectedIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('CatzoTeam', style: TextStyle(color: Colors.orange, fontSize: 27, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Manager Portal', style: TextStyle(color: Colors.grey, fontSize: 18)),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.task_outlined,
              color: _selectedSubIndex == 0 ? Colors.orange : Colors.black,
            ),
            title: Text(
              'Tasks',
              style: TextStyle(
                color: _selectedSubIndex == 0 ? Colors.orange : Colors.black,
              ),
            ),
            selected: _selectedSubIndex == 0,
            selectedTileColor: Colors.orange[50],
            onTap: () {
              setState(() {
                _selectedSubIndex = 0;
              });
              widget.onItemSelected(0);
              Navigator.pop(context); 
            },
          ),
          ListTile(
            leading: Icon(
              Icons.table_chart_outlined,
              color: _selectedSubIndex == 1 ? Colors.orange : Colors.black,
            ),
            title: Text(
              'Overview',
              style: TextStyle(
                color: _selectedSubIndex == 1 ? Colors.orange : Colors.black,
              ),
            ),
            selected: _selectedSubIndex == 1,
            selectedTileColor: Colors.orange[50],
            onTap: () {
              setState(() {
                _selectedSubIndex = 1;
              });
              widget.onItemSelected(1);
              Navigator.pop(context); 
            },
          ),
          ListTile(
            leading: Icon(
              Icons.edit_calendar_outlined,
              color: _selectedSubIndex == 2 ? Colors.orange : Colors.black,
            ),
            title: Text(
              'Attendance',
              style: TextStyle(
                color: _selectedSubIndex == 2 ? Colors.orange : Colors.black,
              ),
            ),
            selected: _selectedSubIndex == 2,
            selectedTileColor: Colors.orange[50],
            onTap: () {
              setState(() {
                _selectedSubIndex = 2;
              });
              widget.onItemSelected(2);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.inbox_outlined,
              color: _selectedSubIndex == 3 ? Colors.orange : Colors.black,
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Inbox', 
                  style: TextStyle(
                    color: _selectedSubIndex == 2 ? Colors.orange : Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<InboxProvider>(
                  builder: (context, inboxProvider, child) {
                    return inboxProvider.unreadCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${inboxProvider.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),  
                          )
                        : const SizedBox();
                  },
                ),
              ],
            ),
            selected: _selectedSubIndex == 3,
            selectedTileColor: Colors.orange[50],
            onTap: () {
              setState(() {
                _selectedSubIndex = 3;
              });
              widget.onItemSelected(3);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.analytics_outlined,
              color: _selectedSubIndex == 4 ? Colors.orange : Colors.black,
            ),
            title: Text(
              'Trenche',
              style: TextStyle(
                color: _selectedSubIndex == 4 ? Colors.orange : Colors.black,
              ),
            ),
            selected: _selectedSubIndex == 4,
            selectedTileColor: Colors.orange[50],
            onTap: () {
              setState(() {
                _selectedSubIndex = 4;
              });
              widget.onItemSelected(4);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}