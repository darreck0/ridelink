// RideLink — mga reusable na HUD widget.
//
// Ang lahat dito ay purong presentation. Walang alam ang mga ito sa
// LiveKit — datos lang ang tinatanggap nila para madali silang
// i-preview at baguhin nang hindi ginagalaw ang voice logic.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// CORNER BRACKETS — ang pirma ng buong disenyo.
// Sa halip na buong border, apat na sulok lang ang ginuguhitan. Ito ang
// nagbibigay ng "targeting reticle" na dating ng instrument panel.
// ---------------------------------------------------------------------------

class _BracketPainter extends CustomPainter {
  final Color color;
  final double len; // haba ng bawat braso ng sulok

  _BracketPainter({required this.color, this.len = 14});

  static const stroke = 1.5;
  static const radius = RL.r;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final w = size.width, h = size.height, r = radius;

    // Bawat sulok: pahalang na braso, arc, pababang braso.
    void corner(double cx, double cy, int sx, int sy) {
      final path = Path()
        ..moveTo(cx + sx * (r + len), cy)
        ..lineTo(cx + sx * r, cy)
        ..arcToPoint(
          Offset(cx, cy + sy * r),
          radius: Radius.circular(r),
          clockwise: sx * sy < 0,
        )
        ..lineTo(cx, cy + sy * (r + len));
      canvas.drawPath(path, p);
    }

    corner(0, 0, 1, 1); // kaliwa-taas
    corner(w, 0, -1, 1); // kanan-taas
    corner(0, h, 1, -1); // kaliwa-baba
    corner(w, h, -1, -1); // kanan-baba
  }

  @override
  bool shouldRepaint(_BracketPainter old) =>
      old.color != color || old.len != len;
}

/// Kahon na may corner brackets sa halip na buong border.
class HudPanel extends StatelessWidget {
  final Widget child;
  final Color? bracketColor;
  final Color? fill;
  final EdgeInsets padding;
  final double bracketLen;

