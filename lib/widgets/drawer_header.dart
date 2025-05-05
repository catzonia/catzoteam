import 'package:flutter/material.dart';

class CustomDrawerHeader extends StatelessWidget {
  final String portalTitle;

  const CustomDrawerHeader({required this.portalTitle, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DrawerHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'CatzoTeam',
            style: TextStyle(color: Colors.orange, fontSize: 27, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            portalTitle,
            style: const TextStyle(color: Colors.grey, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
