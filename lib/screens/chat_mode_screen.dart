import 'package:flutter/material.dart';

import 'profile_screen.dart';

class ChatModeScreen extends StatefulWidget {
  final String guestId;

  const ChatModeScreen({super.key, required this.guestId});

  @override
  State<ChatModeScreen> createState() => _ChatModeScreenState();
}

class _ChatModeScreenState extends State<ChatModeScreen> {
  String selectedMode = 'Text Chat';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        foregroundColor: Colors.white,
        title: const Text('Choose Chat Mode'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How would you like to connect?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            buildModeButton(title: 'Text Chat', icon: Icons.chat),
            const SizedBox(height: 16),
            buildModeButton(title: 'Video Chat', icon: Icons.video_call),
            const SizedBox(height: 30),
            Text(
              'Selected Mode: $selectedMode',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        chatMode: selectedMode,
                        guestId: widget.guestId,
                      ),
                    ),
                  );
                },
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildModeButton({required String title, required IconData icon}) {
    final bool isSelected = selectedMode == title;

    return SizedBox(
      width: double.infinity,
      height: 75,
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            selectedMode = title;
          });
        },
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? Colors.deepPurple
              : const Color(0xFF263653),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
