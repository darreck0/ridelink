// RideLink — Prototype 01 (v3)
// Bago sa v3: bagong "moto HUD" na disenyo. Walang binago sa voice
// logic — pareho pa rin ang token fetch, permissions, at LiveKit flow.
// Nasa theme.dart ang mga kulay/type, at nasa widgets.dart ang mga
// bahagi ng UI.
//
// Flow:
//   1. Ilagay ang Sandbox ID (galing sa LiveKit dashboard settings)
//   2. Room name (pareho dapat sa lahat ng phones)
//   3. Pangalan mo (iba dapat bawat phone)
//   4. CONNECT

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background/flutter_background.dart';

import 'theme.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: RL.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const RideLinkApp());
}

class RideLinkApp extends StatelessWidget {
  const RideLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideLink P01',
      debugShowCheckedModeBanner: false,
      theme: RL.theme(),
      home: const ConnectPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// CONNECT PAGE
// ---------------------------------------------------------------------------

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  /// Ibinibigay sa build time, hindi isinusulat sa source — ang Sandbox ID
  /// ay nagbibigay ng access sa LiveKit project, at sinumang may hawak nito
  /// ay makakasali sa kahit anong room o makakaubos ng quota.
  ///
  ///   flutter run --dart-define-from-file=dev.json
  ///
  /// Blangko kapag walang ibinigay — ita-type na lang ito ng user.
  static const _defaultSandboxId = String.fromEnvironment('LK_SANDBOX_ID');

