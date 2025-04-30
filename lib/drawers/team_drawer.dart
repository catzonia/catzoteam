import 'package:flutter/material.dart';

class TeamDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const TeamDrawer({required this.selectedIndex, required this.onItemSelected, super.key});

  @override
  _TeamDrawerState createState() => _TeamDrawerState();
}

class _TeamDrawerState extends State<TeamDrawer> {
  late int _selectedSubIndex;

  @override
  void initState() {
    super.initState();
    _selectedSubIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(TeamDrawer oldWidget) {
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
                Text('Team Portal', style: TextStyle(color: Colors.grey, fontSize: 18)),
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
              Icons.schedule_outlined,
              color: _selectedSubIndex == 1 ? Colors.orange : Colors.black,
            ),
            title: Text(
              'Schedule',
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
        ],
      ),
    );
  }
}