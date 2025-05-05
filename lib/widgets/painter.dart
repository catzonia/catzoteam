import 'package:flutter/material.dart';

class RoundedLinearProgressPainter extends CustomPainter {
  final double progress;
  final double inProgress;

  RoundedLinearProgressPainter(this.progress, this.inProgress);

  @override
  void paint(Canvas canvas, Size size) {
    Paint backgroundPaint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;

    Paint inProgressPaint = Paint()
      ..color = Colors.orange[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;

    Paint progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.deepOrange[400]!, Colors.deepOrange[800]!],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;

    Paint notchPaint = Paint()
      ..color = Colors.orange[100]!.withOpacity(0.5)
      ..style = PaintingStyle.fill;


    // Draw background line
    Offset startPoint = Offset(0, size.height / 2);
    Offset endPoint = Offset(size.width, size.height / 2);
    canvas.drawLine(startPoint, endPoint, backgroundPaint);

    // Draw in-progress segment (behind actual progress)
    if (inProgress > 0) {
      double inProgressEnd = (progress + inProgress).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(size.width * progress, size.height / 2),
        Offset(size.width * inProgressEnd, size.height / 2),
        inProgressPaint,
      );
    }

    // Draw completed segment
    if (progress > 0) {
      canvas.drawLine(startPoint, Offset(size.width * progress, size.height / 2), progressPaint);
    }

    // Draw milestone notches
    const double maxPoints = 85;
    const List<double> milestonePoints = [45, 55, 65, 75];
    List<double> milestoneFractions = milestonePoints.map((point) => point / maxPoints).toList();

    double notchWidth = 2.5;
    double notchHeight = size.height;

    for (double fraction in milestoneFractions) {
      double milestoneX = fraction * size.width;
      Rect notchRect = Rect.fromLTWH(
        milestoneX - notchWidth / 2,
        0,
        notchWidth,
        notchHeight,
      );
      canvas.drawRect(notchRect, notchPaint);
    }
  }

  @override
  bool shouldRepaint(RoundedLinearProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class DualProgressPainter extends CustomPainter {
  final double completedPercentage;
  final double inProgressPercentage;

  DualProgressPainter({
    required this.completedPercentage,
    required this.inProgressPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint backgroundPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.fill;

    Paint completedPaint = Paint()
      ..color = Colors.green[700]!
      ..style = PaintingStyle.fill;

    Paint inProgressPaint = Paint()
      ..color = Colors.yellow[700]!
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(10),
      ),
      backgroundPaint,
    );

    double inProgressWidth = size.width * (completedPercentage + inProgressPercentage).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, inProgressWidth, size.height),
        const Radius.circular(10),
      ),
      inProgressPaint,
    );

    double completedWidth = size.width * completedPercentage;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, completedWidth, size.height),
        const Radius.circular(10),
      ),
      completedPaint,
    );
  }

  @override
  bool shouldRepaint(DualProgressPainter oldDelegate) {
    return oldDelegate.completedPercentage != completedPercentage || oldDelegate.inProgressPercentage != inProgressPercentage;
  }
}