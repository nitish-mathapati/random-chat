import 'package:flutter/material.dart';

import '../services/guest_session_storage.dart';
import '../services/matchmaking_api.dart';
import '../services/socket_service.dart';
import 'chat_screen.dart';

class MatchingScreen extends StatefulWidget {
  final String userName;
  final String chatMode;
  final String guestId;

  const MatchingScreen({
    super.key,
    required this.userName,
    required this.chatMode,
    required this.guestId,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  bool _isSearching = true;
  bool _isOpeningChat = false;

  String _statusMessage = 'Connecting to matchmaking...';
  String? _sessionToken;

  @override
  void initState() {
    super.initState();

    SocketService.instance.onMatchFound(_handleMatchFound);

    _startSearching();
  }

  Future<void> _startSearching() async {
    try {
      final token = await GuestSessionStorage.getSessionToken();

      if (token == null || token.isEmpty) {
        throw Exception('Guest session not found. Please restart the app.');
      }

      _sessionToken = token;

      if (!SocketService.instance.isConnected) {
        throw Exception(
          'Socket connection is not ready. Please go back and try again.',
        );
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Finding someone for you...';
        });
      }

      final response = await MatchmakingApi.joinQueue(
        token,
        chatMode: widget.chatMode.toLowerCase().contains('video')
            ? 'video'
            : 'text',
      );

      if (!mounted || _isOpeningChat) return;

      final data = response['data'] as Map<String, dynamic>;
      final status = data['status']?.toString();

      if (status == 'waiting') {
        setState(() {
          _isSearching = true;
          _statusMessage = 'Waiting for another user to join...';
        });
      } else if (status == 'matched' || status == 'already_matched') {
        await _openMatchedChat(
          data['matchId']?.toString(),
          data['partnerGuestId']?.toString(),
        );
      } else {
        throw Exception('Unexpected matchmaking response: $status');
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _statusMessage = error.toString();
      });
    }
  }

  void _handleMatchFound(dynamic eventData) {
    if (_isOpeningChat || !mounted) return;

    if (eventData is! Map) {
      debugPrint('[Matching] Invalid match event: $eventData');
      return;
    }

    _openMatchedChat(
      eventData['matchId']?.toString(),
      eventData['partnerGuestId']?.toString(),
    );
  }

  Future<void> _openMatchedChat(String? matchId, String? partnerGuestId) async {
    if (_isOpeningChat || !mounted) return;

    if (matchId == null ||
        matchId.isEmpty ||
        partnerGuestId == null ||
        partnerGuestId.isEmpty) {
      debugPrint('[Matching] Match details are incomplete.');
      return;
    }

    _isOpeningChat = true;

    setState(() {
      _isSearching = false;
      _statusMessage = 'Match found!';
    });

    SocketService.instance.offMatchFound();

    if (!mounted) return;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          partnerName: 'Matched User',
          chatMode: widget.chatMode,
          guestId: widget.guestId,
          matchId: matchId,
          partnerGuestId: partnerGuestId,
        ),
      ),
    );
  }

  Future<void> _cancelSearch() async {
    final token = _sessionToken;

    if (token != null) {
      try {
        await MatchmakingApi.cancelQueue(token);
      } catch (error) {
        debugPrint('[Matching] Queue cancellation error: $error');
      }
    }

    SocketService.instance.offMatchFound();

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  void dispose() {
    SocketService.instance.offMatchFound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Finding a Match'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_alt_outlined,
              size: 85,
              color: Colors.deepPurpleAccent,
            ),
            const SizedBox(height: 35),
            const Text(
              'Finding someone for you...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (_isSearching)
              const CircularProgressIndicator(color: Colors.deepPurpleAccent),
            const SizedBox(height: 30),
            Text(
              'Hello, ${widget.userName}!',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              'Chat Mode: ${widget.chatMode}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 35),
            if (!_isSearching && !_isOpeningChat)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                      _statusMessage = 'Trying again...';
                    });

                    _startSearching();
                  },
                  child: const Text('Try Again'),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: _cancelSearch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.deepPurpleAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Cancel Search'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
