import 'package:flutter/material.dart';

import '../widgets/app_logo.dart';
import '../widgets/action_button.dart';
import 'chat_mode_screen.dart';

class HomeScreen extends StatelessWidget {
  final String guestId;

  const HomeScreen({super.key, required this.guestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogo(),
              const Spacer(),
              const Text(
                'Meet someone new.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Connect with people around the world.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 40),
              ActionButton(
                title: 'Start Random Chat',
                icon: Icons.chat_bubble_outline,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatModeScreen(guestId: guestId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ActionButton(
                title: 'Start Video Chat',
                icon: Icons.videocam_outlined,
                isPrimary: false,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video chat is coming soon!')),
                  );
                },
              ),
              const Spacer(),
              const Center(
                child: Text(
                  'Be respectful. Stay safe. Enjoy connecting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
