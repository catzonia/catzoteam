import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:catzoteam/provider.dart';
import 'package:catzoteam/widgets/section_box.dart';

class TrencheScreen extends StatelessWidget {
  final List<Map<String, dynamic>> trenche = [
    {
      'title': '35',
      'points': '38 Points Daily',
      'grooming': '4-5 Grooming',
      'gradient': [Colors.orange[100]!, Colors.yellow[100]!],
      'totalBonus': 50, // Total Bonus
    },
    {
      'title': '40',
      'points': '43 Points Daily',
      'grooming': '5-6 Grooming',
      'gradient': [Colors.orange[200]!, Colors.yellow[200]!],
      'totalBonus': 150,
    },
    {
      'title': '45',
      'points': '48 Points Daily',
      'grooming': '6-7 Grooming',
      'gradient': [Colors.orange[300]!, Colors.yellow[300]!],
      'totalBonus': 275,
    },
    {
      'title': '50',
      'points': '53 Points Daily',
      'grooming': '7-8 Grooming',
      'gradient': [Colors.orange[400]!, Colors.yellow[400]!],
      'totalBonus': 425,
    },
    {
      'title': '55',
      'points': '58 Points Daily',
      'grooming': '8-9 Grooming',
      'gradient': [Colors.orange, Colors.yellow],
      'totalBonus': 600,
    },
    {
      'title': '60',
      'points': '63 Points Daily',
      'grooming': '9-10 Grooming',
      'gradient': [Colors.orange[600]!, Colors.yellow[600]!],
      'totalBonus': 800,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionBox(
              title: "Trenche",
              icon: Icons.bar_chart_rounded,
              child: _buildTrencheContent(context),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTrencheContent(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        return Column(
          children: [
            // Trenche cards and Total Bonus below
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: trenche.map((trenche) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Container(
                            width: 170,
                            height: 110,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: trenche['gradient'],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trenche['title'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  trenche['points'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  trenche['grooming'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Total Bonus below each card
                        Text.rich(
                          textAlign: TextAlign.center,
                          TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                text: "${trenche['totalBonus']}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                ),
                              ),
                              const TextSpan(
                                text: " TOTAL BONUS",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
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
        );
      },
    );
  }
}