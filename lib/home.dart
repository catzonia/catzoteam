import 'package:catzoteam/inbox.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:catzoteam/provider.dart';
import 'package:catzoteam/drawers/shop_drawer.dart';
import 'package:catzoteam/drawers/team_drawer.dart';
import 'package:catzoteam/drawers/staff_drawer.dart';
import 'package:catzoteam/drawers/manager_drawer.dart';
import 'package:catzoteam/shop.dart';
import 'package:catzoteam/team.dart';
import 'package:catzoteam/overview.dart';
import 'package:catzoteam/manager.dart';
import 'package:catzoteam/pin_pad.dart';
import 'package:catzoteam/team_schedule.dart';
import 'package:catzoteam/trenche.dart';
import 'package:catzoteam/attendance.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _selectedDrawerIndex = 0;
  String _selectedBranch = 'Damansara Perdana';
  String _selectedBranchCode = 'DP';
  String? _authenticatedUserName;
  List<Map<String, String>> _branches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedBranch();
  }

  String capitalizeEachWord(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  Future<void> _loadSavedBranch() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedBranchCode = prefs.getString('selectedBranchCode');
    if (savedBranchCode != null) {
      setState(() {
        _selectedBranchCode = savedBranchCode;
      });
    }
    await _fetchBranches();
  }

  Future<void> _saveBranch(String branchCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedBranchCode', branchCode);
  }

  Future<void> _fetchBranches() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('branch').get();

      List<Map<String, String>> branches = snapshot.docs.map((doc) {
        return {
          'name': capitalizeEachWord(doc['name'] as String),
          'code': doc.id,
        };
      }).toList();

      setState(() {
        _branches = branches;
        if (branches.isNotEmpty) {
          if (_branches.any((b) => b['code'] == _selectedBranchCode)) {
            _selectedBranch = _branches.firstWhere((b) => b['code'] == _selectedBranchCode)['name']!;
          } else {
            _selectedBranch = branches[0]['name']!;
            _selectedBranchCode = branches[0]['code']!;
            _saveBranch(_selectedBranchCode);
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching branches: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    if (index == 2 || index == 3) {
      String type = index == 2 ? 'staff' : 'manager';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PinPadScreen(
            type: type,
            selectedBranchCode: _selectedBranchCode,
          ),
        ),
      ).then((result) {
        if (result != null && result is Map && result['success'] == true) {
          setState(() {
            _selectedIndex = index;
            _selectedDrawerIndex = 0;
            _authenticatedUserName = result['userName'];
          });
        }
      });
    } else {
      setState(() {
        _selectedIndex = index;
        _selectedDrawerIndex = 0;
        _authenticatedUserName = null;
      });
    }
  }

  Widget _getTeamPage(int index) {
    switch (index) {
      case 0:
        return TeamScreen(selectedBranchCode: _selectedBranchCode);
      case 1:
        return TeamScheduleScreen(selectedBranchCode: _selectedBranchCode);
      default:
        return TeamScreen(selectedBranchCode: _selectedBranchCode);
    }
  }

  Widget _getStaffPage(int index) {
    String userName = _authenticatedUserName ?? "Lathifah Husna";
    switch (index) {
      case 0:
        return OverviewScreen(
          role: "staff",
          userName: userName,
        );
      case 1:
        return AttendanceScreen(
          userRole: 'staff',
          userName: userName,
        );
      case 2:
        return InboxScreen();
      case 3:
        return TrencheScreen();
      default:
        return OverviewScreen(
          role: "staff",
          userName: userName,
        );
    }
  }

  Widget _getManagerPage(int index) {
    String userName = _authenticatedUserName ?? "Afeena Farhan";
    switch (index) {
      case 0:
        return ManagerScreen(
          selectedBranchCode: _selectedBranchCode,
          userName: userName,
        );
      case 1:
        return OverviewScreen(
          role: "manager",
          userName: userName,
        );
      case 2:
        return AttendanceScreen(
          userRole: 'manager',
          userName: userName,
        );
      case 3:
        return InboxScreen();
      case 4:
        return TrencheScreen();
      default:
        return ManagerScreen(
          selectedBranchCode: _selectedBranchCode,
          userName: userName,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      ShopScreen(selectedBranchCode: _selectedBranchCode),
      _getTeamPage(_selectedDrawerIndex),
      _getStaffPage(_selectedDrawerIndex),
      _getManagerPage(_selectedDrawerIndex),
    ];

    final List<Widget> _drawers = [
      ShopDrawer(selectedIndex: _selectedDrawerIndex, onItemSelected: (index) {
        setState(() {
          _selectedDrawerIndex = index;
        });
      }),
      TeamDrawer(selectedIndex: _selectedDrawerIndex, onItemSelected: (index) {
        setState(() {
          _selectedDrawerIndex = index;
        });
      }),
      StaffDrawer(selectedIndex: _selectedDrawerIndex, onItemSelected: (index) {
        setState(() {
          _selectedDrawerIndex = index;
        });
      }),
      ManagerDrawer(selectedIndex: _selectedDrawerIndex, onItemSelected: (index) {
        setState(() {
          _selectedDrawerIndex = index;
        });
      }),
    ];

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskProvider>(
          create: (context) => TaskProvider(branchId: _selectedBranchCode),
        ),
        ChangeNotifierProvider<InboxProvider>(
          create: (_) => InboxProvider(
            staffId: _authenticatedUserName ?? 'guest',
            branchCode: _selectedBranchCode,
          ),
        ),
      ],
      child: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          if (taskProvider.branchId != _selectedBranchCode) {
            taskProvider.setBranchId(_selectedBranchCode);
          }

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              leading: Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.black),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  );
                },
              ),
              actions: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  child: _isLoading
                      ? CircularProgressIndicator()
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _branches.any((b) => b['name'] == _selectedBranch)
                                ? _selectedBranch
                                : _branches.isNotEmpty
                                    ? _branches[0]['name']
                                    : null,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _selectedIndex == 0 ? Colors.black : Colors.grey,
                            ),
                            dropdownColor: Colors.white,
                            underline: Container(),
                            onChanged: _selectedIndex == 0
                                ? (String? newValue) {
                                    setState(() {
                                      _selectedBranch = newValue!;
                                      _selectedBranchCode = _branches.firstWhere((b) => b['name'] == newValue)['code']!;
                                      _saveBranch(_selectedBranchCode);
                                      taskProvider.setBranchId(_selectedBranchCode);
                                    });
                                  }
                                : null,
                            items: _branches.map<DropdownMenuItem<String>>((Map<String, String> branch) {
                              return DropdownMenuItem<String>(
                                value: branch['name'],
                                child: Text(branch['name']!),
                              );
                            }).toList(),
                            disabledHint: Text(
                              _selectedBranch,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
              ],
            ),
            drawer: _drawers[_selectedIndex],
            body: _pages[_selectedIndex],
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.store_rounded), label: 'Shop'),
                BottomNavigationBarItem(icon: Icon(Icons.group_rounded), label: 'Team'),
                BottomNavigationBarItem(icon: Icon(Icons.badge_rounded), label: 'Staff'),
                BottomNavigationBarItem(icon: Icon(Icons.manage_accounts_rounded), label: 'Manager'),
              ],
              backgroundColor: Colors.white,
              currentIndex: _selectedIndex,
              selectedItemColor: Colors.orange,
              unselectedItemColor: Colors.grey,
              onTap: _onItemTapped,
            ),
          );
        },
      ),
    );
  }
}