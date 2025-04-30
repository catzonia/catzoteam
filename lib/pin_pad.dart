import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PinPadScreen extends StatefulWidget {
  final String type; // 'staff' or 'manager'
  final String selectedBranchCode; // Branch code from HomeScreen

  const PinPadScreen({super.key, required this.type, required this.selectedBranchCode});

  @override
  State<PinPadScreen> createState() => _PinPadScreenState();
}

class _PinPadScreenState extends State<PinPadScreen> with SingleTickerProviderStateMixin {
  static const int _pinLength = 4;

  String _pin = '';
  bool _shake = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleNumberPress(int number) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += number.toString();
      });
      if (_pin.length == _pinLength) {
        _handleSubmit();
      }
    }
  }

  void _handleBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  String capitalizeEachWord(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  Future<void> _handleSubmit() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('staffNumber', isEqualTo: int.parse(_pin))
          .where('branch', isEqualTo: widget.selectedBranchCode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var staffData = snapshot.docs.first.data() as Map<String, dynamic>;
        String role = staffData['role'] as String;
        String username = capitalizeEachWord(staffData['username'] as String); // Ensure consistent formatting

        if (widget.type == role) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Access Granted - Logging in as $username'),
              backgroundColor: Colors.green,
            ),
          );

          Future.delayed(const Duration(milliseconds: 500), () {
            Navigator.pop(context, {'success': true, 'userName': username});
          });
        } else {
          _handleInvalidPin("Role mismatch: Expected ${widget.type}, got $role");
        }
      } else {
        _handleInvalidPin("Invalid PIN or branch mismatch");
      }
    } catch (e) {
      _handleInvalidPin("Error verifying PIN: $e");
    }
  }

  void _handleInvalidPin(String message) {
    setState(() => _shake = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Access Denied - $message'),
        backgroundColor: Colors.red,
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _shake = false;
        _pin = '';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.type == 'staff' ? 'Staff Login' : 'Manager Login',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your 4-digit PIN',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 32),

              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    final isFilled = index < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFilled ? Colors.orange[500]! : Colors.grey[300]!,
                          width: 2,
                        ),
                        color: isFilled ? Colors.orange[500] : Colors.transparent,
                      ),
                    );
                  }),
                ),
              ).animate(
                effects: _shake
                    ? [
                        ShakeEffect(
                          duration: const Duration(milliseconds: 500),
                          hz: 4,
                          offset: const Offset(10, 0),
                        ),
                      ]
                    : [],
              ),
              const SizedBox(height: 24),

              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ...[1, 2, 3, 4, 5, 6, 7, 8, 9].map((num) => _buildButton(
                        text: num.toString(),
                        onTap: () => _handleNumberPress(num),
                      )),
                  _buildButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: _handleBackspace,
                    textColor: Colors.grey[500],
                  ),
                  _buildButton(
                    text: '0',
                    onTap: () => _handleNumberPress(0),
                  ),
                  _buildButton(
                    icon: Icons.arrow_forward_rounded,
                    onTap: _pin.length == _pinLength ? _handleSubmit : null,
                    backgroundColor: _pin.length == _pinLength
                        ? Colors.orange[500]
                        : Colors.grey[300],
                    textColor: _pin.length == _pinLength
                        ? Colors.white
                        : Colors.grey[300],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    String? text,
    IconData? icon,
    VoidCallback? onTap,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Colors.grey[100],
        foregroundColor: textColor ?? Colors.black87,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
        elevation: 2,
      ),
      child: icon != null
          ? Icon(icon, size: 24)
          : Text(
              text!,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }
}