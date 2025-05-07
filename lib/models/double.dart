double parsePoints(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

String formatDouble(double value) {
  if (value == value.truncateToDouble()) {
    // If the number has no decimal part (e.g., 10.0), display it as an integer
    return value.toInt().toString();
  } else {
    // Otherwise, display with one decimal place (e.g., 10.5)
    return value.toStringAsFixed(1);
  }
}