import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/features/fleet/home/fleet_home_screen.dart';
import 'package:the_crane/features/fleet/invite_driver/invite_driver_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

void main() {
  Future<void> pumpToFleetHome(WidgetTester tester) async {
    await tester.pumpWidget(
      TheCraneApp(dependencies: testDependencies(authRole: UserRole.fleetOwner)),
    );
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(FleetHomeScreen), findsOneWidget);
  }

  testWidgets('FLT-4: sends a driver invite and shows it pending',
      (tester) async {
    await pumpToFleetHome(tester);

    await tester.tap(find.byKey(const Key('inviteDriverNavButton')));
    await tester.pumpAndSettle();
    expect(find.byType(InviteDriverScreen), findsOneWidget);

    // No pending invites yet.
    expect(find.byKey(const Key('inviteSendButton')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('invitePhoneField')),
      '+573001112233',
    );
    await tester.enterText(
      find.byKey(const Key('invitePlateField')),
      'INV001',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('inviteSendButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('+573001112233'), findsOneWidget);
  });

  testWidgets('FLT-4: shows an error for a duplicate pending phone invite',
      (tester) async {
    await pumpToFleetHome(tester);

    await tester.tap(find.byKey(const Key('inviteDriverNavButton')));
    await tester.pumpAndSettle();

    Future<void> sendInvite(String plate) async {
      await tester.enterText(
        find.byKey(const Key('invitePhoneField')),
        '+573001112233',
      );
      await tester.enterText(find.byKey(const Key('invitePlateField')), plate);
      await tester.pump();
      await tester.tap(find.byKey(const Key('inviteSendButton')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    }

    await sendInvite('INV001');
    await sendInvite('INV002');

    expect(find.byKey(const Key('inviteSendButton')), findsOneWidget);
    // The second attempt fails (same pending phone) -- an error is shown
    // rather than a second pending row appearing. Scoped to the pending-
    // invites card: the phone field itself still holds the same text after
    // the failed retry, so a bare `find.text` would double-count it.
    expect(
      find.descendant(
        of: find.byType(Card),
        matching: find.text('+573001112233'),
      ),
      findsOneWidget,
    );
  });
}
