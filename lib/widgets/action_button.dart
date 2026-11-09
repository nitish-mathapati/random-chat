import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const ActionButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(title),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(title),
            ),
    );
  }
}