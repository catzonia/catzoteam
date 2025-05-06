import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catzoteam/provider.dart';
import 'package:catzoteam/models/painter.dart';
import 'package:catzoteam/models/task_category.dart'; 
import 'package:intl/intl.dart';
import 'dart:math';

const MaterialColor Colors_bronze = MaterialColor(0xFFCD7F32, <int, Color>{
  500: Color(0xFFCD7F32),
});

class OverviewScreen extends StatefulWidget {
  final String role;
  final String userName;

  const OverviewScreen({this.role = "staff", this.userName = "Lathifah Husna", super.key});

  @override
  _OverviewScreenState createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> with TickerProviderStateMixin {
  List<String> staffMembers = [];
  bool _isLoadingStaff = true;
  String _errorMessage = '';
  List<int> _congratulatedMilestones = []; 
  
  final Map<int, Map<String, dynamic>> badgeData = {
    45: {"icon": Icons.star_border, "color": Colors_bronze, "label": "Bronze Starter"},
    55: {"icon": Icons.military_tech, "color": Colors.grey, "label": "Silver Achiever"},
    65: {"icon": Icons.workspace_premium, "color": Colors.amber, "label": "Golden Performer"},
    75: {"icon": Icons.diamond, "color": Colors.blue, "label": "Diamond Elite"},
    85: {"icon": Icons.emoji_events, "color": Colors.deepPurple, "label": "Champion Badge"},
  };

  final List<Map<String, dynamic>> categories = kTaskCategories.map((cat) {
    return {
      "title": cat.title,
      "initials": cat.initials,
      "color": cat.color,
      "tasks": <Map<String, dynamic>>[],
    };
  }).toList();

  PageController _incompleteController = PageController();
  int _incompletePage = 0;

  PageController _assignedController = PageController();
  int _assignedPage = 0;

  PageController _completedController = PageController();
  int _completedPage = 0;

  late AnimationController _warningAnimController;
  late Animation<double> _warningScaleAnimation;
  late Animation<double> _warningOpacityAnimation;
  final Set<int> _triggeredWarnings = {};
  final List<int> _warningMilestones = [20, 40];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _fetchStaffMembers();
    
    _warningAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _warningScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 60),
    ]).animate(_warningAnimController);

    _warningOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
    ]).animate(_warningAnimController);
  }

  Future<void> _fetchStaffMembers() async {
    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('staff')
        .where('branch', isEqualTo: taskProvider.branchId)
        .get();
      List<String> names = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        String username = data['username'] as String;
        return "${username[0].toUpperCase()}${username.substring(1).toLowerCase()}"
            .split(' ')
            .map((word) => "${word[0].toUpperCase()}${word.substring(1)}")
            .join(' ');
      }).toList();
      setState(() {
        staffMembers = names;
        _isLoadingStaff = false;
        _errorMessage = names.isEmpty ? 'No staff found' : '';
      });
    } catch (e) {
      setState(() {
        _isLoadingStaff = false;
        _errorMessage = 'Error fetching staff: $e';
      });
    }
  }

  double estimateTaskHeight(Map<String, dynamic> task) {
    double baseHeight = 100; // ID + title
    if ((task['catName'] ?? '').toString().trim().isNotEmpty) {
      baseHeight += 20;
    }
    if (task['isAssisting'] == true) {
      baseHeight += 20;
    }
    return baseHeight;
  }
  
  void _checkAndAddEarnedBadges(int dailyPoints) {
    const milestones = [45, 55, 65, 75, 85];
    
    for (int milestone in milestones) {
      if (dailyPoints >= milestone && !_congratulatedMilestones.contains(milestone)) {
        setState(() {
          _congratulatedMilestones.add(milestone);
        });

        // Only increment badge if NOT already earned today
        final taskProvider = Provider.of<TaskProvider>(context, listen: false);
        Map<String, int> badges = taskProvider.getStaffBadges(widget.userName);
        String badgeField = 'badge$milestone';

        if ((badges[badgeField] ?? 0) == 0) {
          taskProvider.incrementBadge(widget.userName, milestone);
        } else {
          print('Badge $badgeField already earned today, skip increment');
        }
      }
    }
  }

  void _showBadgeDetailDialog(int milestone, String label) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("🎖 $label"),
          content: Text(
            "You have earned the '$label' badge by achieving $milestone daily points!\n\nKeep collecting more badges for rewards!",
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        );
      },
    );
  }

  void _checkWarningMilestones(int dailyPoints) {
    final now = TimeOfDay.now();
    final timeValue = Duration(hours: now.hour, minutes: now.minute);

    if (timeValue >= const Duration(hours: 12, minutes: 30) && dailyPoints < 20 && !_triggeredWarnings.contains(20)) {
      setState(() {
        _triggeredWarnings.add(20);
      });
      _warningAnimController.forward(from: 0.0);
      print("⚠️ Warning: <20 points after 12:30pm");
    }

    if (timeValue >= const Duration(hours: 16, minutes: 0) && dailyPoints < 40 && !_triggeredWarnings.contains(40)) {
      setState(() {
        _triggeredWarnings.add(40);
      });
      _warningAnimController.forward(from: 0.0);
      print("⚠️ Warning: <40 points after 4:00pm");
    }

    // Auto-resolve if milestone met
    for (int m in _warningMilestones) {
      if (dailyPoints >= m && _triggeredWarnings.contains(m)) {
        setState(() {
          _triggeredWarnings.remove(m);
        });
        print("✅ Resolved warning for $m points");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoadingStaff)
                const Center(child: CircularProgressIndicator())
              else if (_errorMessage.isNotEmpty)
                Center(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileCard(),
                          const SizedBox(height: 20),
                          _buildStatsAndSuggestionsCard(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: _buildTaskCard()),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        int monthlyPoints = taskProvider.getStaffMonthlyPoints(widget.userName);
        String selectedTrenche = taskProvider.getSelectedTrenche(widget.userName);
        int dailyDeficit = taskProvider.getStaffDailyDeficit(widget.userName);
        int dailyPoints = taskProvider.getStaffDailyPoints(widget.userName);
        int targetPoints = taskProvider.getTargetPoints(widget.userName);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndAddEarnedBadges(dailyPoints);
          _checkWarningMilestones(dailyPoints);
        });

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepOrange[100]!, Colors.orange[100]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Avatar and Name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundImage: const AssetImage('assets/profile.jpg'),
                            backgroundColor: Colors.grey[200],
                            child: Icon(Icons.pets, size: 40, color: Colors.deepOrange[300]),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.userName,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section 1: Progress Overview
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Daily Points',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '$dailyPoints / $targetPoints',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Warning Icons
                      if (_triggeredWarnings.isNotEmpty)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            double availableWidth = constraints.maxWidth;
                            const double maxPoints = 85; // Same as in _buildDailyProgressBar
                            return SizedBox(
                              height: 36, // Height of the warning icons
                              width: double.infinity,
                              child: Stack(
                                children: _triggeredWarnings.map((milestone) {
                                  // Calculate the position of the milestone relative to the progress bar width
                                  double fraction = milestone / maxPoints;
                                  double leftPosition = fraction * availableWidth - 18; // Center the icon (36/2 = 18)

                                  return Positioned(
                                    left: leftPosition.clamp(0, availableWidth - 36), // Ensure it stays within bounds
                                    child: GestureDetector(
                                      onTap: () => _showWarningPopup(milestone),
                                      child: AnimatedBuilder(
                                        animation: _warningAnimController,
                                        builder: (context, child) {
                                          final jitter = _random.nextDouble() * 0.05;
                                          return Transform.scale(
                                            scale: _warningScaleAnimation.value + jitter,
                                            child: Opacity(
                                              opacity: _warningOpacityAnimation.value,
                                              child: Stack(
                                                children: [
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.withOpacity(0.3),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      gradient: const RadialGradient(
                                                        colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                                                        center: Alignment.center,
                                                        radius: 0.8,
                                                      ),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.red.withOpacity(0.4),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                      _buildDailyProgressBar(dailyPoints, targetPoints),
                      const SizedBox(height: 16),
                      const Text(
                        'Earned Badges:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      _buildBadgeRow(),
                      const SizedBox(height: 20),

                      // Section 2: Stats
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Monthly Points: ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    '$monthlyPoints',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'Trenche: ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    selectedTrenche,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'Points Owed: ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    '$dailyDeficit',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: dailyDeficit > 0 ? Colors.red : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Positioned(
                  //   bottom: 0,
                  //   right: 0,
                  //   child: ElevatedButton(
                  //     onPressed: () {
                  //       _showTrencheSelectionDialog(context, taskProvider);
                  //     },
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.orange,
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(10),
                  //       ),
                  //     ),
                  //     child: const Text(
                  //       'Select Trenche',
                  //       style: TextStyle(
                  //         color: Colors.white,
                  //         fontSize: 14,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDailyProgressBar(int dailyPoints, int targetPoints) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    const List<int> milestones = [45, 55, 65, 75, 85];
    const double maxPoints = 85;

    // Calculate progress based on dailyPoints
    double progress = (dailyPoints / maxPoints).clamp(0.0, 1.0);

    // Trigger milestone dialog for daily points
    for (int milestone in milestones) {
      if (dailyPoints >= milestone && dailyPoints < milestone + 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showMilestoneDialog(context, milestone);
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: progress),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return SizedBox(
              height: 18,
              width: double.infinity,
              child: CustomPaint(
              painter: RoundedLinearProgressPainter(
                value,
                (taskProvider.getStaffInProgressPoints(widget.userName) / 85).clamp(0.0, 1.0),
                ),
              ),
            );
          }
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            double availableWidth = constraints.maxWidth;
            return SizedBox(
              width: double.infinity,
              height: 20,
              child: Stack(
                children: [
                  // Milestone labels
                  ... milestones.asMap().entries.map((entry) {
                    int milestone = entry.value;
                    double fraction = milestone / maxPoints;
                    bool isReached = dailyPoints >= milestone;

                    double leftPosition;
                    if (milestone == 85) {
                      leftPosition = availableWidth - 22.5;
                    } else {
                      leftPosition = fraction * availableWidth - 15;
                    }

                    return Positioned(
                      left: leftPosition,
                      child: SizedBox(
                        width: 30,
                        child: Center(
                          child: Text(
                            milestone.toString(),
                            style: TextStyle(
                              color: isReached ? Colors.deepOrange : Colors.black38,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showMilestoneDialog(BuildContext context, int milestone) {
    if (_congratulatedMilestones.contains(milestone)) return;

    _congratulatedMilestones.add(milestone);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/congratulations.json', repeat: false, height: 120),
              const SizedBox(height: 16),
              Text("You've reached the $milestone points milestone today! Keep it up!",
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Awesome!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showWarningPopup(int milestone) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
            ),
            const SizedBox(width: 12),
            const Text("Deadline Missed", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("You didn't reach $milestone points before the deadline. This warning will stay until you reach $milestone points."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Understood"),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeRow() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        Map<String, int> badges = taskProvider.getStaffBadges(widget.userName);

        // Filter badges that have count > 0
        List<MapEntry<String, int>> earnedBadges = badges.entries
            .where((entry) => entry.value > 0)
            .toList();

        if (earnedBadges.isEmpty) {
          return const Text(
            'No badges earned yet.',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: earnedBadges.map((entry) {
            int milestone = int.parse(entry.key.replaceAll('badge', ''));
            int count = entry.value;
            final badge = badgeData[milestone];

            if (badge == null) return const SizedBox();

            return GestureDetector(
              onTap: () => _showBadgeDetailDialog(milestone, badge["label"]),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(badge["icon"], color: badge["color"], size: 40),
                      if (count > 1)
                        Positioned(
                          top: -4,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              'x$count',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${badge["label"]}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: badge["color"]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStatsAndSuggestionsCard() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        int targetPoints = taskProvider.getTargetPoints(widget.userName);
        int currentPoints = taskProvider.getStaffDailyPoints(widget.userName);
        int remainingPoints = targetPoints - currentPoints;

        List<Map<String, dynamic>> suggestedTasks = taskProvider.suggestTasks(widget.userName);

        bool hasDisplayedTasks = taskProvider.displayedTasks.isNotEmpty;
        bool needsTasks = remainingPoints > 0;

        if (!hasDisplayedTasks || !needsTasks || suggestedTasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.orange),
                  SizedBox(width: 10),
                  Text(
                    'Suggested Tasks',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: suggestedTasks.map((task) => _buildSuggestedTaskCard(task)).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestedTaskCard(Map<String, dynamic> task) {
    Color taskColor = _getTaskColor(task);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: taskColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task["taskID"],
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
                Text(
                  task["task"] ?? "Unknown Task",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if ((task["catName"] ?? '').toString().trim().isNotEmpty && task["catName"].toString().trim() != '-')
                  Text(
                    task["catName"],
                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${task["points"] ?? 0} pts',
                      style: TextStyle(
                        color: Colors.green[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 10,
                            backgroundColor: Colors.white,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.all(20),
                              constraints: const BoxConstraints(maxWidth: 350),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Confirm Task Selection",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Are you sure you want to select this task?",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task["task"],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.star, color: Colors.green[700], size: 20),
                                            const SizedBox(width: 6),
                                            Text(
                                              "${task["points"]} Points",
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.green[800],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if ((task["catName"] ?? '').toString().trim().isNotEmpty &&
                                            task["catName"].toString().trim() != '-')
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              "Category: ${task["catName"]}",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text(
                                          "Cancel",
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          elevation: 2,
                                        ),
                                        onPressed: () {
                                          final taskProvider = Provider.of<TaskProvider>(context, listen: false);
                                          taskProvider.assignTask(task, widget.userName);
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("Task '${task["task"]}' assigned to ${widget.userName}."),
                                              duration: const Duration(seconds: 2),
                                              backgroundColor: Colors.green[600],
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "Select Task",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.add_circle_rounded),
                    color: Colors.deepOrange[800],
                    tooltip: "Select task",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        DateTime today = DateTime.now();
        DateTime yesterday = today.subtract(const Duration(days: 1));

        // Incomplete Yesterday
        List<Map<String, dynamic>> incompleteTasks = taskProvider.assignedTasks.where((task) {
          bool isForUser = task["assignee"] == widget.userName ||
              (task["assistant1"] == widget.userName && task["assistant1"] != "none") ||
              (task["assistant2"] == widget.userName && task["assistant2"] != "none");
          if (!isForUser) return false;
          try {
            final taskDate = DateTime.parse(task["date"]);
            return taskDate.year == yesterday.year && 
                taskDate.month == yesterday.month &&
                taskDate.day == yesterday.day;
          } catch (_) {
            return false;
          }
        }).toList();

        Set<String> incompleteTaskIds = incompleteTasks.map((t) => t["taskID"].toString()).toSet();

        // Assigned Today
        List<Map<String, dynamic>> tasksToShow = taskProvider.assignedTasks.where((task) {
          bool isForUser = task["assignee"] == widget.userName ||
              (task["assistant1"] == widget.userName && task["assistant1"] != "none") ||
              (task["assistant2"] == widget.userName && task["assistant2"] != "none");
          if (!isForUser) return false;
          if (incompleteTaskIds.contains(task["taskID"])) return false;
          try {
            final taskDate = DateTime.parse(task["date"]);
            return taskDate.year == today.year && 
                taskDate.month == today.month && 
                taskDate.day == today.day;
          } catch (_) {
            return false;
          }
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (incompleteTasks.isNotEmpty) ...[
              _buildIncompleteTaskList(incompleteTasks),
              const SizedBox(height: 20),
            ], 
            _buildAssignedTaskList(tasksToShow, taskProvider),
            const SizedBox(height: 20),
            _buildCompletedTaskList(),
          ],
        );
      },
    );
  }

  Widget _buildIncompleteTaskList(List<Map<String, dynamic>> tasks) {
    final pages = List.generate(
      (tasks.length / 3).ceil(),
      (i) {
        final start = i * 3;
        final end = (start + 3 > tasks.length) ? tasks.length : start + 3;
        return tasks.sublist(start, end);
      },
    );

    final pageHeights = pages.map((page) => page.map(estimateTaskHeight).fold(0.0, (a, b) => a + b)).toList();
    final maxHeight = pageHeights.isNotEmpty ? pageHeights.reduce(max) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 10, 20),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text('Incomplete Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: maxHeight,
            child: PageView.builder(
              controller: _incompleteController,
              scrollDirection: Axis.vertical,
              onPageChanged: (index) {
                setState(() {
                  _incompletePage = index;
                });
              },
              itemCount: pages.length,
              itemBuilder: (context, pageIndex) {
                final taskSlice = pages[pageIndex];
                return Row(
                  children: [
                    Expanded(
                      flex: 20,
                      child: Column(
                        children: taskSlice.map((task) {
                          Color taskColor = _getTaskColor(task);
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: taskColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(task['taskID'], style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                                    Text(task['task'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    if ((task['catName'] ?? '').toString().trim().isNotEmpty && task['catName'].toString().trim() != '-')
                                      Text(task['catName'], style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    '${task['points'] ?? 0} pts',
                                    style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),  
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (pages.length > 1)
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            pages.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _incompletePage == index ? Colors.red : Colors.red[100],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAssignedTaskList(List<Map<String, dynamic>> tasksToShow, TaskProvider taskProvider) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final pages = List.generate(
          (tasksToShow.length / 3).ceil(),
          (i) {
            final start = i * 3;
            final end = (start + 3 > tasksToShow.length) ? tasksToShow.length : start + 3;
            return tasksToShow.sublist(start, end);
          },
        );

        final pageHeights = pages.map((page) => page.map(estimateTaskHeight).fold(0.0, (a, b) => a + b)).toList();
        final maxHeight = pageHeights.isNotEmpty ? pageHeights.reduce(max) : 0.0;
        
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 10, 20),
          decoration: _boxDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment_outlined, color: Colors.orange),
                  SizedBox(width: 10),
                  Text('Assigned Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              if (tasksToShow.isEmpty)
                const Center(child: Text('No tasks assigned', style: TextStyle(color: Colors.grey)))
              else
                SizedBox(
                  height: maxHeight,
                  child: PageView.builder(
                    controller: _assignedController,
                    scrollDirection: Axis.vertical,
                    onPageChanged: (index) {
                      setState(() {
                        _assignedPage = index;
                      });
                    },
                    itemCount: pages.length,
                    itemBuilder: (context, pageIndex) {
                      final taskSlice = pages[pageIndex];

                      return Row(
                        children: [
                          Expanded(
                            flex: 20,
                            child: Column(
                              children: taskSlice.map((task) {
                                return _slidableTaskCard(
                                  task['taskID'],
                                  task['task'],
                                  task['catName'] ?? '',
                                  int.tryParse(task["points"].toString()) ?? 0,
                                  _getTaskColor(task),
                                  taskProvider,
                                  (task["taskID"] ?? '').startsWith("GR"),
                                  isAssisting: task["assignee"] != widget.userName &&
                                    ((task["assistant1"] == widget.userName && task["assistant1"] != "none") ||
                                     (task["assistant2"] == widget.userName && task["assistant2"] != "none")),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (pages.length > 1)
                            Expanded(
                              flex: 1,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  pages.length,
                                  (index) => Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _assignedPage == index ? Colors.orange : Colors.orange[100],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletedTaskList() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        DateTime today = DateTime.now();
        List<Map<String, dynamic>> tasksToShow = taskProvider.completedTasks.where((task) {
          bool isForUser = task["assignee"] == widget.userName ||
              task["assistant1"] == widget.userName ||
              task["assistant2"] == widget.userName;
          if (!isForUser) return false;
          
          try {
            final taskDate = DateTime.parse(task["date"]);
            return taskDate.year == today.year &&
                   taskDate.month == today.month &&
                   taskDate.day == today.day;
          } catch (_) {
            return false;
          }
        }).map((task) {
          if (task["assignee"] != widget.userName) {
          return {...task, "isAssisting": true};
          }
          return task;  
        }).toList();

        final pages = List.generate(
          (tasksToShow.length / 3).ceil(),
          (i) {
            final start = i * 3;
            final end = (start + 3 > tasksToShow.length) ? tasksToShow.length : start + 3;
            return tasksToShow.sublist(start, end);
          },
        );

        final pageHeights = pages.map((page) => page.map(estimateTaskHeight).fold(0.0, (a, b) => a + b)).toList();
        final maxHeight = pageHeights.isNotEmpty ? pageHeights.reduce(max) : 0.0;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 10, 20),
          decoration: _boxDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_outlined, color: Colors.green),
                  SizedBox(width: 10),
                  Text('Completed Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              if (tasksToShow.isEmpty)
                const Center(child: Text('No tasks completed yet', style: TextStyle(color: Colors.grey)))
              else
                SizedBox(
                  height: maxHeight,
                  child: PageView.builder(
                    controller: _completedController,
                    scrollDirection: Axis.vertical,
                    onPageChanged: (index) {
                      setState(() {
                        _completedPage = index;
                      });
                    },
                    itemCount: pages.length,
                    itemBuilder: (context, pageIndex) {
                      final taskSlice = pages[pageIndex];
                      return Row(
                        children: [
                          Expanded(
                            flex: 20,
                            child: Column(
                              children: taskSlice.map((task) {
                                Color taskColor = _getTaskColor(task);
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: taskColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(task['taskID'], style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                                          Text(task['task'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          if ((task['catName'] ?? '').isNotEmpty)
                                            Text(task['catName'], style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14)),
                                          if (task["isAssisting"] == true)
                                            const Text("(Assisting)", style: TextStyle(fontSize: 12, color: Colors.white)),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(7),
                                        ),
                                        child: Text(
                                          '${task['points'] ?? 0} pts',
                                          style: TextStyle(color: Colors.green[900], fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (pages.length > 1)
                            Expanded(
                              flex: 1,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  pages.length,
                                  (index) => Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _completedPage == index ? Colors.green : Colors.green[100],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                )            
            ],
          ),
        );
      },
    );
  }

  Widget _slidableTaskCard(
    String id,
    String title,
    String catName,
    int points,
    Color color,
    TaskProvider taskProvider,
    bool isGroomingTask, {
    bool isAssisting = false,
  }) {
    String? selectedAssistant1 = taskProvider.assignedTasks
        .firstWhere((task) => task['taskID'] == id, orElse: () => {})['assistant1'];
    String? selectedAssistant2 = taskProvider.assignedTasks
        .firstWhere((task) => task['taskID'] == id, orElse: () => {})['assistant2'];
    String priority = taskProvider.assignedTasks
        .firstWhere((task) => task['taskID'] == id, orElse: () => {})['priority'] ?? 'no';
    bool isPriority = priority == 'high';

    // Convert 'none' to null for dropdown values
    selectedAssistant1 = (selectedAssistant1 == 'none') ? null : selectedAssistant1;
    selectedAssistant2 = (selectedAssistant2 == 'none') ? null : selectedAssistant2;

    Color priorityColor;
    IconData priorityIcon;
    switch (priority) {
      case "high":
        priorityColor = Colors.red[800]!;
        priorityIcon = Icons.flag_rounded;
        break;
      case "no":
      default:
        priorityColor = Colors.grey[700]!;
        priorityIcon = Icons.outlined_flag_rounded;
    }

    return Slidable(
      key: ValueKey(id),
      closeOnScroll: true,
      endActionPane: isAssisting
          ? null
          : ActionPane(
              motion: DrawerMotion(),
              extentRatio: 0.20,
              children: [
                SlidableAction(
                  onPressed: (context) {
                    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                    final task = taskProvider.assignedTasks.firstWhere((t) => t["taskID"] == id, orElse: () => {});
                    if (task.isNotEmpty && (task["date"] == null || task["date"].toString().isEmpty)) {
                      task["date"] = today;
                      print("Date was missing — set task[\"date\"] to today: $today for taskID: ${task["taskID"]}");
                    }
                    taskProvider.completeTask(id);
                  },
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  icon: Icons.check,
                  label: 'Complete',
                ),
              ],
            ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Column: Task Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(id, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (catName.trim().isNotEmpty && catName.trim() != '-')
                    Text(
                      catName,
                      style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (isAssisting)
                      const Text("(Assisting)", style: TextStyle(fontSize: 12, color: Colors.white))
                  ],
                ),
              ),
              // Right Column: Action Elements
              Column(
                mainAxisAlignment: isPriority ? MainAxisAlignment.start : MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isPriority)
                    Column(
                      children: [
                        Icon(
                          priorityIcon,
                          color: priorityColor,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (isGroomingTask && !isAssisting)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Container(
                            height: 30,
                            child: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.person_add,
                                color: Colors.green[800],
                                size: 22,
                              ),
                              onSelected: (value) {},
                              itemBuilder: (BuildContext context) {
                                return [
                                  PopupMenuItem<String>(
                                    enabled: false,
                                    child: StatefulBuilder(
                                      builder: (BuildContext context, StateSetter setState) {
                                        List<String> availableAssistants = staffMembers
                                            .where((staff) => staff != widget.userName)
                                            .toList();
                                        List<String> assistant2Options = selectedAssistant1 != null
                                            ? availableAssistants
                                                .where((staff) => staff != selectedAssistant1)
                                                .toList()
                                            : availableAssistants;

                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                const Text("Assistant 1: ", style: TextStyle(fontSize: 14)),
                                                SizedBox(
                                                  width: 120,
                                                  child: DropdownButton<String>(
                                                    value: selectedAssistant1,
                                                    isExpanded: true,
                                                    hint: const Text("Select", style: TextStyle(fontSize: 14)),
                                                    items: availableAssistants.map((String staff) {
                                                      return DropdownMenuItem<String>(
                                                        value: staff,
                                                        child: Text(
                                                          staff,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontSize: 14),
                                                        ),
                                                      );
                                                    }).toList(),
                                                    onChanged: (String? newValue) {
                                                      setState(() {
                                                        selectedAssistant1 = newValue;
                                                        taskProvider.assignAssistant(id, selectedAssistant1, selectedAssistant2);
                                                        if (newValue != null) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text("Assigned $newValue as Assistant 1 for '$title'."),
                                                              duration: const Duration(seconds: 2),
                                                            ),
                                                          );
                                                        }
                                                      });
                                                      Navigator.pop(context);
                                                    },
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                    size: 20,
                                                  ),
                                                  onPressed: selectedAssistant1 != null
                                                      ? () {
                                                          setState(() {
                                                            String? removedAssistant = selectedAssistant1;
                                                            if (selectedAssistant2 != null) {
                                                              selectedAssistant1 = selectedAssistant2;
                                                              selectedAssistant2 = null;
                                                              taskProvider.assignAssistant(id, selectedAssistant1, null);
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                      "Removed $removedAssistant as Assistant 1 from '$title'."),
                                                                  duration: const Duration(seconds: 2),
                                                                ),
                                                              );
                                                            } else {
                                                              selectedAssistant1 = null;
                                                              taskProvider.assignAssistant(id, null, null);
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                      "Removed $removedAssistant as Assistant 1 from '$title'."),
                                                                  duration: const Duration(seconds: 2),
                                                                ),
                                                              );
                                                            }
                                                          });
                                                          Navigator.pop(context);
                                                        }
                                                      : null,
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                const Text("Assistant 2: ", style: TextStyle(fontSize: 14)),
                                                SizedBox(
                                                  width: 120,
                                                  child: DropdownButton<String>(
                                                    value: selectedAssistant2,
                                                    isExpanded: true,
                                                    hint: const Text("Select", style: TextStyle(fontSize: 14)),
                                                    items: assistant2Options.map((String staff) {
                                                      return DropdownMenuItem<String>(
                                                        value: staff,
                                                        child: Text(
                                                          staff,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontSize: 14),
                                                        ),
                                                      );
                                                    }).toList(),
                                                    onChanged: (String? newValue) {
                                                      setState(() {
                                                        selectedAssistant2 = newValue;
                                                        taskProvider.assignAssistant(id, selectedAssistant1, selectedAssistant2);
                                                        if (newValue != null) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text("Assigned $newValue as Assistant 2 for '$title'."),
                                                              duration: const Duration(seconds: 2),
                                                            ),
                                                          );
                                                        }
                                                      });
                                                      Navigator.pop(context);
                                                    },
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                    size: 20,
                                                  ),
                                                  onPressed: selectedAssistant2 != null
                                                      ? () {
                                                          setState(() {
                                                            String? removedAssistant = selectedAssistant2;
                                                            selectedAssistant2 = null;
                                                            taskProvider.assignAssistant(id, selectedAssistant1, null);
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content:
                                                                    Text("Removed $removedAssistant as Assistant 2 from '$title'."),
                                                                duration: const Duration(seconds: 2),
                                                              ),
                                                            );
                                                          });
                                                          Navigator.pop(context);
                                                        }
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ];
                              },
                            ),
                          ),
                        ),
                      const SizedBox(width: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '$points pts',
                          style: TextStyle(
                            color: Colors.green[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTaskColor(Map<String, dynamic> task) {
    String taskId = task["taskID"] ?? '';
    if (taskId.isEmpty) {
      return Colors.grey[300]!;
    }

    List<String> parts = taskId.split('_');
    if (parts.length < 2) {
      return Colors.grey[300]!;
    }

    String initials = parts[0];
    var category = categories.firstWhere(
      (cat) => cat["initials"] == initials,
      orElse: () => <String, Object>{"color": Colors.grey[300]!},
    );
    Color color = category["color"] as Color;
    print('Task $taskId initials: $initials, color: $color');
    return color;
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1),
      ],
    );
  }
}