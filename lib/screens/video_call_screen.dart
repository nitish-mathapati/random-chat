
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/socket_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String? guestId;
  final String? partnerGuestId;
  final String? matchId;

  final Map<String, dynamic>? initialOffer;
  final List<Map<String, dynamic>> initialIceCandidates;

  const VideoCallScreen({
    super.key,
    this.guestId,
    this.partnerGuestId,
    this.matchId,
    this.initialOffer,
    this.initialIceCandidates = const [],
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final SocketService _socketService = SocketService.instance;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final List<Map<String, dynamic>> _pendingIceCandidates = [];

  bool _isInitializing = true;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  bool _isRemoteDescriptionSet = false;
  bool _isCleaningUp = false;

  String? _errorMessage;

  bool get _hasCallInformation =>
      widget.guestId != null &&
      widget.partnerGuestId != null &&
      widget.matchId != null;

  bool get _isOfferer {
    if (!_hasCallInformation) return false;

    return widget.guestId!.compareTo(widget.partnerGuestId!) < 0;
  }

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      if (_hasCallInformation && !_socketService.isConnected) {
        throw Exception('Socket connection is not available.');
      }

      await _getLocalMedia();

      if (_hasCallInformation) {
        _registerSocketListeners();

        await _initializePeerConnection();

        if (widget.initialOffer != null) {
          _pendingIceCandidates.addAll(
            widget.initialIceCandidates,
          );
        }

        if (widget.initialOffer != null) {
          await _handleIncomingOffer(widget.initialOffer!);
        } else if (_isOfferer) {
          await _createAndSendOffer();
        }
      }

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (error) {
      debugPrint('Video call initialization error: $error');

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  Future<void> _getLocalMedia() async {
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
        'frameRate': {'ideal': 24},
      },
    };

    _localStream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);

    _localRenderer.srcObject = _localStream;

    if (mounted) {
      setState(() {});
    }
  }

  // Corrected callback types:
  // SocketService sends dynamic data, so convert it to a Map here.
  void _registerSocketListeners() {
    _socketService.onWebRtcAnswer((data) {
      if (data is Map) {
        _handleAnswer(Map<String, dynamic>.from(data));
      }
    });

    _socketService.onWebRtcIceCandidate((data) {
      if (data is Map) {
        _handleIceCandidate(Map<String, dynamic>.from(data));
      }
    });

    _socketService.onWebRtcSignalError((data) {
      if (data is Map) {
        _handleSignalError(Map<String, dynamic>.from(data));
      }
    });

    _socketService.onWebRtcHangup((data) {
      if (data is Map) {
        _handleRemoteHangup(Map<String, dynamic>.from(data));
      }
    });
  }

  Future<void> _handleRemoteHangup(Map<String, dynamic> data) async {
    if (data['matchId'] != widget.matchId ||
        data['fromGuestId'] != widget.partnerGuestId) {
      return;
    }

    await _cleanup();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The other person ended the call.')),
    );

    Navigator.of(context).pop();
  }

  Future<void> _initializePeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': [
        {
          'urls': 'stun:stun.l.google.com:19302',
        },
      ],
    };

    _peerConnection = await createPeerConnection(configuration);

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate == null || !_hasCallInformation) {
        return;
      }

      _socketService.sendWebRtcIceCandidate(
        matchId: widget.matchId!,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;

        if (mounted) {
          setState(() {});
        }
      }
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('WebRTC connection state: $state');

      if (mounted) {
        setState(() {});
      }
    };
  }

  Future<void> _createAndSendOffer() async {
    final offer = await _peerConnection!.createOffer();

    await _peerConnection!.setLocalDescription(offer);

    _socketService.sendWebRtcOffer(
      matchId: widget.matchId!,
      description: {
        'type': offer.type,
        'sdp': offer.sdp,
      },
    );
  }

  Future<void> _handleIncomingOffer(
    Map<String, dynamic> data,
  ) async {
    if (!_hasCallInformation) return;

    if (data['matchId'] != widget.matchId ||
        data['fromGuestId'] != widget.partnerGuestId) {
      return;
    }

    final description =
        Map<String, dynamic>.from(data['description'] as Map);

    if (description['type'] != 'offer') return;

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(
        description['sdp'] as String?,
        description['type'] as String?,
      ),
    );

    _isRemoteDescriptionSet = true;

    await _flushPendingIceCandidates();

    final answer = await _peerConnection!.createAnswer();

    await _peerConnection!.setLocalDescription(answer);

    _socketService.sendWebRtcAnswer(
      matchId: widget.matchId!,
      description: {
        'type': answer.type,
        'sdp': answer.sdp,
      },
    );
  }

  Future<void> _handleAnswer(
    Map<String, dynamic> data,
  ) async {
    if (!_hasCallInformation) return;

    if (data['matchId'] != widget.matchId ||
        data['fromGuestId'] != widget.partnerGuestId) {
      return;
    }

    final description =
        Map<String, dynamic>.from(data['description'] as Map);

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(
        description['sdp'] as String?,
        description['type'] as String?,
      ),
    );

    _isRemoteDescriptionSet = true;

    await _flushPendingIceCandidates();
  }

  Future<void> _handleIceCandidate(
    Map<String, dynamic> data,
  ) async {
    if (!_hasCallInformation) return;

    if (data['matchId'] != widget.matchId ||
        data['fromGuestId'] != widget.partnerGuestId) {
      return;
    }

    final candidate =
        Map<String, dynamic>.from(data['candidate'] as Map);

    if (!_isRemoteDescriptionSet) {
      _pendingIceCandidates.add(candidate);
      return;
    }

    await _addIceCandidate(candidate);
  }

  Future<void> _addIceCandidate(
    Map<String, dynamic> candidate,
  ) async {
    await _peerConnection!.addCandidate(
      RTCIceCandidate(
        candidate['candidate'] as String?,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      ),
    );
  }

  Future<void> _flushPendingIceCandidates() async {
    if (!_isRemoteDescriptionSet) return;

    final candidates =
        List<Map<String, dynamic>>.from(_pendingIceCandidates);

    _pendingIceCandidates.clear();

    for (final candidate in candidates) {
      await _addIceCandidate(candidate);
    }
  }

  void _handleSignalError(Map<String, dynamic> data) {
    debugPrint('WebRTC signaling error: ${data['message']}');

    if (mounted) {
      setState(() {
        _errorMessage =
            data['message']?.toString() ?? 'Signaling error';
      });
    }
  }

  void _toggleMicrophone() {
    if (_localStream == null) return;

    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = _isMuted;
    }

    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleCamera() {
    if (_localStream == null) return;

    for (final track in _localStream!.getVideoTracks()) {
      track.enabled = _isCameraOff;
    }

    setState(() {
      _isCameraOff = !_isCameraOff;
    });
  }

  Future<void> _switchCamera() async {
    if (_localStream == null) return;

    final videoTracks = _localStream!.getVideoTracks();

    if (videoTracks.isEmpty) return;

    await Helper.switchCamera(videoTracks.first);

    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
  }

  Future<void> _cleanup() async {
    if (_isCleaningUp) return;

    _isCleaningUp = true;

    _socketService.offWebRtcAnswer();
    _socketService.offWebRtcIceCandidate();
    _socketService.offWebRtcSignalError();
    _socketService.offWebRtcHangup();

    try {
      _peerConnection?.onIceCandidate = null;
      _peerConnection?.onTrack = null;

      await _peerConnection?.close();
      await _peerConnection?.dispose();

      for (final track in _localStream?.getTracks() ?? []) {
        await track.stop();
      }

      await _localStream?.dispose();

      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;

      await _localRenderer.dispose();
      await _remoteRenderer.dispose();
    } catch (error) {
      debugPrint('Video call cleanup error: $error');
    }
  }

  Future<void> _endCall() async {
    if (_hasCallInformation && !_isCleaningUp) {
      _socketService.sendWebRtcHangup(matchId: widget.matchId!);
    }

    await _cleanup();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video Call'),
        actions: [
          IconButton(
            onPressed: _endCall,
            icon: const Icon(Icons.call_end, color: Colors.red),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _remoteRenderer.srcObject != null
                ? RTCVideoView(
                    _remoteRenderer,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          color: Colors.white54,
                          size: 90,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Waiting for the other person...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
          ),
          Positioned(
            top: 16,
            right: 16,
            width: 120,
            height: 170,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.grey.shade900,
                child: _localRenderer.srcObject != null
                    ? RTCVideoView(
                        _localRenderer,
                        mirror: _isFrontCamera,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : const Center(
                        child: Icon(
                          Icons.videocam_off,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          if (_isInitializing)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          if (_errorMessage != null)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  onPressed: _toggleMicrophone,
                  backgroundColor:
                      _isMuted ? Colors.red : Colors.white24,
                ),
                const SizedBox(width: 20),
                _buildControlButton(
                  icon: _isCameraOff
                      ? Icons.videocam_off
                      : Icons.videocam,
                  onPressed: _toggleCamera,
                  backgroundColor:
                      _isCameraOff ? Colors.red : Colors.white24,
                ),
                const SizedBox(width: 20),
                _buildControlButton(
                  icon: Icons.flip_camera_android,
                  onPressed: _switchCamera,
                  backgroundColor: Colors.white24,
                ),
                const SizedBox(width: 20),
                _buildControlButton(
                  icon: Icons.call_end,
                  onPressed: _endCall,
                  backgroundColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return CircleAvatar(
      radius: 27,
      backgroundColor: backgroundColor,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
