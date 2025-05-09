import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class CustomDialog extends StatelessWidget {
  final String title;
  final String message;
  final List<Widget> actions;
  final Widget? leadingIcon;
  final ConfettiController? confettiController;

  const CustomDialog({
    required this.title,
    required this.message,
    required this.actions,
    this.leadingIcon,
    this.confettiController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              if (leadingIcon != null) ...[
                leadingIcon!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          actions: actions,
        ),
        if (confettiController != null)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiController!,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.08,
              numberOfParticles: 100,
              gravity: 0.3,
              minBlastForce: 5,
              maxBlastForce: 20,
              shouldLoop: false,
            ),
          ),
      ],
    );
  }
}