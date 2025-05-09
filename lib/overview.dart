import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catzoteam/provider.dart';
import 'package:catzoteam/models/double.dart';
import 'package:catzoteam/models/painter.dart';
import 'package:catzoteam/models/task_category.dart';
import 'package:catzoteam/widgets/custom_dialog.dart';
import 'package:intl/intl.dart';
import 'dart:math';

const MaterialColor Colors_bronze = MaterialColor(0xFFCD7F32, <int, Color>{
  500: Color(0xFFCD7F32),
});

class OverviewScreen extends StatefulWidget {
  final String role;
  final String userName;

  const OverviewScreen(
      {this.role = "staff", this.userName = "Lathifah Husna", super.key});

  @override
  _OverviewScreenState createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen>
    with TickerProviderStateMixin {
  List<String> staffMembers = [];
  bool _isLoadingStaff = true;
  String _errorMessage = '';
  List<int> _congratulatedMilestones = [];

  final Map<double, Map<String, dynamic>> badgeData = {
    45.0: {
      "icon": Icons.star_border,
      "color": Colors_bronze,
      "label": "Bronze Starter"
    },
    55.0: {
      "icon": Icons.military_tech,
      "color": Colors.grey,
      "label": "Silver Achiever"
    },
    65.0: {
      "icon": Icons.workspace_premium,
      "color": Colors.amber,
      "label": "Golden Performer"
    },
    75.0: {
      "icon": Icons.diamond,
      "color": Colors.blue,
      "label": "Diamond Elite"
    },
    85.0: {
      "icon": Icons.emoji_events,
      "color": Colors.deepPurple,
      "label": "Champion Badge"
    },
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

 WidgetsBinding.instance.addPostFrameCallback((_) {
    _showDailyWelcomePopup(context, widget.userName);
  });

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

  Future<void> _showDailyWelcomePopup(BuildContext context, String userName) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10); // yyyy-MM-dd
    final key = 'welcome_shown_${userName}_$today';

    if (prefs.getBool(key) ?? false) return;

    await prefs.setBool(key, true);

    showDialog(
      context: context,
      builder: (_) => CustomDialog(
        title: "👋 Welcome ${userName.split(' ').first}",
        message: "Let’s crush today! 💪\n🎯 Target:\n➤ Get 20 points by 12:30 PM\n➤ Get 40 points by 4:00 PM\n\nYou’ve got this — every task counts! 🚀 Keep up the great work!",
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
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

  Future<bool> hasShownMilestone(String userName, int milestone) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    final key = 'shown_${milestone}_${userName}_$today';
    return prefs.getBool(key) ?? false;
  }

  Future<void> markMilestoneAsShown(String userName, int milestone) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    final key = 'shown_${milestone}_${userName}_$today';
    await prefs.setBool(key, true);
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

  void _checkAndAddEarnedBadges(double dailyPoints) {
    const List<double> milestones = [45.0, 55.0, 65.0, 75.0, 85.0];

    for (double milestone in milestones) {
      int milestoneInt = milestone.toInt();
      if (dailyPoints >= milestone &&
          !_congratulatedMilestones.contains(milestoneInt)) {
        setState(() {
          _congratulatedMilestones.add(milestoneInt);
        });

        // Only increment badge if NOT already earned today
        final taskProvider = Provider.of<TaskProvider>(context, listen: false);
        Map<String, double> badges =
            taskProvider.getStaffBadges(widget.userName);
        String badgeField = 'badge${milestone.toStringAsFixed(0)}';

        if ((badges[badgeField] ?? 0.0) == 0.0) {
          taskProvider.incrementBadge(widget.userName, milestone);
        } else {
          print('Badge $badgeField already earned today, skip increment');
        }
      }
    }
  }

  void _showBadgeDetailDialog(double milestone, String label) {
    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: "🎖 $label",
        message:
            "You have earned the '$label' badge by achieving ${milestone.toStringAsFixed(0)} daily points!\n\nKeep collecting more badges for rewards!",
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _checkWarningMilestones(double dailyPoints) {
    final now = TimeOfDay.now();
    final timeValue = Duration(hours: now.hour, minutes: now.minute);

    if (timeValue >= const Duration(hours: 12, minutes: 30) &&
        dailyPoints < 20.0 &&
        !_triggeredWarnings.contains(20)) {
      setState(() {
        _triggeredWarnings.add(20);
      });
      _warningAnimController.forward(from: 0.0);
      print("⚠️ Warning: <20 points after 12:30pm");
    }

    if (timeValue >= const Duration(hours: 16, minutes: 0) &&
        dailyPoints < 40.0 &&
        !_triggeredWarnings.contains(40)) {
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
        double monthlyPoints = taskProvider.getStaffMonthlyPoints(widget.userName);
        String selectedTrenche = taskProvider.getSelectedTrenche(widget.userName);
        double dailyDeficit = taskProvider.getStaffDailyDeficit(widget.userName);
        double dailyPoints = taskProvider.getStaffDailyPoints(widget.userName);
        double targetPoints = taskProvider.getTargetPoints(widget.userName);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          hasShownMilestone(widget.userName, 2600).then((alreadyShown) {
            if (dailyPoints >= 26.0 && !alreadyShown) {
              markMilestoneAsShown(widget.userName, 2600);
              _congratulatedMilestones.add(2600);
              showDialog(
                context: context,
                builder: (context) => CustomDialog(
                  title: "⏳ So Close",
                  message: "You’re just a few points away from your daily goal.\nKeep going — you’ve got this! 💥",
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            }
          });
          
          hasShownMilestone(widget.userName, 5300).then((alreadyShown) {
            if (dailyPoints >= 53.0 && !alreadyShown) {
              markMilestoneAsShown(widget.userName, 5300);
              _congratulatedMilestones.add(5300);
              final confettiControllerTop = ConfettiController(duration: Duration(seconds: 2));
              confettiControllerTop.play();
              showDialog(
                context: context,
                builder: (context) => CustomDialog(
                  title: "🎉 You Did It!",
                  message: "You’ve hit your daily target of X points — awesome work! 💪\nIf you still have time, try pushing a bit more. Let’s break limits together! 🚀",
                  actions: [
                    TextButton(
                      onPressed: () {
                        confettiControllerTop.stop();
                        Navigator.pop(context);
                      },
                      child: const Text("OK"),
                    ),
                  ],
                  confettiController: confettiControllerTop,
                ),
              );
            }
          });

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
                            backgroundImage:
                                const AssetImage('assets/profile.jpg'),
                            backgroundColor: Colors.grey[200],
                            child: Icon(Icons.pets,
                                size: 40, color: Colors.deepOrange[300]),
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
                            '${dailyPoints.toStringAsFixed(1)} / ${targetPoints.toStringAsFixed(1)}',
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
                            const double maxPoints =
                                85; // Same as in _buildDailyProgressBar
                            return SizedBox(
                              height: 36, // Height of the warning icons
                              width: double.infinity,
                              child: Stack(
                                children: _triggeredWarnings.map((milestone) {
                                  // Calculate the position of the milestone relative to the progress bar width
                                  double fraction = milestone / maxPoints;
                                  double leftPosition =
                                      fraction * availableWidth -
                                          18; // Center the icon (36/2 = 18)

                                  return Positioned(
                                    left: leftPosition.clamp(
                                        0,
                                        availableWidth -
                                            36), // Ensure it stays within bounds
                                    child: GestureDetector(
                                      onTap: () => _showWarningPopup(milestone),
                                      child: AnimatedBuilder(
                                        animation: _warningAnimController,
                                        builder: (context, child) {
                                          final jitter =
                                              _random.nextDouble() * 0.05;
                                          return Transform.scale(
                                            scale:
                                                _warningScaleAnimation.value +
                                                    jitter,
                                            child: Opacity(
                                              opacity: _warningOpacityAnimation
                                                  .value,
                                              child: Stack(
                                                children: [
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      color: Colors.red
                                                          .withOpacity(0.3),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      gradient:
                                                          const RadialGradient(
                                                        colors: [
                                                          Color(0xFFFF5252),
                                                          Color(0xFFD32F2F)
                                                        ],
                                                        center:
                                                            Alignment.center,
                                                        radius: 0.8,
                                                      ),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.red
                                                              .withOpacity(0.4),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                              0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Icon(
                                                        Icons
                                                            .warning_amber_rounded,
                                                        color: Colors.white,
                                                        size: 20),
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
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54),
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
                                    monthlyPoints.toStringAsFixed(1),
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
                                    dailyDeficit.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: dailyDeficit > 0
                                          ? Colors.red
                                          : Colors.black87,
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
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDailyProgressBar(double dailyPoints, double targetPoints) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    const List<double> milestones = [45.0, 55.0, 65.0, 75.0, 85.0];
    const double maxPoints = 85.0;

    // Calculate progress based on dailyPoints
    double progress = (dailyPoints / maxPoints).clamp(0.0, 1.0);

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
                    (taskProvider.getStaffInProgressPoints(widget.userName) /
                            85.0)
                        .clamp(0.0, 1.0),
                  ),
                ),
              );
            }),
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
                  ...milestones.asMap().entries.map((entry) {
                    double milestone = entry.value;
                    double fraction = milestone / maxPoints;
                    bool isReached = dailyPoints >= milestone;

                    double leftPosition;
                    if (milestone == 85.0) {
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
                            milestone.toStringAsFixed(0),
                            style: TextStyle(
                              color: isReached
                                  ? Colors.deepOrange
                                  : Colors.black38,
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

  void _showWarningPopup(int milestone) {
    final Map<int, Map<String, String>> warningData = {
      20: {
        'title': 'Heads Up: 20 Points Not Reached',
        'message': 'It’s 12:30 PM, and you’re still below 20 points.\nLet’s move faster to stay on track!',
      },
      40: {
        'title': 'Warning: 40 Points Not Reached',
        'message': 'It’s already 4:00 PM and your progress is still under 40 points.\nFinish your tasks soon to avoid delays.',
      },
    };

    if (!warningData.containsKey(milestone)) return;

    final title = warningData[milestone]!['title']!;
    final message = warningData[milestone]!['message']!;
    
    showDialog(
      context: context,
      builder: (_) => CustomDialog(
        title: title,
        message: message,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'I’ll complete my tasks',
              style: TextStyle(color: Colors.green),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'I’ll add more points',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
          leadingIcon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
        ),
      ),
    );
  }

  Widget _buildBadgeRow() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        Map<String, double> badges =
            taskProvider.getStaffBadges(widget.userName);

        // Filter badges that have count > 0
        List<MapEntry<String, double>> earnedBadges =
            badges.entries.where((entry) => entry.value > 0).toList();

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
            double milestone = double.parse(entry.key.replaceAll('badge', ''));
            double count = entry.value;
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
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: badge["color"]),
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
        double targetPoints = taskProvider.getTargetPoints(widget.userName);
        double currentPoints =
            taskProvider.getStaffDailyPoints(widget.userName);
        double remainingPoints = targetPoints - currentPoints;

        // Get today's date
        DateTime today = DateTime.now();
        String todayDateStr = DateFormat('yyyy-MM-dd').format(today);

        // Filter suggested tasks to only include those for today and displayed
        List<Map<String, dynamic>> suggestedTasks =
            taskProvider.suggestTasks(widget.userName).where((task) {
          try {
            String taskDate = task['date'] ?? '';
            return taskDate == todayDateStr;
          } catch (_) {
            return false;
          }
        }).toList();

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
                children: suggestedTasks
                    .map((task) => _buildSuggestedTaskCard(task, taskProvider))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestedTaskCard(
      Map<String, dynamic> task, TaskProvider taskProvider) {
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if ((task["catName"] ?? '').toString().trim().isNotEmpty &&
                    task["catName"].toString().trim() != '-')
                  Text(
                    task["catName"],
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 14),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${formatDouble(parsePoints(task["points"]))} pts',
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            Icon(Icons.star,
                                                color: Colors.green[700],
                                                size: 20),
                                            const SizedBox(width: 6),
                                            Text(
                                              "${formatDouble(parsePoints(task["points"]))} Points",
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.green[800],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if ((task["catName"] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty &&
                                            task["catName"].toString().trim() !=
                                                '-')
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          elevation: 2,
                                        ),
                                        onPressed: () {
                                          taskProvider.assignTask(
                                              task, widget.userName);
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  "Task '${task["task"]}' assigned to ${widget.userName}."),
                                              duration:
                                                  const Duration(seconds: 2),
                                              backgroundColor:
                                                  Colors.green[600],
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
        List<Map<String, dynamic>> incompleteTasks =
            taskProvider.assignedTasks.where((task) {
          bool isForUser = task["assignee"] == widget.userName ||
              (task["assistant1"] == widget.userName &&
                  task["assistant1"] != "none") ||
              (task["assistant2"] == widget.userName &&
                  task["assistant2"] != "none");
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

        Set<String> incompleteTaskIds =
            incompleteTasks.map((t) => t["taskID"].toString()).toSet();

        // Assigned Today
        List<Map<String, dynamic>> tasksToShow =
            taskProvider.assignedTasks.where((task) {
          bool isForUser = task["assignee"] == widget.userName ||
              (task["assistant1"] == widget.userName &&
                  task["assistant1"] != "none") ||
              (task["assistant2"] == widget.userName &&
                  task["assistant2"] != "none");
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

    final pageHeights = pages
        .map((page) => page.map(estimateTaskHeight).fold(0.0, (a, b) => a + b))
        .toList();
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
              Text('Incomplete Tasks',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                                    Text(task['taskID'],
                                        style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 12)),
                                    Text(task['task'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    if ((task['catName'] ?? '')
                                            .toString()
                                            .trim()
                                            .isNotEmpty &&
                                        task['catName'].toString().trim() !=
                                            '-')
                                      Text(task['catName'],
                                          style: const TextStyle(
                                              fontStyle: FontStyle.italic,
                                              fontSize: 14)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    '${formatDouble(parsePoints(task['points'] ?? 0))} pts',
                                    style: TextStyle(
                                        color: Colors.red[900],
                                        fontWeight: FontWeight.w600),
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
                                color: _incompletePage == index
                                    ? Colors.red
                                    : Colors.red[100],
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

  Widget _buildAssignedTaskList(
      List<Map<String, dynamic>> tasksToShow, TaskProvider taskProvider) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final pages = List.generate(
          (tasksToShow.length / 3).ceil(),
          (i) {
            final start = i * 3;
            final end = (start + 3 > tasksToShow.length)
                ? tasksToShow.length
                : start + 3;
            return tasksToShow.sublist(start, end);
          },
        );

        final pageHeights = pages
            .map((page) =>
                page.map(estimateTaskHeight).fold(0.0, (a, b) => a + b))
            .toList();
        final maxHeight =
            pageHeights.isNotEmpty ? pageHeights.reduce(max) : 0.0;

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
                  Text('Assigned Tasks',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              if (tasksToShow.isEmpty)
                const Center(
                    child: Text('No tasks assigned',
                        style: TextStyle(color: Colors.grey)))
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
                                // Updated line to handle double points
                                double points = parsePoints(task["points"]);
                                return _slidableTaskCard(
                                  task['taskID'],
                                  task['task'],
                                  task['catName'] ?? '',
                                  points,
                                  _getTaskColor(task),
                                  taskProvider,
                                  (task["taskID"] ?? '').startsWith("GR"),
                                  isAssisting: task["assignee"] !=
                                          widget.userName &&
                                      ((task["assistant1"] == widget.userName &&
                                              task["assistant1"] != "none") ||
                                          (task["assistant2"] ==
                                                  widget.userName &&
                                              task["assistant2"] != "none")),
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
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _assignedPage == index
                                          ? Colors.orange
                                          : Colors.orange[100],
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
        List<Map<String, dynamic>> tasksToShow =
            taskProvider.completedTasks.where((task) {
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
            final end = (start + 3 > tasksToShow.length)
                ? tasksToShow.length
                : start + 3;
            return tasksToShow.sublist(start, end);
          },
        );

        final pageHeights = pages
            .map((page) =>
                page.map(estimateTaskHeight).fold(0.0, (a, b) => a + b))
            .toList();
        final maxHeight =
            pageHeights.isNotEmpty ? pageHeights.reduce(max) : 0.0;

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
                  Text('Completed Tasks',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              if (tasksToShow.isEmpty)
                const Center(
                    child: Text('No tasks completed yet',
                        style: TextStyle(color: Colors.grey)))
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
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: taskColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(task['taskID'],
                                              style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 12)),
                                          Text(task['task'],
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          if ((task['catName'] ?? '')
                                              .isNotEmpty)
                                            Text(task['catName'],
                                                style: const TextStyle(
                                                    fontStyle: FontStyle.italic,
                                                    fontSize: 14)),
                                          if (task["isAssisting"] == true)
                                            const Text("(Assisting)",
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white)),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius:
                                              BorderRadius.circular(7),
                                        ),
                                        child: Text(
                                          '${formatDouble(parsePoints(task['points'] ?? 0))} pts',
                                          style: TextStyle(
                                              color: Colors.green[900],
                                              fontWeight: FontWeight.w600),
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
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _completedPage == index
                                          ? Colors.green
                                          : Colors.green[100],
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
    double points,
    Color color,
    TaskProvider taskProvider,
    bool isGroomingTask, {
    bool isAssisting = false,
  }) {
    String? selectedAssistant1 = taskProvider.assignedTasks.firstWhere(
        (task) => task['taskID'] == id,
        orElse: () => {})['assistant1'];
    String? selectedAssistant2 = taskProvider.assignedTasks.firstWhere(
        (task) => task['taskID'] == id,
        orElse: () => {})['assistant2'];
    String priority = taskProvider.assignedTasks.firstWhere(
            (task) => task['taskID'] == id,
            orElse: () => {})['priority'] ??
        'no';
    bool isPriority = priority == 'high';

    // Convert 'none' to null for dropdown values
    selectedAssistant1 =
        (selectedAssistant1 == 'none') ? null : selectedAssistant1;
    selectedAssistant2 =
        (selectedAssistant2 == 'none') ? null : selectedAssistant2;

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

    return FutureBuilder<bool>(
        future: widget.role == 'manager'
            ? taskProvider.isTomorrowPlanningComplete()
            : Future.value(true),
        builder: (context, snapshot) {
          bool isPlanningComplete = snapshot.data ?? false;
          bool canCompleteTask = widget.role != 'manager' ||
              (widget.role == 'manager' && isPlanningComplete && !isAssisting);

          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Slidable(
                key: ValueKey(id),
                closeOnScroll: true,
                endActionPane: ActionPane(
                  motion: DrawerMotion(),
                  extentRatio: 0.20,
                  children: [
                    if (!isAssisting && canCompleteTask)
                      SlidableAction(
                        onPressed: (context) {
                          final today =
                              DateFormat('yyyy-MM-dd').format(DateTime.now());
                          final task = taskProvider.assignedTasks.firstWhere(
                              (t) => t["taskID"] == id,
                              orElse: () => {});
                          if (task.isNotEmpty &&
                              (task["date"] == null ||
                                  task["date"].toString().isEmpty)) {
                            task["date"] = today;
                            print(
                                "Date was missing — set task[\"date\"] to today: $today for taskID: ${task["taskID"]}");
                          }
                          taskProvider.completeTask(id);
                        },
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        icon: Icons.check,
                        label: 'Complete',
                      ),
                    if (!isAssisting && !canCompleteTask)
                      SlidableAction(
                        onPressed: (context) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Please complete tomorrow's planning to mark tasks as complete."),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                        backgroundColor: Colors.grey[400]!,
                        foregroundColor: Colors.white,
                        icon: Icons.lock,
                        label: 'Locked',
                      ),
                  ],
                ),
                child: Container(
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
                              Text(id,
                                  style: TextStyle(
                                      color: Colors.grey[700], fontSize: 12)),
                              Text(
                                title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              if (catName.trim().isNotEmpty &&
                                  catName.trim() != '-')
                                Text(
                                  catName,
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              if (isAssisting)
                                const Text("(Assisting)",
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white)),
                            ],
                          ),
                        ),
                        // Right Column: Action Elements
                        Column(
                          mainAxisAlignment: isPriority
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
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
                                                builder: (BuildContext context,
                                                    StateSetter setState) {
                                                  List<String>
                                                      availableAssistants =
                                                      staffMembers
                                                          .where((staff) =>
                                                              staff !=
                                                              widget.userName)
                                                          .toList();
                                                  List<String>
                                                      assistant2Options =
                                                      selectedAssistant1 != null
                                                          ? availableAssistants
                                                              .where((staff) =>
                                                                  staff !=
                                                                  selectedAssistant1)
                                                              .toList()
                                                          : availableAssistants;

                                                  return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Text(
                                                              "Assistant 1: ",
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      14)),
                                                          SizedBox(
                                                            width: 120,
                                                            child:
                                                                DropdownButton<
                                                                    String>(
                                                              value:
                                                                  selectedAssistant1,
                                                              isExpanded: true,
                                                              hint: const Text(
                                                                  "Select",
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          14)),
                                                              items: availableAssistants
                                                                  .map((String
                                                                      staff) {
                                                                return DropdownMenuItem<
                                                                    String>(
                                                                  value: staff,
                                                                  child: Text(
                                                                    staff,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            14),
                                                                  ),
                                                                );
                                                              }).toList(),
                                                              onChanged: (String?
                                                                  newValue) {
                                                                setState(() {
                                                                  selectedAssistant1 =
                                                                      newValue;
                                                                  taskProvider.assignAssistant(
                                                                      id,
                                                                      selectedAssistant1,
                                                                      selectedAssistant2);
                                                                  if (newValue !=
                                                                      null) {
                                                                    ScaffoldMessenger.of(
                                                                            context)
                                                                        .showSnackBar(
                                                                      SnackBar(
                                                                        content:
                                                                            Text("Assigned $newValue as Assistant 1 for '$title'."),
                                                                        duration:
                                                                            const Duration(seconds: 2),
                                                                      ),
                                                                    );
                                                                  }
                                                                });
                                                                Navigator.pop(
                                                                    context);
                                                              },
                                                            ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.delete,
                                                              color: Colors.red,
                                                              size: 20,
                                                            ),
                                                            onPressed:
                                                                selectedAssistant1 !=
                                                                        null
                                                                    ? () {
                                                                        setState(
                                                                            () {
                                                                          String?
                                                                              removedAssistant =
                                                                              selectedAssistant1;
                                                                          if (selectedAssistant2 !=
                                                                              null) {
                                                                            selectedAssistant1 =
                                                                                selectedAssistant2;
                                                                            selectedAssistant2 =
                                                                                null;
                                                                            taskProvider.assignAssistant(
                                                                                id,
                                                                                selectedAssistant1,
                                                                                null);
                                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                                              SnackBar(
                                                                                content: Text("Removed $removedAssistant as Assistant 1 from '$title'."),
                                                                                duration: const Duration(seconds: 2),
                                                                              ),
                                                                            );
                                                                          } else {
                                                                            selectedAssistant1 =
                                                                                null;
                                                                            taskProvider.assignAssistant(
                                                                                id,
                                                                                null,
                                                                                null);
                                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                                              SnackBar(
                                                                                content: Text("Removed $removedAssistant as Assistant 1 from '$title'."),
                                                                                duration: const Duration(seconds: 2),
                                                                              ),
                                                                            );
                                                                          }
                                                                        });
                                                                        Navigator.pop(
                                                                            context);
                                                                      }
                                                                    : null,
                                                          ),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          const Text(
                                                              "Assistant 2: ",
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      14)),
                                                          SizedBox(
                                                            width: 120,
                                                            child:
                                                                DropdownButton<
                                                                    String>(
                                                              value:
                                                                  selectedAssistant2,
                                                              isExpanded: true,
                                                              hint: const Text(
                                                                  "Select",
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          14)),
                                                              items: assistant2Options
                                                                  .map((String
                                                                      staff) {
                                                                return DropdownMenuItem<
                                                                    String>(
                                                                  value: staff,
                                                                  child: Text(
                                                                    staff,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            14),
                                                                  ),
                                                                );
                                                              }).toList(),
                                                              onChanged: (String?
                                                                  newValue) {
                                                                setState(() {
                                                                  selectedAssistant2 =
                                                                      newValue;
                                                                  taskProvider.assignAssistant(
                                                                      id,
                                                                      selectedAssistant1,
                                                                      selectedAssistant2);
                                                                  if (newValue !=
                                                                      null) {
                                                                    ScaffoldMessenger.of(
                                                                            context)
                                                                        .showSnackBar(
                                                                      SnackBar(
                                                                        content:
                                                                            Text("Assigned $newValue as Assistant 2 for '$title'."),
                                                                        duration:
                                                                            const Duration(seconds: 2),
                                                                      ),
                                                                    );
                                                                  }
                                                                });
                                                                Navigator.pop(
                                                                    context);
                                                              },
                                                            ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.delete,
                                                              color: Colors.red,
                                                              size: 20,
                                                            ),
                                                            onPressed:
                                                                selectedAssistant2 !=
                                                                        null
                                                                    ? () {
                                                                        setState(
                                                                            () {
                                                                          String?
                                                                              removedAssistant =
                                                                              selectedAssistant2;
                                                                          selectedAssistant2 =
                                                                              null;
                                                                          taskProvider.assignAssistant(
                                                                              id,
                                                                              selectedAssistant1,
                                                                              null);
                                                                          ScaffoldMessenger.of(context)
                                                                              .showSnackBar(
                                                                            SnackBar(
                                                                              content: Text("Removed $removedAssistant as Assistant 2 from '$title'."),
                                                                              duration: const Duration(seconds: 2),
                                                                            ),
                                                                          );
                                                                        });
                                                                        Navigator.pop(
                                                                            context);
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    '${formatDouble(points)} pts',
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
              ));
        });
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
