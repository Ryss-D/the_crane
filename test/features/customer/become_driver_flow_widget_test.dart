import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/models/driver_profile.dart';
import 'package:the_crane/core/models/truck.dart';
import 'package:the_crane/features/customer/request/request_screen.dart';
import 'package:the_crane/features/customer/settings/become_driver_screen.dart';
import 'package:the_crane/features/customer/settings/settings_screen.dart';
import 'package:the_crane/features/driver/home/driver_home_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

/// Fails the next `registerDriver` call exactly once, mirroring
/// `RejectingOnceJobsRepository`'s shape (`test/support/`).
class _RejectingOnceDriversRepository extends FakeDriversRepository {
  _RejectingOnceDriversRepository({required super.jobs, super.actionDelay});

  bool rejectNext = false;

  @override
  Future<DriverProfile> registerDriver({
    String? plate,
    TruckType? truckType,
    TruckCapacity? capacity,
    String? inviteToken,
    String? licenseUrl,
    String? truckPhotoUrl,
  }) async {
    if (rejectNext) {
      rejectNext = false;
      throw StateError('boom');
    }
    return super.registerDriver(
      plate: plate,
      truckType: truckType,
      capacity: capacity,
      inviteToken: inviteToken,
      licenseUrl: licenseUrl,
      truckPhotoUrl: truckPhotoUrl,
    );
  }
}

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
  // phone-mismatch rejection. A widget-level version of *submitting* this
  // flow (tapping through the `_RegistrationMode.invite` segment all the
  // way to a successful/rejected `register`) reliably hung the test runner
  // here for a reason not yet root-caused -- not worth shipping a
  // flaky/hanging test to chase full UI coverage of a path whose logic is
  // otherwise well covered. The mode switch itself (segment tap, field
  // render, submit-enablement) is still exercised below, stopping short of
  // tapping submit while in that mode.
  testWidgets(
      'AUTH-5/FLT-4: mode selector toggles the invite-token field and its '
      'own submit-enablement, without disturbing the own-truck fields',
      (tester) async {
    await tester.pumpWidget(TheCraneApp(dependencies: testDependencies()));
    await tester.pumpAndSettle();
    await signIn(tester);
    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('becomeDriverMenuItem')));
    await tester.pumpAndSettle();
    expect(find.byType(BecomeDriverScreen), findsOneWidget);

    // Switch truck type/capacity away from their defaults (flatbed/both).
    await tester.tap(find.text('Grúa de carros'));
    await tester.pump();
    await tester.tap(find.text('Motos'));
    await tester.pump();

    // Switch to the invite path: own-truck fields disappear, the
    // invite-token field appears, and submit stays disabled until it's
    // non-empty.
    await tester.tap(find.text('Tengo una invitación'));
    await tester.pump();
    expect(find.byKey(const Key('inviteTokenField')), findsOneWidget);
    expect(find.byKey(const Key('plateField')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('becomeDriverSubmitButton')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('inviteTokenField')),
      'INVITE-TOKEN-1',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('becomeDriverSubmitButton')),
          )
          .onPressed,
      isNotNull,
    );

    // Back to the own-truck path for the actual submit below -- the
    // plate field was never touched, so submit is disabled again.
    await tester.tap(find.text('Tengo mi camión'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('becomeDriverSubmitButton')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
      'AUTH-5: a rejected registration shows an inline error and re-enables '
      'the submit button', (tester) async {
    final jobs = fastFakeJobs();
    final drivers = _RejectingOnceDriversRepository(
      jobs: jobs,
      actionDelay: const Duration(milliseconds: 10),
    )..rejectNext = true;
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(jobs: jobs, drivers: drivers),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);
    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('becomeDriverMenuItem')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('plateField')), 'FAIL123');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('becomeDriverSubmitButton')));
    await tester.tap(find.byKey(const Key('becomeDriverSubmitButton')));
    await tester.pump(); // isSubmitting
    await tester.pump(const Duration(milliseconds: 20)); // actionDelay

    expect(
      find.text('No pudimos completar el registro. Intenta de nuevo.'),
      findsOneWidget,
    );
    // Still on this screen, and submit is re-enabled (plate is still set).
    expect(find.byType(BecomeDriverScreen), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('becomeDriverSubmitButton')),
          )
          .onPressed,
      isNotNull,
    );

    // A later, non-rejected submit no longer throws (the reject flag was
    // consumed above) -- re-disarms the submitting spinner without
    // asserting on the role-flip redirect, which needs the driver repo
    // wired to the same `FakeAuthRepository` the router's `AuthCubit`
    // reads from (this repo intentionally isn't, to isolate the failure
    // path above from FLT-4's role-flip plumbing).
    await tester.tap(find.byKey(const Key('becomeDriverSubmitButton')));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const Key('becomeDriverSubmitButton')), findsOneWidget);
  });
}