  final _sandboxCtrl = TextEditingController(text: _defaultSandboxId);
  final _roomCtrl = TextEditingController(text: 'testroom');
  final _nameCtrl = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _sandboxCtrl.dispose();
    _roomCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_sandboxCtrl.text.trim().isEmpty) {
      setState(() => _error =
          'Ilagay ang Sandbox ID mula sa LiveKit dashboard mo.');
      return;
    }

    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ilagay muna ang pangalan mo.');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      // 1. Permissions
      final statuses = await [
        Permission.microphone,
        Permission.bluetoothConnect,
      ].request();

      if (statuses[Permission.microphone] != PermissionStatus.granted) {
        throw Exception('Kailangan ng microphone permission.');
      }

      // 2. Android audio -> communication mode (Bluetooth SCO routing)
      await webrtc.Helper.setAndroidAudioConfiguration(
        webrtc.AndroidAudioConfiguration.communication,
      );

      // 2.5 Foreground service — para tuloy ang audio kahit naka-lock
      //     ang screen o nasa ibang app. May lalabas na notification
      //     habang aktibo ang room — normal at kailangan yun.
      const bgConfig = FlutterBackgroundAndroidConfig(
        notificationTitle: 'RideLink',
        notificationText: 'Voice room active — konektado ka pa rin',
        notificationImportance: AndroidNotificationImportance.normal,
        enableWifiLock: true,
      );
      final bgOk = await FlutterBackground.initialize(androidConfig: bgConfig);
      if (bgOk) {
        await FlutterBackground.enableBackgroundExecution();
      }

      // 3. Kunin ang token sa LiveKit sandbox token server.
      //    DEV/TESTING LANG ITO — sa Phase 4, ang Laravel na natin
      //    ang papalit dito (POST /api/rides/{ride}/voice/token).
      final uri = Uri.parse(
        'https://cloud-api.livekit.io/api/sandbox/connection-details',
      );

      final res = await http.post(
        uri,
        headers: {
          'X-Sandbox-ID': _sandboxCtrl.text.trim(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'roomName': _roomCtrl.text.trim(),
          'participantName': _nameCtrl.text.trim(),
          'room_name': _roomCtrl.text.trim(),
          'participant_name': _nameCtrl.text.trim(),
        }),
      );

      if (res.statusCode != 200) {
        throw Exception('Token server error ${res.statusCode}: ${res.body}');
      }

      final details = jsonDecode(res.body) as Map<String, dynamic>;
      final serverUrl = details['serverUrl'] as String;
      final token = details['participantToken'] as String;

      // 4. Connect to LiveKit
      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            dtx: true, // tahimik = walang packets, tipid sa data
          ),
          defaultAudioCaptureOptions: AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
        ),
      );

      await room.connect(serverUrl, token);

      // Wag sa loudspeaker — hayaan ang OS mag-route sa Bluetooth headset
      await Hardware.instance.setSpeakerphoneOn(false);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomPage(room: room)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Top strip: parang status bar ng instrument panel ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Text('PROTOTYPE 01',
                        style: RL.label.copyWith(color: RL.textLow)),
                    const Spacer(),
                    const StatusChip(
                      text: 'standby',
                      color: RL.amber,
                      pulse: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // --- Wordmark ---
              const Text('RIDELINK', style: RL.wordmark),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(width: 34, height: 2, color: RL.green),
                  const SizedBox(width: 10),
                  Text(
                    'GROUP VOICE FOR RIDERS',
                    style: RL.label.copyWith(color: RL.textMid),
                  ),
                ],
              ),

              const SizedBox(height: 44),

              // --- Server details ---
              HudField(
                controller: _sandboxCtrl,
                label: 'Sandbox ID',
                hint: 'galing sa LiveKit dashboard',
                enabled: !_connecting,
              ),
              const SizedBox(height: 22),
              HudField(
                controller: _roomCtrl,
                label: 'Room',
                hint: 'pareho sa lahat ng phone',
                enabled: !_connecting,
              ),
              const SizedBox(height: 22),
              HudField(
                controller: _nameCtrl,
                label: 'Callsign',
                hint: 'hal. Darreck',
                capitalization: TextCapitalization.words,
                enabled: !_connecting,
              ),

              const SizedBox(height: 34),

              HudButton(
                label: 'CONNECT',
                icon: Icons.podcasts_rounded,
                busy: _connecting,
                onPressed: _connecting ? null : _connect,
              ),

              if (_error != null) ...[
                const SizedBox(height: 20),
                HudAlert(_error!),
              ],

              const SizedBox(height: 40),

              // --- Footer note ---
              Center(
                child: Text(
                  'DEV BUILD · LIVEKIT SANDBOX',
                  style: RL.label.copyWith(color: RL.textLow, fontSize: 9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ROOM PAGE — participant list, open mic / PTT, mute
// ---------------------------------------------------------------------------

enum VoiceMode { openMic, pushToTalk }

class RoomPage extends StatefulWidget {
  final Room room;
  const RoomPage({super.key, required this.room});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late final EventsListener<RoomEvent> _listener;
  VoiceMode _mode = VoiceMode.pushToTalk;
  bool _micOn = false;
  bool _pttPressed = false;

  Room get room => widget.room;

  @override
  void initState() {
    super.initState();
    _listener = room.createListener();

    _listener.on<RoomEvent>((_) {
      if (mounted) setState(() {});
    });

    _listener.on<RoomDisconnectedEvent>((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: RL.redDim,
          content: Text(
            'DISCONNECTED — ${e.reason}',
            style: RL.label.copyWith(color: RL.red),
          ),
        ),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    });

    _setMic(false);
  }

  Future<void> _setMic(bool on) async {
    await room.localParticipant?.setMicrophoneEnabled(on);
    if (mounted) setState(() => _micOn = on);
  }

  void _switchMode(VoiceMode mode) {
    setState(() => _mode = mode);
    _setMic(mode == VoiceMode.openMic);
  }

  /// Ginagawang 0..4 na bar ang connection quality.
  int _bars(ConnectionQuality q) {
    switch (q) {
      case ConnectionQuality.excellent:
        return 4;
      case ConnectionQuality.good:
        return 3;
      case ConnectionQuality.poor:
        return 2;
      case ConnectionQuality.lost:
        return 0;
      case ConnectionQuality.unknown:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final participants = <Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];
    final speaking = participants.where((p) => p.isSpeaking).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _RoomHeader(
              roomName: room.name ?? 'TEST ROOM',
              riders: participants.length,
              onEnd: () async => room.disconnect(),
            ),

            // --- Participant list ---
            Expanded(
              child: participants.isEmpty
                  ? Center(
                      child: Text(
                        'WALA PANG RIDER',
                        style: RL.label.copyWith(color: RL.textLow),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: participants.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: HudLabel(
                              speaking > 0
                                  ? '$speaking NAGSASALITA'
                                  : 'ALL QUIET',
                              color: speaking > 0 ? RL.green : RL.textLow,
                            ),
                          );
                        }
                        final p = participants[i - 1];
                        return _RiderTile(
                          name: p.name.isNotEmpty ? p.name : p.identity,
                          isLocal: p is LocalParticipant,
                          isSpeaking: p.isSpeaking,
                          isMuted: p.isMuted,
                          level: p.audioLevel,
                          bars: _bars(p.connectionQuality),
                        );
                      },
                    ),
            ),

            // --- Controls ---
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              decoration: const BoxDecoration(
                color: RL.surface,
                border: Border(top: BorderSide(color: RL.line)),
              ),
              child: Column(
                children: [
                  ModeSwitch<VoiceMode>(
                    selected: _mode,
                    onChanged: _switchMode,
                    options: const [
                      (VoiceMode.pushToTalk, 'HOLD TO TALK'),
                      (VoiceMode.openMic, 'OPEN MIC'),
                    ],
                  ),
                  const SizedBox(height: 26),
                  PttButton(
                    holdMode: _mode == VoiceMode.pushToTalk,
                    live: _mode == VoiceMode.pushToTalk ? _pttPressed : _micOn,
                    onPressStart: () {
                      HapticFeedback.mediumImpact();
                      setState(() => _pttPressed = true);
                      _setMic(true);
                    },
                    onPressEnd: () {
                      setState(() => _pttPressed = false);
                      _setMic(false);
                    },
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _setMic(!_micOn);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    room.dispose();
    FlutterBackground.disableBackgroundExecution();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Mga bahagi ng room screen
// ---------------------------------------------------------------------------

class _RoomHeader extends StatelessWidget {
  final String roomName;
  final int riders;
  final VoidCallback onEnd;

  const _RoomHeader({
    required this.roomName,
    required this.riders,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: RL.surface,
        border: Border(bottom: BorderSide(color: RL.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const StatusChip(
                      text: 'live',
                      color: RL.green,
                      pulse: true,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$riders ${riders == 1 ? 'RIDER' : 'RIDERS'}',
                      style: RL.label.copyWith(color: RL.textLow),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  roomName.toUpperCase(),
                  style: RL.readout.copyWith(fontSize: 22, letterSpacing: 2),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // End call — bordered, hindi solid, para hindi ito ang unang
          // nahahawakan nang aksidente habang nagmamaneho.
          GestureDetector(
            onTap: onEnd,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: RL.redDim,
                borderRadius: BorderRadius.circular(RL.r),
                border: Border.all(color: RL.red.withValues(alpha: 0.6)),
              ),
              child: const Icon(Icons.call_end_rounded,
                  color: RL.red, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderTile extends StatelessWidget {
  final String name;
  final bool isLocal;
  final bool isSpeaking;
  final bool isMuted;
  final double level;
  final int bars;

  const _RiderTile({
    required this.name,
    required this.isLocal,
    required this.isSpeaking,
    required this.isMuted,
    required this.level,
    required this.bars,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final accent = isSpeaking ? RL.green : RL.lineBright;

    final String status;
    if (isSpeaking) {
      status = 'NAGSASALITA';
    } else if (isMuted) {
      status = 'NAKA-MUTE';
    } else {
      status = 'NAKIKINIG';
    }

    return HudPanel(
      bracketColor: accent,
      fill: isSpeaking ? RL.greenDim.withValues(alpha: 0.45) : RL.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          // Avatar block — parisukat, hindi bilog, para tumugma sa HUD.
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isSpeaking ? RL.green : RL.surfaceAlt,
              borderRadius: BorderRadius.circular(RL.rSm),
              border: Border.all(
                color: isSpeaking ? RL.green : RL.line,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isSpeaking ? const Color(0xFF04140C) : RL.textMid,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: RL.rider,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLocal) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: RL.surfaceAlt,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: RL.line),
                        ),
                        child: Text(
                          'IKAW',
                          style: RL.label.copyWith(
                            fontSize: 9,
                            color: RL.textMid,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  status,
                  style: RL.label.copyWith(
                    fontSize: 10,
                    color: isSpeaking
                        ? RL.green
                        : (isMuted ? RL.textLow : RL.textMid),
                  ),
                ),
              ],
            ),
          ),
          VoiceMeter(active: isSpeaking, level: level),
          const SizedBox(width: 14),
          SignalBars(bars: bars),
        ],
      ),
    );
  }
}
