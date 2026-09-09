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
      setState(
          () => _error = 'Ilagay ang Sandbox ID mula sa LiveKit dashboard mo.');
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
      backgroundColor: RL.roomBg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [RL.roomBg, RL.roomBgDeep],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 700;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 36,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _ConnectBrandBar(),
                        SizedBox(height: compact ? 26 : 42),
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [RL.cyanBright, RL.cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: RL.cyan.withValues(alpha: 0.20),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.headset_mic_rounded,
                            color: RL.roomBgDeep,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Connect to your crew',
                          style: RL.roomTitle.copyWith(fontSize: 30),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'Join the same voice room and keep your group together on the road.',
                          style: RL.roomBody,
                        ),
                        SizedBox(height: compact ? 24 : 32),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                RL.roomSurfaceRaised,
                                RL.roomSurface,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(RL.roomRadius),
                            border: Border.all(
                              color: RL.roomBorder.withValues(alpha: 0.72),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              HudField(
                                controller: _sandboxCtrl,
                                label: 'LiveKit sandbox',
                                hint: 'Sandbox ID',
                                icon: Icons.cloud_outlined,
                                textInputAction: TextInputAction.next,
                                enabled: !_connecting,
                              ),
                              const SizedBox(height: 16),
                              HudField(
                                controller: _roomCtrl,
                                label: 'Room name',
                                hint: 'Same room for every rider',
                                icon: Icons.groups_2_outlined,
                                textInputAction: TextInputAction.next,
                                enabled: !_connecting,
                              ),
                              const SizedBox(height: 16),
                              HudField(
                                controller: _nameCtrl,
                                label: 'Your callsign',
                                hint: 'Example: Darreck',
                                icon: Icons.person_outline_rounded,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (!_connecting) _connect();
                                },
                                capitalization: TextCapitalization.words,
                                enabled: !_connecting,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        HudButton(
                          label: 'Join voice room',
                          icon: Icons.arrow_forward_rounded,
                          busy: _connecting,
                          onPressed: _connecting ? null : _connect,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          HudAlert(_error!),
                        ],
                        const Spacer(),
                        const SizedBox(height: 24),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: RL.roomTextLow,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Development build · LiveKit sandbox',
                              style: RL.roomCaption,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConnectBrandBar extends StatelessWidget {
  const _ConnectBrandBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: RL.cyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: RL.cyan.withValues(alpha: 0.22)),
          ),
          child: const Icon(
            Icons.route_rounded,
            color: RL.cyan,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'RideLink',
          style: RL.roomBody.copyWith(
            color: RL.roomText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: RL.cyan.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: RL.cyan,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'Ready',
                style: RL.roomCaption.copyWith(color: RL.cyanBright),
              ),
            ],
          ),
        ),
      ],
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
  bool _micBusy = false;
  bool _disconnecting = false;

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
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: RL.roomSurfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: RL.red.withValues(alpha: 0.28)),
          ),
          content: Row(
            children: [
              const Icon(Icons.link_off_rounded, color: RL.red, size: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Voice room disconnected',
                  style: RL.roomBody.copyWith(
                    color: RL.roomText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    });

    _setMic(false);
  }

  Future<void> _setMic(bool on) async {
    if (mounted) setState(() => _micBusy = true);
    try {
      await room.localParticipant?.setMicrophoneEnabled(on);
      if (mounted) setState(() => _micOn = on);
    } finally {
      if (mounted) setState(() => _micBusy = false);
    }
  }

  void _switchMode(VoiceMode mode) {
    setState(() => _mode = mode);
    _setMic(mode == VoiceMode.openMic);
  }

  Future<void> _endCall() async {
    setState(() => _disconnecting = true);
    try {
      await room.disconnect();
    } finally {
      if (mounted) setState(() => _disconnecting = false);
    }
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
    Participant? activeSpeaker;
    var weakConnection = false;
    for (final participant in participants) {
      if (activeSpeaker == null && participant.isSpeaking) {
        activeSpeaker = participant;
      }
      if (_bars(participant.connectionQuality) <= 2) {
        weakConnection = true;
      }
    }

    return Scaffold(
      backgroundColor: RL.roomBg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [RL.roomBg, RL.roomBgDeep],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 720;
              final pttDiameter = compact ? 124.0 : 154.0;

              return Column(
                children: [
                  _RoomHeader(
                    roomName: 'Testroom',
                    riders: participants.length,
                    disconnecting: _disconnecting,
                    onEnd: _endCall,
                  ),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            compact ? 12 : 18,
                            16,
                            8,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _SectionHeading(
                              title: 'Riders',
                              detail: speaking > 0
                                  ? '$speaking speaking'
                                  : 'Everyone is quiet',
                              active: speaking > 0,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          sliver: SliverList.separated(
                            itemCount: participants.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final p = participants[index];
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
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _RoomAmbient(
                            riders: participants.length,
                            speaking: speaking,
                            activeSpeakerName: activeSpeaker == null
                                ? null
                                : (activeSpeaker.name.isNotEmpty
                                    ? activeSpeaker.name
                                    : activeSpeaker.identity),
                            activeSpeakerLevel: activeSpeaker?.audioLevel ?? 0,
                            connecting: _micBusy,
                            weakConnection: weakConnection,
                            compact: compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CommunicationPanel(
                    mode: _mode,
                    micOn: _micOn,
                    pttPressed: _pttPressed,
                    micBusy: _micBusy,
                    disconnecting: _disconnecting,
                    pttDiameter: pttDiameter,
                    onModeChanged: _switchMode,
                    onPressStart: () {
                      HapticFeedback.mediumImpact();
                      setState(() => _pttPressed = true);
                      _setMic(true);
                    },
                    onPressEnd: () {
                      setState(() => _pttPressed = false);
                      _setMic(false);
                    },
                    onMicTap: () {
                      HapticFeedback.mediumImpact();
                      _setMic(!_micOn);
                    },
                  ),
                ],
              );
            },
          ),
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

class _SectionHeading extends StatelessWidget {
  final String title;
  final String detail;
  final bool active;

  const _SectionHeading({
    required this.title,
    required this.detail,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: RL.roomBody.copyWith(
            color: RL.roomText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? RL.cyan : RL.roomTextLow,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          detail,
          style: RL.roomCaption.copyWith(
            color: active ? RL.cyan : RL.roomTextLow,
          ),
        ),
      ],
    );
  }
}

class _RoomAmbient extends StatefulWidget {
  final int riders;
  final int speaking;
  final String? activeSpeakerName;
  final double activeSpeakerLevel;
  final bool connecting;
  final bool weakConnection;
  final bool compact;

  const _RoomAmbient({
    required this.riders,
    required this.speaking,
    required this.activeSpeakerName,
    required this.activeSpeakerLevel,
    required this.connecting,
    required this.weakConnection,
    required this.compact,
  });

  @override
  State<_RoomAmbient> createState() => _RoomAmbientState();
}

class _RoomAmbientState extends State<_RoomAmbient>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeSpeakerName != null;
    final diameter = widget.compact ? 80.0 : 132.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: widget.compact ? 6 : 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.connecting)
              _connectingVisual(diameter)
            else if (active)
              _speakerVisual(diameter)
            else
              _quietVisual(diameter),
            SizedBox(height: widget.compact ? 6 : 12),
            Text(
              widget.connecting
                  ? 'Preparing microphone'
                  : widget.riders == 0
                      ? 'Waiting for riders'
                      : active
                          ? widget.activeSpeakerName!
                          : 'Room is quiet',
              style: RL.roomBody.copyWith(
                fontSize: widget.compact ? 14 : 15,
                color: active ? RL.cyanBright : RL.roomTextMid,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!widget.compact) ...[
              const SizedBox(height: 4),
              Text(
                widget.connecting
                    ? 'Syncing your audio state'
                    : widget.riders == 0
                        ? 'Share the room name to invite your group'
                        : active
                            ? 'Speaking now'
                            : 'Voice connection ready',
                style: RL.roomCaption,
                textAlign: TextAlign.center,
              ),
            ],
            if (widget.weakConnection) ...[
              SizedBox(height: widget.compact ? 6 : 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: RL.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: RL.amber.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.signal_cellular_alt_1_bar_rounded,
                      color: RL.amber,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Weak connection',
                      style: RL.roomCaption.copyWith(color: RL.amber),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quietVisual(double diameter) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = Curves.easeOut.transform(_pulse.value);
        return SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.72 + t * 0.28,
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: RL.cyan.withValues(alpha: 0.12 * (1 - t)),
                    ),
                  ),
                ),
              ),
              Container(
                width: diameter * 0.68,
                height: diameter * 0.68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      RL.roomSurfaceRaised.withValues(alpha: 0.92),
                      RL.roomSurface.withValues(alpha: 0.28),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.multitrack_audio_rounded,
                  color: RL.roomTextLow,
                  size: widget.compact ? 24 : 34,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _speakerVisual(double diameter) {
    final name = widget.activeSpeakerName!;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        return SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.94 + _pulse.value * 0.08,
                child: Container(
                  width: diameter * 0.78,
                  height: diameter * 0.78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: RL.cyan.withValues(
                        alpha: 0.22 * (1 - _pulse.value),
                      ),
                      width: 3,
                    ),
                  ),
                ),
              ),
              Container(
                width: diameter * 0.58,
                height: diameter * 0.58,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [RL.cyanBright, RL.cyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: RL.roomBgDeep,
                    fontSize: widget.compact ? 22 : 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: _AmbientWaveform(
                  animation: _pulse,
                  level: widget.activeSpeakerLevel,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _connectingVisual(double diameter) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: diameter * 0.72,
            height: diameter * 0.72,
            child: const CircularProgressIndicator(
              color: RL.cyan,
              strokeWidth: 2.5,
              backgroundColor: RL.roomBorder,
            ),
          ),
          Icon(
            Icons.mic_none_rounded,
            color: RL.roomTextMid,
            size: widget.compact ? 23 : 30,
          ),
        ],
      ),
    );
  }
}