  const HudPanel({
    super.key,
    required this.child,
    this.bracketColor,
    this.fill,
    this.padding = const EdgeInsets.all(16),
    this.bracketLen = 14,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BracketPainter(
        color: bracketColor ?? RL.lineBright,
        len: bracketLen,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: fill ?? RL.surface,
          borderRadius: BorderRadius.circular(RL.r),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LABEL — maliit na uppercase na heading na may guhit sa gilid.
// ---------------------------------------------------------------------------

class HudLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const HudLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? RL.textMid;
    return Row(
      children: [
        Container(width: 3, height: 11, color: c),
        const SizedBox(width: 8),
        Text(text.toUpperCase(), style: RL.label.copyWith(color: c)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: RL.line)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// STATUS CHIP — tuldok + teksto, para sa live/offline/quality readouts.
// ---------------------------------------------------------------------------

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool pulse;

  const StatusChip({
    super.key,
    required this.text,
    required this.color,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(RL.rSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: color, pulse: pulse),
          const SizedBox(width: 7),
          Text(
            text.toUpperCase(),
            style: RL.label.copyWith(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _Dot({required this.color, required this.pulse});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.pulse && _c.isAnimating) {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = widget.pulse ? 0.35 + 0.65 * _c.value : 1.0;
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: t),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// SIGNAL BARS — apat na patayong bar, parang cell signal.
// ---------------------------------------------------------------------------

class SignalBars extends StatelessWidget {
  final int bars; // 0..4
  const SignalBars({super.key, required this.bars});

  @override
  Widget build(BuildContext context) {
    final c = signalColor(bars);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final on = i < bars;
        return Container(
          margin: const EdgeInsets.only(left: 2.5),
          width: 3.5,
          height: 6.0 + i * 4,
          decoration: BoxDecoration(
            color: on ? c : RL.line,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// VOICE METER — mga bar na tumataas kapag may boses. Ipinapakita lang
// kapag nagsasalita ang rider, kaya ito ang unang nahuhuli ng mata.
// ---------------------------------------------------------------------------

class VoiceMeter extends StatefulWidget {
  final bool active;
  final double level; // 0..1
  final Color color;
  const VoiceMeter({
    super.key,
    required this.active,
    this.level = 0,
    this.color = RL.green,
  });

  @override
  State<VoiceMeter> createState() => _VoiceMeterState();
}

class _VoiceMeterState extends State<VoiceMeter>
    with SingleTickerProviderStateMixin {
  static const _bars = 5;
  static const _barW = 3.0;
  static const _gap = 3.0;
  static const _width = _bars * (_barW + _gap);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Walang ipinapakita kapag tahimik — ang meter lang ang dapat
    // humuli ng mata, kaya wala dapat itong iniiwang bakas. Nakalaan pa
    // rin ang lapad para hindi tumalon ang layout paglabas nito.
    if (!widget.active) return const SizedBox(width: _width);

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_bars, (i) {
            // Bawat bar ay may sariling phase para hindi sabay-sabay.
            final phase = (_c.value + i * 0.17) % 1.0;
            final wave = math.sin(phase * math.pi * 2).abs();
            final amp =
                widget.level > 0.02 ? widget.level.clamp(0.15, 1.0) : 0.55;
            final h = 4 + wave * amp * 18;
            return Container(
              margin: const EdgeInsets.only(left: _gap),
              width: _barW,
              height: h,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// TEXT FIELD
// ---------------------------------------------------------------------------

class HudField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextCapitalization capitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const HudField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.capitalization = TextCapitalization.none,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  State<HudField> createState() => _HudFieldState();
}

class _HudFieldState extends State<HudField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _focus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: RL.roomCaption.copyWith(
            color: active ? RL.cyanBright : RL.roomTextMid,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: RL.roomBgDeep.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(RL.roomRadiusSm),
            border: Border.all(
              color: active
                  ? RL.cyan.withValues(alpha: 0.78)
                  : RL.roomBorder.withValues(alpha: 0.75),
              width: active ? 1.4 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: RL.cyan.withValues(alpha: 0.08),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            textCapitalization: widget.capitalization,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            style: RL.roomBody.copyWith(
              color: RL.roomText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: RL.roomBody.copyWith(color: RL.roomTextLow),
              prefixIcon: widget.icon == null
                  ? null
                  : Icon(
                      widget.icon,
                      color: active ? RL.cyan : RL.roomTextLow,
                      size: 20,
                    ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 52,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PRIMARY BUTTON
// ---------------------------------------------------------------------------

class HudButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  const HudButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final foreground = enabled ? RL.roomBgDeep : RL.roomTextLow;
    return Semantics(
      button: true,
      enabled: enabled,
      label: busy ? 'Joining voice room' : label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 58,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [RL.cyanBright, RL.cyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : RL.roomSurfaceRaised,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color:
                enabled ? RL.cyanBright.withValues(alpha: 0.45) : RL.roomBorder,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: RL.cyan.withValues(alpha: 0.24),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(15),
            child: Center(
              child: busy
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: RL.roomTextMid,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Text(
                          'Joining room…',
                          style: RL.roomBody.copyWith(
                            color: RL.roomTextMid,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: RL.roomBody.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: 10),
                          Icon(icon, size: 21, color: foreground),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MODE SWITCH — sariling segmented control (hindi Material) para tumugma
// sa matigas na hugis ng natitirang UI.
// ---------------------------------------------------------------------------

class ModeSwitch<T> extends StatelessWidget {
  final List<(T value, String label)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool enabled;

  const ModeSwitch({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: RL.roomBgDeep.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RL.roomBorder.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: options.map((o) {
          final on = o.$1 == selected;
          return Expanded(
            child: Semantics(
              button: true,
              selected: on,
              enabled: enabled,
              label: o.$2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled ? () => onChanged(o.$1) : null,
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: on
                          ? const LinearGradient(
                              colors: [Color(0xFF174A48), Color(0xFF123936)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: on
                            ? RL.cyan.withValues(alpha: 0.6)
                            : Colors.transparent,
                      ),
                      boxShadow: on
                          ? [
                              BoxShadow(
                                color: RL.cyan.withValues(alpha: 0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        o.$2,
                        style: RL.roomBody.copyWith(
                          fontSize: 13,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                          color: on ? RL.cyanBright : RL.roomTextMid,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PTT BUTTON — malaking bilog na may tach-style na tick ring.
// Ang ring ang nagsasabi ng estado kahit sulyap lang: patay na kulay abo
// kapag tahimik, buong pula kapag naririnig ka.
// ---------------------------------------------------------------------------

class _PttHaloPainter extends CustomPainter {
  final Color color;
  final double pulse;
  final bool active;

  _PttHaloPainter({
    required this.color,
    required this.pulse,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 5;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = (active ? color : RL.roomBorder)
            .withValues(alpha: active ? 0.28 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (active) {
      canvas.drawCircle(
        center,
        radius + 2 + pulse * 5,
        Paint()
          ..color = color.withValues(alpha: 0.16 * (1 - pulse))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
    }
  }

  @override
  bool shouldRepaint(_PttHaloPainter old) =>
      old.color != color || old.pulse != pulse || old.active != active;
}

class PttButton extends StatefulWidget {
  final bool live;
  final bool holdMode;
  final bool busy;
  final bool connected;
  final double diameter;

  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final VoidCallback? onTap;

  const PttButton({
    super.key,
    required this.live,
    required this.holdMode,
    this.busy = false,
    this.connected = true,
    this.diameter = 154,
    this.onPressStart,
    this.onPressEnd,
    this.onTap,
  });

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.live) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PttButton old) {
    super.didUpdateWidget(old);
    if (widget.live && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.live && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.connected && !widget.busy;
    final gestureEnabled =
        widget.connected && (widget.holdMode || !widget.busy);
    final ready = enabled && widget.holdMode && !widget.live;
    final accent = widget.live
        ? RL.cyanBright
        : ready
            ? RL.cyan
            : RL.roomTextLow;
    final String title;
    final String helper;
    final IconData icon;

    if (!widget.connected) {
      title = 'Disconnected';
      helper = 'Return to the room to reconnect';
      icon = Icons.link_off_rounded;
    } else if (widget.busy) {
      title = 'Connecting mic';
      helper = 'One moment';
      icon = Icons.sync_rounded;
    } else if (widget.live) {
      title = widget.holdMode ? 'Transmitting' : 'Mic is live';
      helper = widget.holdMode ? 'Release to stop' : 'Tap to mute';
      icon = Icons.mic_rounded;
    } else if (widget.holdMode) {
      title = 'Hold to talk';
      helper = 'Press and hold';
      icon = Icons.mic_none_rounded;
    } else {
      title = 'Muted';
      helper = 'Tap to unmute';
      icon = Icons.mic_off_rounded;
    }

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: widget.live,
      label: title,
      hint: helper,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: gestureEnabled && widget.holdMode
            ? (_) {
                setState(() => _pressed = true);
                widget.onPressStart?.call();
              }
            : gestureEnabled
                ? (_) => setState(() => _pressed = true)
                : null,
        onTapUp: gestureEnabled
            ? (_) {
                setState(() => _pressed = false);
                if (widget.holdMode) widget.onPressEnd?.call();
              }
            : null,
        onTapCancel: gestureEnabled
            ? () {
                setState(() => _pressed = false);
                if (widget.holdMode) widget.onPressEnd?.call();
              }
            : null,
        onTap: gestureEnabled && !widget.holdMode ? widget.onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final pulse = widget.live ? _c.value : 0.0;
                return SizedBox(
                  width: widget.diameter,
                  height: widget.diameter,
                  child: CustomPaint(
                    painter: _PttHaloPainter(
                      color: accent,
                      pulse: pulse,
                      active: widget.live,
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOut,
                        width: widget.diameter - (_pressed ? 28 : 22),
                        height: widget.diameter - (_pressed ? 28 : 22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: widget.live
                                ? const [
                                    Color(0xFF237E70),
                                    Color(0xFF14544D),
                                  ]
                                : ready
                                    ? const [
                                        Color(0xFF16413F),
                                        Color(0xFF112E32),
                                      ]
                                    : const [
                                        Color(0xFF1A252E),
                                        Color(0xFF131C24),
                                      ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: widget.live
                                ? accent.withValues(alpha: 0.95)
                                : ready
                                    ? RL.cyan.withValues(alpha: 0.42)
                                    : RL.roomBorder,
                            width: widget.live ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.live
                                  ? accent.withValues(alpha: 0.28)
                                  : Colors.black.withValues(alpha: 0.25),
                              blurRadius: widget.live ? 30 : 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: widget.diameter < 140 ? 28 : 32,
                                color: widget.live || ready
                                    ? accent
                                    : RL.roomTextMid,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                title,
                                style: RL.roomBody.copyWith(
                                  fontSize: widget.diameter < 140 ? 14 : 16,
                                  fontWeight: FontWeight.w700,
                                  color: widget.live || ready
                                      ? accent
                                      : RL.roomText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(helper, style: RL.roomCaption),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ALERT — para sa error messages.
// ---------------------------------------------------------------------------

class HudAlert extends StatelessWidget {
  final String message;
  const HudAlert(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RL.red.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: RL.red.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: RL.red.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: RL.red,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Couldn’t connect',
                  style: RL.roomBody.copyWith(
                    color: const Color(0xFFFFA8AE),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: RL.roomCaption.copyWith(
                    color: const Color(0xFFFFCDD0),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
