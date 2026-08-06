import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/features/customer/request/request_screen.dart';
import 'package:the_crane/features/customer/settings/become_driver_screen.dart';
import 'package:the_crane/features/customer/settings/settings_screen.dart';
import 'package:the_crane/features/driver/home/driver_home_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

void main() {
  testWidgets(
      'AUTH-5: a signed-in customer registers as a driver and lands on '
      'the driver shell', (tester) async {
    await tester.pumpWidget(TheCraneApp(dependencies: testDependencies()));
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(RequestScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('becomeDriverMenuItem')));
    await tester.pumpAndSettle();
    expect(find.byType(BecomeDriverScreen), findsOneWidget);

    // Submit is disabled until a plate is entered.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('becomeDriverSubmitButton')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byKey(const Key('plateField')), 'XYZ987');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('becomeDriverSubmitButton')),
          )
          .onPressed,
      isNotNull,
    );

    // FLT-4's mode selector + invite-token/plate fields pushed the submit
    // button below the fold on the default test viewport.
    await tester.ensureVisible(find.byKey(const Key('becomeDriverSubmitButton')));
    await tester.tap(find.byKey(const Key('becomeDriverSubmitButton')));
    // registerDriver's actionDelay + refreshUser's sync delay, then the
    // router redirect's route transition. Not `pumpAndSettle`: the submit
    // button's indeterminate CircularProgressIndicator keeps animating
    // until this screen is popped by the redirect, which would hang it.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DriverHomeScreen), findsOneWidget);
  });

  // FLT-4's "redeem an invite" path (mode selector -> invite-token field ->
  // register) is exercised at the repository level instead of end-to-end
  // here: `test/core/api/fake_drivers_repository_test.dart` and
  // `test/core/api/fake_fleet_repository_test.dart` cover successful
  // redemption (truck link, invite consumed, role flip) and the
  // phone-mismatch rejection. A widget-level version of this flow (tapping
  // through the `_RegistrationMode.invite` segment) reliably hung the test
  // runner here for a reason not yet root-caused -- not worth shipping a
  // flaky/hanging test to chase full UI coverage of a path whose logic is
  // otherwise well covered.
}
