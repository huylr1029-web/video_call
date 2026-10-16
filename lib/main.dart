import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// Truyền khi chạy: --dart-define=AGORA_APP_ID=...
// Nếu dự án Agora bật App Certificate, cần token hợp lệ cho đúng channel.
const String agoraAppId = String.fromEnvironment('AGORA_APP_ID');
const String agoraToken = String.fromEnvironment('AGORA_TOKEN');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AgoraDemoApp());
}

class AgoraDemoApp extends StatelessWidget {
  const AgoraDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agora Video Call Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const VideoCallDemo(),
    );
  }
}

class VideoCallDemo extends StatefulWidget {
  const VideoCallDemo({super.key});

  @override
  State<VideoCallDemo> createState() => _VideoCallDemoState();
}

class _VideoCallDemoState extends State<VideoCallDemo> {
  final TextEditingController _channelController =
      TextEditingController(text: 'demo_agora');
  RtcEngine? _engine;
  Timer? _timer;
  String _channel = '';
  String _status = 'Chưa tham gia';
  String? _error;
  int? _remoteUid;
  int _seconds = 0;
  bool _connecting = false;
  bool _joined = false;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _speakerEnabled = true;
  bool _disposing = false;

  Future<void> _join() async {
    if (_connecting || _engine != null) return;
    final channel = _channelController.text.trim();
    if (channel.isEmpty || agoraAppId.trim().isEmpty) {
      setState(() => _error = channel.isEmpty
          ? 'Hãy nhập Channel ID.'
          : 'Thiếu AGORA_APP_ID. Xem file README.md.');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
      _status = 'Đang cấp quyền và kết nối...';
    });
    try {
      final permissions = await [Permission.camera, Permission.microphone].request();
      if (permissions.values.any((p) => !p.isGranted)) {
        throw StateError('Cần cấp quyền Camera và Micro cho ứng dụng.');
      }
      if (!mounted || _disposing) return;

      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (!mounted || _disposing) return;
          setState(() {
            _joined = true;
            _status = 'Đã vào phòng – đang đợi người còn lại';
          });
          _timer?.cancel();
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted && !_disposing) setState(() => _seconds++);
          });
        },
        onUserJoined: (connection, uid, elapsed) {
          if (!mounted || _disposing) return;
          setState(() {
            _remoteUid = uid;
            _status = 'Đang gọi video';
          });
        },
        onUserOffline: (connection, uid, reason) {
          if (!mounted || _disposing) return;
          if (_remoteUid == uid) {
            setState(() {
              _remoteUid = null;
              _status = 'Người kia đã rời phòng';
            });
          }
        },
        onError: (code, message) {
          if (!mounted || _disposing) return;
          setState(() => _error = 'Agora: $code – $message');
        },
        onConnectionStateChanged: (connection, state, reason) {
          if (!mounted || _disposing) return;
          if (state == ConnectionStateType.connectionStateFailed) {
            setState(() => _error = 'Kết nối Agora thất bại: $reason');
          }
        },
      ));
      await engine.enableVideo();
      await engine.enableAudio();
      await engine.setDefaultAudioRouteToSpeakerphone(true);
      await engine.startPreview();
      if (!mounted || _disposing) {
        await _cleanup();
        return;
      }
      _channel = channel;
      await engine.joinChannel(
        token: agoraToken,
        channelId: channel,
        uid: 0, // Agora tự cấp UID, hai máy không cần nhập UID.
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e) {
      if (mounted && !_disposing) {
        setState(() {
          _error = e.toString();
          _status = 'Không thể kết nối';
        });
      }
      await _cleanup();
    } finally {
      if (mounted && !_disposing) setState(() => _connecting = false);
    }
  }

  Future<void> _cleanup() async {
    _timer?.cancel();
    _timer = null;
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      try {
        await engine.leaveChannel();
        await engine.release();
      } catch (e) {
        debugPrint('Agora release: $e');
      }
    }
  }

  Future<void> _leave() async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _status = 'Đang rời phòng...';
    });
    await _cleanup();
    if (!mounted || _disposing) return;
    setState(() {
      _connecting = false;
      _joined = false;
      _remoteUid = null;
      _seconds = 0;
      _channel = '';
      _micEnabled = true;
      _cameraEnabled = true;
      _speakerEnabled = true;
      _status = 'Chưa tham gia';
      _error = null;
    });
  }

  Future<void> _toggleMic() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_micEnabled;
    await engine.muteLocalAudioStream(!next);
    if (mounted) setState(() => _micEnabled = next);
  }

  Future<void> _toggleCamera() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_cameraEnabled;
    await engine.muteLocalVideoStream(!next);
    if (mounted) setState(() => _cameraEnabled = next);
  }

  Future<void> _switchCamera() async {
    final engine = _engine;
    if (engine != null) await engine.switchCamera();
  }

  Future<void> _toggleSpeaker() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_speakerEnabled;
    await engine.setEnableSpeakerphone(next);
    if (mounted) setState(() => _speakerEnabled = next);
  }

  @override
  void dispose() {
    _disposing = true;
    _channelController.dispose();
    _timer?.cancel();
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    return Scaffold(
      appBar: AppBar(title: const Text('Demo Agora RTC SDK')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(
              controller: _channelController,
              enabled: engine == null && !_connecting,
              decoration: const InputDecoration(
                labelText: 'Channel ID (nhập giống nhau trên hai máy)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text(_status, maxLines: 2, overflow: TextOverflow.ellipsis)),
              Text(_formatTime(_seconds), style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            if (_error != null) Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 10),
            Expanded(child: Stack(children: [
              Positioned.fill(child: Container(
                color: const Color(0xFF171A28),
                child: engine != null && _joined && _remoteUid != null
                    ? AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: engine,
                          canvas: VideoCanvas(uid: _remoteUid),
                          connection: RtcConnection(channelId: _channel),
                        ),
                      )
                    : const Center(child: Text(
                        'Video người tham gia khác sẽ hiện ở đây',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      )),
              )),
              Positioned(right: 12, top: 12, width: 125, height: 170,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.white, width: 2)),
                  child: engine != null && _cameraEnabled
                      ? AgoraVideoView(controller: VideoViewController(
                          rtcEngine: engine,
                          canvas: const VideoCanvas(uid: 0),
                        ))
                      : const Center(child: Icon(Icons.videocam_off, color: Colors.white)),
                ),
              ),
            ])),
            const SizedBox(height: 16),
            if (engine == null)
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _connecting ? null : _join,
                icon: const Icon(Icons.video_call),
                label: const Text('Tham gia cuộc gọi'),
              ))
            else
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                _control(_micEnabled ? Icons.mic : Icons.mic_off,
                    _micEnabled ? 'Tắt mic' : 'Bật mic', _toggleMic),
                _control(_cameraEnabled ? Icons.videocam : Icons.videocam_off,
                    _cameraEnabled ? 'Tắt camera' : 'Bật camera', _toggleCamera),
                _control(Icons.cameraswitch, 'Đổi camera', _switchCamera),
                _control(_speakerEnabled ? Icons.volume_up : Icons.hearing,
                    _speakerEnabled ? 'Tắt loa ngoài' : 'Bật loa ngoài', _toggleSpeaker),
                FilledButton.icon(
                  onPressed: _connecting ? null : _leave,
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.call_end),
                  label: const Text('Kết thúc'),
                ),
              ]),
          ]),
        ),
      ),
    );
  }

  Widget _control(IconData icon, String label, Future<void> Function() action) {
    return OutlinedButton.icon(
      onPressed: _connecting ? null : () { action(); },
      icon: Icon(icon),
      label: Text(label),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }
}
