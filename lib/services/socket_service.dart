
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  // Current laptop Wi-Fi IPv4 address.
  static const String _serverUrl = 'http://192.168.1.11:3000';

  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  // --------------------------------------------------
  // CONNECTION MANAGEMENT
  // --------------------------------------------------

  void connect(String sessionToken) {
    if (_socket != null) {
      if (_socket!.connected) {
        debugPrint('[Socket] Already connected.');
        return;
      }

      _socket!.dispose();
      _socket = null;
    }

    debugPrint('[Socket] Connecting to $_serverUrl');

    _socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': sessionToken})
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connected successfully.');
      debugPrint('[Socket] Socket ID: ${_socket!.id}');
    });

    _socket!.onConnectError((error) {
      debugPrint('[Socket] Connection error: $error');
    });

    _socket!.onError((error) {
      debugPrint('[Socket] Error: $error');
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[Socket] Disconnected: $reason');
    });

    _socket!.connect();
  }

  void disconnect() {
    if (_socket == null) {
      return;
    }

    _socket!.disconnect();
    _socket!.dispose();
    _socket = null;

    debugPrint('[Socket] Connection closed.');
  }

  // --------------------------------------------------
  // MATCHMAKING EVENTS
  // --------------------------------------------------

  void onMatchFound(void Function(dynamic data) callback) {
    if (_socket == null) {
      debugPrint('[Socket] Cannot listen: socket is not initialized.');
      return;
    }

    _socket!.on('match_found', callback);
    debugPrint('[Socket] Listening for match_found.');
  }

  void offMatchFound() {
    _socket?.off('match_found');
    debugPrint('[Socket] Removed match_found listener.');
  }

  // --------------------------------------------------
  // SEND CHAT MESSAGE
  // --------------------------------------------------

  void sendMessage({
    required String matchId,
    required String message,
  }) {
    if (!isConnected) {
      debugPrint('[Socket] Cannot send message: not connected.');
      return;
    }

    final trimmedMessage = message.trim();

    if (trimmedMessage.isEmpty) {
      debugPrint('[Socket] Cannot send an empty message.');
      return;
    }

    _socket!.emit('send_message', {
      'matchId': matchId,
      'message': trimmedMessage,
    });

    debugPrint('[Socket] Message sent to backend.');
  }

  // --------------------------------------------------
  // RECEIVE NEW MESSAGES
  // --------------------------------------------------

  void onNewMessage(void Function(dynamic data) callback) {
    if (_socket == null) {
      debugPrint('[Socket] Cannot listen: socket is not initialized.');
      return;
    }

    _socket!.on('new_message', callback);
    debugPrint('[Socket] Listening for new_message.');
  }

  void offNewMessage() {
    _socket?.off('new_message');
    debugPrint('[Socket] Removed new_message listener.');
  }

  // --------------------------------------------------
  // REQUEST CHAT HISTORY
  // --------------------------------------------------

  void requestChatHistory({
    required String matchId,
    int limit = 50,
  }) {
    if (!isConnected) {
      debugPrint('[Socket] Cannot request history: not connected.');
      return;
    }

    _socket!.emit('get_chat_history', {
      'matchId': matchId,
      'limit': limit,
    });

    debugPrint('[Socket] Chat history requested.');
  }

  // --------------------------------------------------
  // RECEIVE CHAT HISTORY
  // --------------------------------------------------

  void onChatHistory(void Function(dynamic data) callback) {
    if (_socket == null) {
      debugPrint('[Socket] Cannot listen: socket is not initialized.');
      return;
    }

    _socket!.on('chat_history', callback);
    debugPrint('[Socket] Listening for chat_history.');
  }

  void offChatHistory() {
    _socket?.off('chat_history');
    debugPrint('[Socket] Removed chat_history listener.');
  }

  // --------------------------------------------------
  // RECEIVE MESSAGE ERRORS
  // --------------------------------------------------

  void onMessageError(void Function(dynamic data) callback) {
    if (_socket == null) {
      debugPrint('[Socket] Cannot listen: socket is not initialized.');
      return;
    }

    _socket!.on('message_error', callback);
    debugPrint('[Socket] Listening for message_error.');
  }

  void offMessageError() {
    _socket?.off('message_error');
    debugPrint('[Socket] Removed message_error listener.');
  }

  // --------------------------------------------------
  // END MATCH
  // --------------------------------------------------

  void endMatch({
    required String matchId,
  }) {
    if (!isConnected) {
      debugPrint('[Socket] Cannot end match: not connected.');
      return;
    }

    _socket!.emit('end_match', {
      'matchId': matchId,
    });

    debugPrint('[Socket] End match request sent.');
  }

  // --------------------------------------------------
  // RECEIVE MATCH ENDED EVENT
  // --------------------------------------------------

  void onMatchEnded(void Function(dynamic data) callback) {
    if (_socket == null) {
      debugPrint('[Socket] Cannot listen: socket is not initialized.');
      return;
    }

    _socket!.on('match_ended', callback);
    debugPrint('[Socket] Listening for match_ended.');
  }

  void offMatchEnded() {
    _socket?.off('match_ended');
    debugPrint('[Socket] Removed match_ended listener.');
  }

  // ==================================================
  // WEBRTC SIGNALING
  // ==================================================

  // --------------------------------------------------
  // SEND WEBRTC OFFER
  // --------------------------------------------------

  void sendWebRtcOffer({
    required String matchId,
    required Map<String, dynamic> description,
  }) {
    if (!isConnected) {
      debugPrint('[WebRTC] Cannot send offer: not connected.');
      return;
    }

    _socket!.emit('webrtc_offer', {
      'matchId': matchId,
      'description': description,
    });

    debugPrint('[WebRTC] Offer sent.');
  }

  // --------------------------------------------------
  // RECEIVE WEBRTC OFFER
  // --------------------------------------------------

  void onWebRtcOffer(void Function(dynamic data) callback) {
    if (_socket == null) {
      debugPrint('[WebRTC] Cannot listen: socket is not initialized.');
      return;
    }

    _socket!.on('webrtc_offer', callback);
    debugPrint('[WebRTC] Listening for offers.');
  }

  void offWebRtcOffer() {
    _socket?.off('webrtc_offer');
  }

  // --------------------------------------------------
  // SEND WEBRTC ANSWER
  // --------------------------------------------------

  void sendWebRtcAnswer({
    required String matchId,
    required Map<String, dynamic> description,
  }) {
    if (!isConnected) {
      debugPrint('[WebRTC] Cannot send answer: not connected.');
      return;
    }

    _socket!.emit('webrtc_answer', {
      'matchId': matchId,
      'description': description,
    });

    debugPrint('[WebRTC] Answer sent.');
  }

  // --------------------------------------------------
  // RECEIVE WEBRTC ANSWER
  // --------------------------------------------------

  void onWebRtcAnswer(void Function(dynamic data) callback) {
    if (_socket == null) {
      debugPrint('[WebRTC] Cannot listen: socket is not initialized.');
      return;
    }

    _socket!.on('webrtc_answer', callback);
    debugPrint('[WebRTC] Listening for answers.');
  }

  void offWebRtcAnswer() {
    _socket?.off('webrtc_answer');
  }

  // --------------------------------------------------
  // SEND ICE CANDIDATE
  // --------------------------------------------------

  void sendWebRtcIceCandidate({
    required String matchId,
    required Map<String, dynamic> candidate,
  }) {
    if (!isConnected) {
      debugPrint('[WebRTC] Cannot send ICE candidate: not connected.');
      return;
    }

    _socket!.emit('webrtc_ice_candidate', {
      'matchId': matchId,
      'candidate': candidate,
    });

    debugPrint('[WebRTC] ICE candidate sent.');
  }

  // --------------------------------------------------
  // RECEIVE ICE CANDIDATE
  // --------------------------------------------------

  void onWebRtcIceCandidate(void Function(dynamic data) callback) {
    if (_socket == null) {
      debugPrint('[WebRTC] Cannot listen: socket is not initialized.');
      return;
    }

    _socket!.on('webrtc_ice_candidate', callback);
    debugPrint('[WebRTC] Listening for ICE candidates.');
  }

  void offWebRtcIceCandidate() {
    _socket?.off('webrtc_ice_candidate');
  }

  // --------------------------------------------------
  // WEBRTC HANG UP
  // --------------------------------------------------

  void sendWebRtcHangup({required String matchId}) {
    if (!isConnected) return;

    _socket!.emit('webrtc_hangup', {'matchId': matchId});

    debugPrint('[WebRTC] Hang-up sent.');
  }

  void onWebRtcHangup(void Function(dynamic data) callback) {
    if (_socket == null) {
      debugPrint('[WebRTC] Cannot listen: socket is not initialized.');
      return;
    }

    _socket!.on('webrtc_hangup', callback);
  }

  void offWebRtcHangup() {
    _socket?.off('webrtc_hangup');
  }

  // --------------------------------------------------
  // WEBRTC SIGNALING ERRORS
  // --------------------------------------------------

  void onWebRtcSignalError(void Function(dynamic data) callback) {
    if (_socket == null) {
      debugPrint('[WebRTC] Cannot listen: socket is not initialized.');
      return;
    }

    _socket!.on('webrtc_signal_error', callback);
    debugPrint('[WebRTC] Listening for signaling errors.');
  }

  void offWebRtcSignalError() {
    _socket?.off('webrtc_signal_error');
  }
}
