// Smoke test para sa connect screen.
//
// Hindi ito tumatawag sa LiveKit — pinapatunayan lang nito na nabubuo
// ang UI at nandiyan ang mga kontrol na kailangan bago kumonekta.

import 'package:flutter/material.dart' show TextField;
import 'package:flutter_test/flutter_test.dart';

import 'package:ridelink_mobile/main.dart';
import 'package:ridelink_mobile/widgets.dart';

void main() {
  testWidgets('nabubuo ang connect screen kasama ang mga kontrol nito',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RideLinkApp());

    expect(find.text('RIDELINK'), findsOneWidget);

    // Tatlong field: sandbox, room, callsign.
    expect(find.byType(HudField), findsNWidgets(3));
    expect(find.text('SANDBOX ID'), findsOneWidget);
    expect(find.text('ROOM'), findsOneWidget);
    expect(find.text('CALLSIGN'), findsOneWidget);

    expect(find.text('CONNECT'), findsOneWidget);
  });

  testWidgets('may error kapag walang Sandbox ID', (WidgetTester tester) async {
    // Walang --dart-define sa test, kaya blangko ang sandbox field.
    await tester.pumpWidget(const RideLinkApp());

    await tester.tap(find.text('CONNECT'));
    await tester.pump();

    expect(find.byType(HudAlert), findsOneWidget);
    expect(
      find.text('Ilagay ang Sandbox ID mula sa LiveKit dashboard mo.'),
      findsOneWidget,
    );
  });

  testWidgets('may error kapag walang callsign', (WidgetTester tester) async {
    await tester.pumpWidget(const RideLinkApp());

    // Punan muna ang sandbox para makarating sa susunod na check.
    await tester.enterText(find.byType(TextField).first, 'test-sandbox');
    await tester.tap(find.text('CONNECT'));
    await tester.pump();

    expect(find.byType(HudAlert), findsOneWidget);
    expect(find.text('Ilagay muna ang pangalan mo.'), findsOneWidget);
  });
}
