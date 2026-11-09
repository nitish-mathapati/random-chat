import 'package:flutter/material.dart';

import 'matching_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String chatMode;
  final String guestId;

  const ProfileScreen({
    super.key,
    required this.chatMode,
    required this.guestId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController nameController = TextEditingController();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  void saveProfile() {
    if (formKey.currentState!.validate()) {
      final String userName = nameController.text.trim();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatchingScreen(
            userName: userName,
            chatMode: widget.chatMode,
            guestId: widget.guestId,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        title: const Text('Your Profile'),
        backgroundColor: const Color(0xFF0B1020),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tell us about yourself',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Selected chat mode: ${widget.chatMode}',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 35),
              const Text(
                'Display Name',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter your display name',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF263653),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your display name';
                  }

                  if (value.trim().length < 3) {
                    return 'Name must contain at least 3 characters';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: saveProfile,
                  child: const Text(
                    'Find Someone',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
