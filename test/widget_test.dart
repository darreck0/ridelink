// Smoke test para sa connect screen.
//
// Hindi ito tumatawag sa LiveKit — pinapatunayan lang nito na nabubuo
// ang UI at nandiyan ang mga kontrol na kailangan bago kumonekta.

import 'package:flutter/material.dart' show MaterialApp, Scaffold, TextField;
import 'package:flutter_test/flutter_test.dart';

import 'package:ridelink_mobile/main.dart';
import 'package:ridelink_mobile/widgets.dart';

void main() {
  testWidgets('nabubuo ang connect screen kasama ang mga kontrol nito',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RideLinkApp());

    expect(find.text('RideLink'), findsOneWidget);

    // Tatlong field: sandbox, room, callsign.
    expect(find.byType(HudField), findsNWidgets(3));
    expect(find.text('LiveKit sandbox'), findsOneWidget);
    expect(find.text('Room name'), findsOneWidget);
    expect(find.text('Your callsign'), findsOneWidget);

    expect(find.text('Join voice room'), findsOneWidget);
  });

  testWidgets('may error kapag walang Sandbox ID', (WidgetTester tester) async {
    // Walang --dart-define sa test, kaya blangko ang sandbox field.
    await tester.pumpWidget(const RideLinkApp());

    await tester.ensureVisible(find.text('Join voice room'));
    await tester.tap(find.text('Join voice room'));
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
    await tester.ensureVisible(find.text('Join voice room'));
    await tester.tap(find.text('Join voice room'));
    await tester.pump();

    expect(find.byType(HudAlert), findsOneWidget);
    expect(find.text('Ilagay muna ang pangalan mo.'), findsOneWidget);
  });

  testWidgets('ipinapakita ng PTT control ang mahahalagang voice states',
      (WidgetTester tester) async {
    Future<void> pumpPtt({
      required bool live,
      required bool holdMode,
      bool busy = false,
      bool connected = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PttButton(
              live: live,
              holdMode: holdMode,
              busy: busy,
              connected: connected,
            ),
          ),
        ),
      );
    }

    await pumpPtt(live: false, holdMode: true);
    expect(find.text('Hold to talk'), findsOneWidget);

    await pumpPtt(live: true, holdMode: true);
    expect(find.text('Transmitting'), findsOneWidget);

    await pumpPtt(live: false, holdMode: false);
    expect(find.text('Muted'), findsOneWidget);

    await pumpPtt(live: false, holdMode: false, busy: true);
    expect(find.text('Connecting mic'), findsOneWidget);

    await pumpPtt(live: false, holdMode: false, connected: false);
    expect(find.text('Disconnected'), findsOneWidget);
  });
}
