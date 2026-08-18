// RideLink — design tokens at ThemeData.
//
// Direksyon: "moto HUD" — parang instrument cluster ng motor, hindi
// parang chat app. Halos itim na background, isang matingkad na berde
// bilang signal color, at monospace para sa mga readout/label.
//
// Panuntunan sa kulay:
//   berde  = maayos, live, konektado
//   pula   = on air (naririnig ka), o disconnect
//   amber  = babala / mahina ang signal
// Wag gagamitin ang berde para sa dekorasyon lang — dapat may ibig
// sabihin ito tuwing lalabas.

import 'package:flutter/material.dart';

class RL {
  RL._();

  // --- Surfaces ------------------------------------------------------
  static const bg = Color(0xFF06080A); // pinakailalim
  static const surface = Color(0xFF0E1214); // cards, fields
  static const surfaceAlt = Color(0xFF141A1D); // nakataas na card
  static const line = Color(0xFF1E2629); // hairline border
  static const lineBright = Color(0xFF2C3639); // border ng aktibong item

  // --- Signal --------------------------------------------------------
  static const green = Color(0xFF2BE08A);
  static const greenDim = Color(0xFF0F3B27); // fill sa likod ng berde
  static const amber = Color(0xFFFFB627);
  static const amberDim = Color(0xFF3A2A08);
  static const red = Color(0xFFFF3B47);
  static const redDim = Color(0xFF3A0F14);

  // --- Text ----------------------------------------------------------
  static const textHi = Color(0xFFE8EDEF);
  static const textMid = Color(0xFF8A9599);
  static const textLow = Color(0xFF4E585C);

  // --- Spacing / radius ----------------------------------------------
  static const r = 10.0; // pangkaraniwang radius — matigas, hindi bilog
  static const rSm = 6.0;

  // --- Type ----------------------------------------------------------
  // Ang monospace ang nagbibigay ng "instrument readout" na dating.
  // Generic family ito kaya laging may katumbas sa Android/iOS/web.
  static const mono = 'monospace';

  /// Maliit na uppercase na label — para sa field labels at status chips.
  static const label = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.8,
    color: textMid,
    height: 1.2,
  );

  /// Readout ng datos (room name, counters).
  static const readout = TextStyle(
    fontFamily: mono,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: textHi,
  );

  /// Pangalan ng rider sa participant list.
  static const rider = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
    color: textHi,
  );

  /// Malaking wordmark.
  static const wordmark = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    letterSpacing: 7,
    color: textHi,
    height: 1.0,
  );

  /// Teksto sa loob ng malalaking button.
  static const action = TextStyle(
    fontFamily: mono,
    fontSize: 17,
    fontWeight: FontWeight.w900,
    letterSpacing: 3,
  );

  static ThemeData theme() {
    const scheme = ColorScheme.dark(
      primary: green,
      onPrimary: Color(0xFF04140C),
      secondary: amber,
      surface: surface,
      onSurface: textHi,
      error: red,
      onError: Colors.white,
      outline: line,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      splashFactory: NoSplash.splashFactory, // walang ripple — mas HUD
      highlightColor: Colors.transparent,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: green,
        selectionColor: greenDim,
        selectionHandleColor: green,
      ),
    );
  }
}

/// Kulay ng signal ayon sa lakas: 0 = wala, 3 = malakas.
Color signalColor(int bars) {
  if (bars >= 3) return RL.green;
  if (bars == 2) return RL.amber;
  return RL.red;
}