class _AmbientWaveform extends StatelessWidget {
  final Animation<double> animation;
  final double level;

  const _AmbientWaveform({required this.animation, required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(7, (index) {
        final phase = (animation.value + index * 0.13) % 1.0;
        final wave = 1 - (phase * 2 - 1).abs();
        final amplitude = level > 0.02 ? level.clamp(0.25, 1.0) : 0.55;
        return Container(
          width: 3,
          height: 5 + wave * amplitude * 16,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: RL.cyanBright,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _CommunicationPanel extends StatelessWidget {
  final VoiceMode mode;
  final bool micOn;
  final bool pttPressed;
  final bool micBusy;
  final bool disconnecting;
  final double pttDiameter;
  final ValueChanged<VoiceMode> onModeChanged;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final VoidCallback onMicTap;

  const _CommunicationPanel({
    required this.mode,
    required this.micOn,
    required this.pttPressed,
    required this.micBusy,
    required this.disconnecting,
    required this.pttDiameter,
    required this.onModeChanged,
    required this.onPressStart,
    required this.onPressEnd,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    final holdMode = mode == VoiceMode.pushToTalk;
    final live = holdMode ? pttPressed : micOn;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          16,
          pttDiameter < 140 ? 12 : 16,
          16,
          pttDiameter < 140 ? 12 : 18,
        ),
        decoration: BoxDecoration(
          color: RL.roomSurface.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(RL.roomRadius),
          ),
          border: Border(
            top: BorderSide(
              color: RL.roomBorder.withValues(alpha: 0.75),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModeSwitch<VoiceMode>(
              selected: mode,
              enabled: !micBusy && !disconnecting,
              onChanged: onModeChanged,
              options: const [
                (VoiceMode.pushToTalk, 'Hold to Talk'),
                (VoiceMode.openMic, 'Open Mic'),
              ],
            ),
            SizedBox(height: pttDiameter < 140 ? 10 : 14),
            PttButton(
              holdMode: holdMode,
              live: live,
              busy: micBusy,
              connected: !disconnecting,
              diameter: pttDiameter,
              onPressStart: onPressStart,
              onPressEnd: onPressEnd,
              onTap: onMicTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  final String roomName;
  final int riders;
  final bool disconnecting;
  final VoidCallback onEnd;

  const _RoomHeader({
    required this.roomName,
    required this.riders,
    required this.disconnecting,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: RL.roomSurface.withValues(alpha: 0.84),
        border: Border(
          bottom: BorderSide(
            color: RL.roomBorder.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  style: RL.roomTitle,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: RL.cyan,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: RL.cyan, blurRadius: 7),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      disconnecting ? 'Ending call…' : 'Live',
                      style: RL.roomCaption.copyWith(
                        color: disconnecting ? RL.roomTextMid : RL.cyan,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: RL.roomTextLow,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        '$riders ${riders == 1 ? 'rider' : 'riders'}',
                        style: RL.roomCaption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            enabled: !disconnecting,
            label: 'End call',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: disconnecting ? null : onEnd,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: RL.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: RL.red.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (disconnecting)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RL.red,
                          ),
                        )
                      else
                        const Icon(
                          Icons.call_end_rounded,
                          color: RL.red,
                          size: 20,
                        ),
                      const SizedBox(width: 7),
                      Text(
                        'End',
                        style: RL.roomCaption.copyWith(
                          color: RL.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

    final String status;
    if (isSpeaking) {
      status = 'Speaking';
    } else if (isMuted) {
      status = 'Mic muted';
    } else {
      status = 'Mic on';
    }

    final connection = switch (bars) {
      >= 4 => 'Excellent',
      3 => 'Good',
      2 => 'Weak',
      1 => 'Connecting',
      _ => 'Offline',
    };

    return Semantics(
      container: true,
      label: '$name, $status, $connection connection',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSpeaking
                ? const [Color(0xFF173338), Color(0xFF13262F)]
                : const [Color(0xFF172735), Color(0xFF14232F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(RL.roomRadiusSm),
          border: Border.all(
            color: isSpeaking
                ? RL.cyan.withValues(alpha: 0.45)
                : RL.roomBorder.withValues(alpha: 0.65),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSpeaking ? RL.cyan : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSpeaking
                          ? [
                              BoxShadow(
                                color: RL.cyan.withValues(alpha: 0.22),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isSpeaking
                              ? const [RL.cyanBright, RL.cyan]
                              : const [
                                  Color(0xFF263B4A),
                                  Color(0xFF1B2B38),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isSpeaking ? RL.roomBgDeep : RL.roomText,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: isMuted ? RL.roomTextLow : RL.cyan,
                        shape: BoxShape.circle,
                        border: Border.all(color: RL.roomSurface, width: 2),
                      ),
                      child: Icon(
                        isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        size: 9,
                        color: RL.roomBgDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: RL.roomBody.copyWith(
                            color: RL.roomText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLocal) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: RL.cyanDim,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'You',
                            style: RL.roomCaption.copyWith(
                              color: RL.cyanBright,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        size: 14,
                        color: isSpeaking ? RL.cyan : RL.roomTextLow,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          status,
                          style: RL.roomCaption.copyWith(
                            color: isSpeaking ? RL.cyan : RL.roomTextMid,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            VoiceMeter(active: isSpeaking, level: level, color: RL.cyan),
            const SizedBox(width: 9),
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SignalBars(bars: bars),
                  const SizedBox(height: 6),
                  Text(
                    connection,
                    style: RL.roomCaption.copyWith(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
