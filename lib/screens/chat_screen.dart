
import 'package:flutter/material.dart';

import '../services/socket_service.dart';
import 'video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String partnerName;
  final String chatMode;
  final String guestId;
  final String? matchId;
  final String? partnerGuestId;

  const ChatScreen({
    super.key,
    required this.partnerName,
    required this.chatMode,
    required this.guestId,
    this.matchId,
    this.partnerGuestId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final SocketService socketService = SocketService.instance;

  final List<Map<String, dynamic>> messages = [];

  // Incoming WebRTC call information.
  Map<String, dynamic>? _incomingOffer;
  final List<Map<String, dynamic>> _pendingIceCandidates = [];

  bool _incomingCallDialogVisible = false;
  bool _isVideoCallOpen = false;

  bool isLoadingHistory = true;
  bool isEndingChat = false;
  bool hasEndedChat = false;

  String? connectionError;

  bool get _hasValidMatch =>
      widget.matchId != null &&
      widget.partnerGuestId != null &&
      widget.guestId.isNotEmpty;

  // Both guests calculate the same offer creator.
  bool get _isOfferer =>
      _hasValidMatch &&
      widget.guestId.compareTo(widget.partnerGuestId!) < 0;

  bool get _isVideoMode =>
      widget.chatMode.toLowerCase().contains('video');

  @override
  void initState() {
    super.initState();
    initializeChat();
  }

  // ==================================================
  // CHAT INITIALIZATION
  // ==================================================

  void initializeChat() {
    if (!_hasValidMatch) {
      setState(() {
        connectionError = 'Invalid matchmaking information.';
        isLoadingHistory = false;
      });
      return;
    }

    if (!socketService.isConnected) {
      setState(() {
        connectionError = 'Not connected to the chat server.';
        isLoadingHistory = false;
      });
      return;
    }

    socketService.onNewMessage(handleNewMessage);
    socketService.onChatHistory(handleChatHistory);
    socketService.onMessageError(handleMessageError);
    socketService.onMatchEnded(handleMatchEnded);

    _registerIncomingCallListeners();

    socketService.requestChatHistory(
      matchId: widget.matchId!,
      limit: 50,
    );
  }

  // ==================================================
  // INCOMING WEBRTC SIGNAL LISTENERS
  // ==================================================

  void _registerIncomingCallListeners() {
    if (!_hasValidMatch || hasEndedChat || _isVideoCallOpen) {
      return;
    }

    socketService.onWebRtcOffer(_handleIncomingOffer);
    socketService.onWebRtcIceCandidate(_handleIncomingIceCandidate);

    debugPrint('[WebRTC] Chat screen listening for incoming calls.');
  }

  void _removeIncomingCallListeners() {
    socketService.offWebRtcOffer();
    socketService.offWebRtcIceCandidate();
  }

  void _handleIncomingOffer(dynamic data) {
    if (!mounted ||
        hasEndedChat ||
        _isVideoCallOpen ||
        _incomingCallDialogVisible ||
        data is! Map) {
      return;
    }

    final offerData = Map<String, dynamic>.from(data);

    if (offerData['matchId'] != widget.matchId ||
        offerData['fromGuestId'] != widget.partnerGuestId) {
      return;
    }

    final description = offerData['description'];

    if (description is! Map ||
        description['type'] != 'offer' ||
        description['sdp'] == null) {
      debugPrint('[WebRTC] Invalid incoming offer.');
      return;
    }

    _incomingOffer = offerData;

    debugPrint('[WebRTC] Incoming video call received.');

    _showIncomingCallDialog();
  }

  void _handleIncomingIceCandidate(dynamic data) {
    if (!mounted ||
        hasEndedChat ||
        _isVideoCallOpen ||
        data is! Map) {
      return;
    }

    final candidateData = Map<String, dynamic>.from(data);

    if (candidateData['matchId'] != widget.matchId ||
        candidateData['fromGuestId'] != widget.partnerGuestId) {
      return;
    }

    final candidate = candidateData['candidate'];

    if (candidate is! Map) return;

    _pendingIceCandidates.add(
      Map<String, dynamic>.from(candidate),
    );

    debugPrint('[WebRTC] Incoming ICE candidate buffered in chat.');
  }

  // ==================================================
  // INCOMING CALL DIALOG
  // ==================================================

  Future<void> _showIncomingCallDialog() async {
    if (!mounted || _incomingCallDialogVisible || _isVideoCallOpen) {
      return;
    }

    _incomingCallDialogVisible = true;

    final bool? accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF263653),
          title: const Text(
            'Incoming Video Call',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '${widget.partnerName} wants to start a video call.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Not now',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.videocam),
              label: const Text('Accept'),
            ),
          ],
        );
      },
    );

    _incomingCallDialogVisible = false;

    if (!mounted || hasEndedChat) return;

    if (accepted == true) {
      await _acceptIncomingCall();
    } else {
      _incomingOffer = null;
      _pendingIceCandidates.clear();
    }
  }

  // ==================================================
  // START OUTGOING VIDEO CALL
  // ==================================================

  Future<void> _startVideoCall() async {
    if (!_isOfferer ||
        !_hasValidMatch ||
        isEndingChat ||
        hasEndedChat ||
        _isVideoCallOpen) {
      return;
    }

    if (!socketService.isConnected) {
      showError('Not connected to the signaling server.');
      return;
    }

    await _openVideoCall();
  }

  // ==================================================
  // ACCEPT INCOMING VIDEO CALL
  // ==================================================

  Future<void> _acceptIncomingCall() async {
    final offer = _incomingOffer;

    if (offer == null || !mounted || hasEndedChat) {
      return;
    }

    await _openVideoCall(initialOffer: offer);
  }

  // ==================================================
  // OPEN WEBRTC SCREEN
  // ==================================================

  Future<void> _openVideoCall({
    Map<String, dynamic>? initialOffer,
  }) async {
    if (!mounted || _isVideoCallOpen || hasEndedChat) return;

    if (!_hasValidMatch || !socketService.isConnected) {
      showError('Unable to start video call.');
      return;
    }

    _isVideoCallOpen = true;

    final List<Map<String, dynamic>> initialCandidates =
        List<Map<String, dynamic>>.from(_pendingIceCandidates);

    _pendingIceCandidates.clear();
    _incomingOffer = null;

    // The video screen installs its own ICE listener.
    _removeIncomingCallListeners();

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            guestId: widget.guestId,
            partnerGuestId: widget.partnerGuestId,
            matchId: widget.matchId,
            initialOffer: initialOffer,
            initialIceCandidates: initialCandidates,
          ),
        ),
      );
    } finally {
      _isVideoCallOpen = false;

      if (mounted && !hasEndedChat) {
        _registerIncomingCallListeners();
      }
    }
  }

  // ==================================================
  // RECEIVE CHAT MESSAGES
  // ==================================================

  void handleNewMessage(dynamic data) {
    if (!mounted || data is! Map || hasEndedChat) return;

    final message = Map<String, dynamic>.from(data);

    if (message['matchId'] != widget.matchId) return;

    addMessage(message);
  }

  void handleChatHistory(dynamic data) {
    if (!mounted || data is! Map || hasEndedChat) return;

    final history = Map<String, dynamic>.from(data);

    if (history['matchId'] != widget.matchId) return;

    final receivedMessages = history['messages'];

    if (receivedMessages is! List) return;

    final List<Map<String, dynamic>> loadedMessages = [];

    for (final item in receivedMessages) {
      if (item is Map) {
        loadedMessages.add(Map<String, dynamic>.from(item));
      }
    }

    setState(() {
      messages
        ..clear()
        ..addAll(loadedMessages);

      isLoadingHistory = false;
      connectionError = null;
    });

    scrollToLatestMessage();
  }

  void handleMessageError(dynamic data) {
    if (!mounted || hasEndedChat) return;

    String errorMessage = 'Unable to send or receive message.';

    if (data is Map && data['message'] != null) {
      errorMessage = data['message'].toString();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  // ==================================================
  // MATCH ENDED
  // ==================================================

  void handleMatchEnded(dynamic data) {
    if (!mounted || data is! Map || hasEndedChat) return;

    final endedMatch = Map<String, dynamic>.from(data);

    if (endedMatch['matchId'] != widget.matchId) return;

    final String endedByGuestId =
        endedMatch['endedByGuestId']?.toString() ?? '';

    final bool endedByPartner =
        endedByGuestId == widget.partnerGuestId;

    hasEndedChat = true;

    debugPrint('[Chat] Match ended: ${widget.matchId}');

    showMatchEndedDialog(endedByPartner);
  }

  Future<void> showMatchEndedDialog(bool endedByPartner) async {
    if (!mounted) return;

    final String message = endedByPartner
        ? '${widget.partnerName} has ended the conversation.'
        : 'You have ended the conversation.';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF263653),
          title: const Text(
            'Conversation Ended',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.deepPurpleAccent),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // ==================================================
  // MESSAGE MANAGEMENT
  // ==================================================

  void addMessage(Map<String, dynamic> message) {
    final String? messageId = message['id']?.toString();

    if (messageId == null || messageId.isEmpty) return;

    final bool alreadyExists = messages.any(
      (existingMessage) => existingMessage['id'] == messageId,
    );

    if (alreadyExists) return;

    setState(() {
      messages.add(message);
    });

    scrollToLatestMessage();
  }

  void sendMessage() {
    if (hasEndedChat || isEndingChat) return;

    final String message = messageController.text.trim();

    if (message.isEmpty) return;

    if (widget.matchId == null) {
      showError('Match information is unavailable.');
      return;
    }

    if (!socketService.isConnected) {
      showError('Not connected to the chat server.');
      return;
    }

    socketService.sendMessage(
      matchId: widget.matchId!,
      message: message,
    );

    messageController.clear();
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  void scrollToLatestMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ==================================================
  // END CHAT
  // ==================================================

  Future<void> endChat() async {
    if (isEndingChat || hasEndedChat) return;

    final bool? shouldEnd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF263653),
          title: const Text(
            'End Conversation?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to end this conversation?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'End Chat',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldEnd != true) return;

    if (widget.matchId == null) {
      showError('Match information is unavailable.');
      return;
    }

    if (!socketService.isConnected) {
      showError('Not connected to the chat server.');
      return;
    }

    setState(() {
      isEndingChat = true;
    });

    socketService.endMatch(matchId: widget.matchId!);

    debugPrint('[Chat] End match request submitted.');
  }

  // ==================================================
  // DISPOSE
  // ==================================================

  @override
  void dispose() {
    socketService.offNewMessage();
    socketService.offChatHistory();
    socketService.offMessageError();
    socketService.offMatchEnded();

    _removeIncomingCallListeners();

    messageController.dispose();
    scrollController.dispose();

    super.dispose();
  }

  // ==================================================
  // BUILD UI
  // ==================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF263653),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.partnerName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              socketService.isConnected ? 'Connected' : 'Disconnected',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          // Only the designated offer creator starts the call.
          if (_isVideoMode && _isOfferer)
            IconButton(
              onPressed: isEndingChat || hasEndedChat || _isVideoCallOpen
                  ? null
                  : _startVideoCall,
              tooltip: 'Start Video Call',
              icon: const Icon(Icons.videocam),
            ),
          IconButton(
            onPressed: isEndingChat ? null : endChat,
            tooltip: 'End Chat',
            icon: const Icon(Icons.call_end),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF263653),
            child: Text(
              isEndingChat
                  ? 'Ending conversation...'
                  : connectionError ??
                      'You are now chatting with a stranger.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: isLoadingHistory
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepPurple,
                    ),
                  )
                : connectionError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            connectionError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      )
                    : messages.isEmpty
                        ? const Center(
                            child: Text(
                              'Say hello to start the conversation!',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];

                              final String senderGuestId =
                                  message['senderGuestId']?.toString() ?? '';

                              final bool isMe =
                                  senderGuestId == widget.guestId;

                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.75,
                                  ),
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.deepPurple
                                        : const Color(0xFF263653),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    message['message']?.toString() ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF263653),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      enabled: !isEndingChat && !hasEndedChat,
                      style: const TextStyle(color: Colors.white),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle:
                            const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0B1020),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: IconButton(
                      onPressed: isEndingChat || hasEndedChat
                          ? null
                          : sendMessage,
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
