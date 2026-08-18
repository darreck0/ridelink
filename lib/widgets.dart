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
  const VoiceMeter({super.key, required this.active, this.level = 0});

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
                color: RL.green,
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
  final TextCapitalization capitalization;
  final bool enabled;

  const HudField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.capitalization = TextCapitalization.none,
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
        HudLabel(widget.label, color: active ? RL.green : RL.textLow),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: RL.surface,
            borderRadius: BorderRadius.circular(RL.r),
            border: Border.all(
              color: active ? RL.green : RL.line,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Patayong marker sa gilid — nagliliwanag kapag naka-focus.
              Container(
                width: 3,
                height: 26,
                margin: const EdgeInsets.only(left: 12, right: 10),
                decoration: BoxDecoration(
                  color: active ? RL.green : RL.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  textCapitalization: widget.capitalization,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: RL.textHi,
                    letterSpacing: 0.3,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: const TextStyle(color: RL.textLow, fontSize: 16),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
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
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 62,
        decoration: BoxDecoration(
          color: enabled ? RL.green : RL.surfaceAlt,
          borderRadius: BorderRadius.circular(RL.r),
          border: Border.all(
            color: enabled ? RL.green : RL.line,
            width: 1.5,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: RL.green.withValues(alpha: 0.28),
                    blurRadius: 26,
                    spreadRadius: -6,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: busy
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(RL.textMid),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'CONNECTING',
                      style: RL.action.copyWith(
                        color: RL.textMid,
                        fontSize: 15,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 21,
                        color: enabled
                            ? const Color(0xFF04140C)
                            : RL.textLow,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      label,
                      style: RL.action.copyWith(
                        color:
                            enabled ? const Color(0xFF04140C) : RL.textLow,
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
// MODE SWITCH — sariling segmented control (hindi Material) para tumugma
// sa matigas na hugis ng natitirang UI.
// ---------------------------------------------------------------------------

class ModeSwitch<T> extends StatelessWidget {
  final List<(T value, String label)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const ModeSwitch({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: RL.surface,
        borderRadius: BorderRadius.circular(RL.r),
        border: Border.all(color: RL.line),
      ),
      child: Row(
        children: options.map((o) {
          final on = o.$1 == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.$1),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 44,
                decoration: BoxDecoration(
                  color: on ? RL.greenDim : Colors.transparent,
                  borderRadius: BorderRadius.circular(RL.rSm),
                  border: Border.all(
                    color: on ? RL.green : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Text(
                    o.$2,
                    style: RL.label.copyWith(
                      fontSize: 12,
                      color: on ? RL.green : RL.textMid,
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

class _RingPainter extends CustomPainter {
  final double progress; // 0..1 — gaano karaming tick ang bukas
  final Color active;
  final Color idle;
  final double glow;

  _RingPainter({
    required this.progress,
    required this.active,
    required this.idle,
    required this.glow,
  });

  static const _ticks = 44;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width / 2 - 2;
    final rInner = rOuter - 11;

    // Glow sa likod kapag aktibo.
    if (glow > 0) {
      canvas.drawCircle(
        c,
        rOuter * (1 + 0.05 * glow),
        Paint()
          ..color = active.withValues(alpha: 0.16 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    // Ang tick ring. Nagsisimula sa itaas, pakanan.
    for (var i = 0; i < _ticks; i++) {
      final frac = i / _ticks;
      // `progress > 0` muna: kung wala, sana walang kahit isang tick na
      // bukas — kung hindi, sasabit ang tick sa index 0 dahil 0 <= 0.
      final on = progress > 0 && frac <= progress;
      final a = -math.pi / 2 + frac * math.pi * 2;
      final dir = Offset(math.cos(a), math.sin(a));
      // Bawat ikaapat na tick ay mas mahaba — parang gauge markings.
      final long = i % 4 == 0;
      final p1 = c + dir * (long ? rInner - 4 : rInner);
      final p2 = c + dir * rOuter;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = on ? active : idle
          ..strokeWidth = long ? 2.4 : 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.active != active || old.glow != glow;
}

class PttButton extends StatefulWidget {
  /// `true` = bukas ang mic (naririnig ka).
  final bool live;

  /// Push-to-talk: hawakan para magsalita. Kapag `false`, tap toggle.
  final bool holdMode;

  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final VoidCallback? onTap;

  const PttButton({
    super.key,
    required this.live,
    required this.holdMode,
    this.onPressStart,
    this.onPressEnd,
    this.onTap,
  });

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton>
    with SingleTickerProviderStateMixin {
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
    // Pula kapag on air, berde kapag handa, abo kapag naka-mute.
    final Color accent = widget.live
        ? RL.red
        : (widget.holdMode ? RL.green : RL.red);
    final String top = widget.live
        ? 'ON AIR'
        : (widget.holdMode ? 'HOLD' : 'MUTED');
    final String sub = widget.live
        ? (widget.holdMode ? 'bitawan para tumigil' : 'naririnig ka')
        : (widget.holdMode ? 'pindutin at hawakan' : 'pindutin para buksan');

    return GestureDetector(
      onTapDown: widget.holdMode ? (_) => widget.onPressStart?.call() : null,
      onTapUp: widget.holdMode ? (_) => widget.onPressEnd?.call() : null,
      onTapCancel: widget.holdMode ? () => widget.onPressEnd?.call() : null,
      onTap: widget.holdMode ? null : widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final glow = widget.live ? _c.value : 0.0;
              return SizedBox(
                width: 196,
                height: 196,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: widget.live ? 1.0 : 0.0,
                    active: accent,
                    idle: RL.line,
                    glow: glow,
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      width: 152,
                      height: 152,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.live
                            ? accent.withValues(alpha: 0.16)
                            : RL.surface,
                        border: Border.all(
                          color: widget.live ? accent : RL.lineBright,
                          width: widget.live ? 2.5 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.live ? Icons.mic : Icons.mic_off,
                              size: 34,
                              color: widget.live ? accent : RL.textMid,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              top,
                              style: RL.action.copyWith(
                                fontSize: 19,
                                color: widget.live ? accent : RL.textHi,
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
          const SizedBox(height: 14),
          Text(
            sub.toUpperCase(),
            style: RL.label.copyWith(fontSize: 10, color: RL.textLow),
          ),
        ],
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
        color: RL.redDim,
        borderRadius: BorderRadius.circular(RL.r),
        border: Border.all(color: RL.red.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: RL.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HINDI NAKAKONEKTA',
                  style: RL.label.copyWith(color: RL.red, fontSize: 10),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFFFC9CC),
                    fontSize: 13,
                    height: 1.45,
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
