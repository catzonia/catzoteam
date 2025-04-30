import 'package:flutter/material.dart';

class ShopDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  ShopDrawer({required this.selectedIndex, required this.onItemSelected});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white, // Set background color to white
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            child: Text('CatzoTeam', style: TextStyle(color: Colors.orange, fontSize: 24)),
          ),
          ListTile(
            leading: Icon(
              Icons.shopping_cart_outlined,
              color: selectedIndex == 0 ? Colors.orange : Colors.black,
            ),
            title: Text(
              'Order',
              style: TextStyle(
                color: selectedIndex == 0 ? Colors.orange : Colors.black,
              ),
            ),
            selected: selectedIndex == 0,
            selectedTileColor: Colors.orange[50],
            onTap: () {
              onItemSelected(0);
              Navigator.pop(context);
            },
          ),
          // ListTile(
          //   leading: Icon(
          //     Icons.calendar_today_outlined,
          //     color: selectedIndex == 1 ? Colors.orange : Colors.black,
          //   ),
          //   title: Text(
          //     'Booking',
          //     style: TextStyle(
          //       color: selectedIndex == 1 ? Colors.orange : Colors.black,
          //     ),
          //   ),
          //   selected: selectedIndex == 1,
          //   selectedTileColor: Colors.orange[50],
          //   onTap: () {
          //     onItemSelected(1);
          //     Navigator.pop(context);
          //   },
          // ),
          // ListTile(
          //   leading: Icon(
          //     Icons.paste_outlined,
          //     color: selectedIndex == 2 ? Colors.orange : Colors.black,
          //   ),
          //   title: Text(
          //     'Task',
          //     style: TextStyle(
          //       color: selectedIndex == 2 ? Colors.orange : Colors.black,
          //     ),
          //   ),
          //   selected: selectedIndex == 2,
          //   selectedTileColor: Colors.orange[50],
          //   onTap: () {
          //     onItemSelected(2);
          //     Navigator.pop(context);
          //   },
          // ),
        ],
      ),
    );
  }
}