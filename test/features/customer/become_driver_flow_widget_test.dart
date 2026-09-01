import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_fleet_repository.dart';
import 'package:the_crane/core/models/driver_profile.dart';
import 'package:the_crane/core/models/truck.dart';
import 'package:the_crane/core/storage/fake_document_image_picker.dart';
import 'package:the_crane/core/storage/fake_document_upload_repository.dart';
import 'package:the_crane/features/customer/request/request_screen.dart';
import 'package:the_crane/features/customer/settings/become_driver_screen.dart';
import 'package:the_crane/features/customer/settings/settings_screen.dart';
import 'package:the_crane/features/driver/home/driver_home_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

/// Records the `licenseUrl`/`truckPhotoUrl` a `registerDriver` call actually
/// received, so the AUTH-5-follow-up document-upload tests below can assert
/// the real uploaded URL (not a hand-typed one) is what gets sent.
class _CapturingDriversRepository extends FakeDriversRepository {
  _CapturingDriversRepository({required super.jobs, super.actionDelay});

  String? lastLicenseUrl;
  String? lastTruckPhotoUrl;

  @override
  Future<DriverProfile> registerDriver({
    String? plate,
    TruckType? truckType,
    TruckCapacity? capacity,
    String? inviteToken,
    String? licenseUrl,
    String? truckPhotoUrl,
  }) async {
    lastLicenseUrl = licenseUrl;
    lastTruckPhotoUrl = truckPhotoUrl;
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
  // register) is exercised at the repository level too:
  // `test/core/api/fake_drivers_repository_test.dart` and
  // `test/core/api/fake_fleet_repository_test.dart` cover successful
  // redemption (truck link, invite consumed, role flip) and the
  // phone-mismatch rejection. The mode switch itself (segment tap, field
  // render, submit-enablement) is exercised below too, stopping short of
  // tapping submit while in that mode -- the two tests further below
  // (`FLT-4: redeeming a valid invite ...` / `FLT-4: a phone-mismatched
  // invite ...`) cover tapping submit itself.
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

  // FLT-4: driving the invite-mode submit all the way through used to
  // "reliably hang the test runner here for a reason not yet root-caused"
  // (see git history on this file). Root-caused: it was never actually
  // trying to redeem a real invite -- there was no seeded
  // `FakeFleetRepository` invite for the typed token to match, so
  // `redeemInvite` threw synchronously and the flow never got past the
  // error path this file's own rejected-registration test already covers.
  // The two tests below seed a real invite via `FakeFleetRepository`
  // (the same fake instance `testDependencies(fleet: ...)` wires the whole
  // app to) before pumping, so submit actually exercises the success/
  // phone-mismatch redemption paths. Both use bounded `pump(duration)`
  // calls after tapping submit, not `pumpAndSettle()` -- the submit
  // button's indeterminate `CircularProgressIndicator` keeps scheduling
  // frames until the screen navigates away (see the AUTH-5 success test's
  // own comment above), so `pumpAndSettle()` genuinely can hang here; a
  // bounded pump cannot, by construction, regardless of what's animating.
  testWidgets(
      'FLT-4: redeeming a valid invite links the pre-provisioned truck and '
      'lands on the driver shell', (tester) async {
    // The root cause of this test's long-standing hang, finally found:
    // `createFleet`/`createInvite` both `await Future<...>.delayed(actionDelay)`
    // internally -- even at `Duration.zero`, a zero-duration `Timer` still
    // needs the FakeAsync zone's `elapse()` to fire it. Inside a
    // `testWidgets` body, that zone only advances when `tester.pump(...)`
    // runs, and *nothing* has pumped yet this early -- a bare `await` here
    // blocks forever (confirmed directly: checkpoint logging showed
    // execution stopping at exactly this call, every time). `tester.runAsync`
    // steps outside the FakeAsync zone into a real one, where a real
    // (near-instant, given `actionDelay: Duration.zero`) `Future.delayed`
    // just resolves normally -- the actual fix, not a workaround.
    final fleet = FakeFleetRepository(actionDelay: Duration.zero);
    final invite = await tester.runAsync(() async {
      await fleet.createFleet(name: 'Grúas del Valle');
      return fleet.createInvite(
        phone: '+573000000000', // matches FakeAuthRepository.currentPhone
        plate: 'INV001',
        truckType: TruckType.flatbed,
        capacity: TruckCapacity.both,
      );
    });

    await tester.pumpWidget(
      TheCraneApp(dependencies: testDependencies(fleet: fleet)),
    );
    await tester.pumpAndSettle();
    await signIn(tester);
    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('becomeDriverMenuItem')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tengo una invitación'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('inviteTokenField')),
      invite!.inviteToken,
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('becomeDriverSubmitButton')));
    await tester.tap(find.byKey(const Key('becomeDriverSubmitButton')));
    // registerDriver's actionDelay + refreshUser's sync delay, then the
    // router redirect's route transition -- same fixed sequence the AUTH-5
    // success test above uses, deliberately not pumpAndSettle (see comment
    // above this group of tests).
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DriverHomeScreen), findsOneWidget);
  });

  testWidgets(
      'FLT-4: a phone-mismatched invite shows an inline error instead of '
      'hanging or silently succeeding', (tester) async {
    // See the previous test's comment: `tester.runAsync` is required here
    // (not just `Duration.zero`) because these fake-repository calls are
    // awaited before the first `pump()`, while the FakeAsync zone's clock
    // is still inert.
    final fleet = FakeFleetRepository(actionDelay: Duration.zero);
    // A phone that does NOT match FakeAuthRepository.currentPhone
    // (+573000000000) -- redeemInvite must reject this.
    final invite = await tester.runAsync(() async {
      await fleet.createFleet(name: 'Grúas del Valle');
      return fleet.createInvite(
        phone: '+573009998877',
        plate: 'INV002',
        truckType: TruckType.flatbed,
        capacity: TruckCapacity.both,
      );
    });

    await tester.pumpWidget(
      TheCraneApp(dependencies: testDependencies(fleet: fleet)),
    );
    await tester.pumpAndSettle();
    await signIn(tester);
    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('becomeDriverMenuItem')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tengo una invitación'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('inviteTokenField')),
      invite!.inviteToken,
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('becomeDriverSubmitButton')));
    await tester.tap(find.byKey(const Key('becomeDriverSubmitButton')));
    await tester.pump(); // isSubmitting
    await tester.pump(const Duration(milliseconds: 20)); // actionDelay

    expect(
      find.text('No pudimos completar el registro. Intenta de nuevo.'),
      findsOneWidget,
    );
    // Still on this screen, and submit is re-enabled (the token field is
    // still filled) -- same shape as the generic-rejection test above.
    expect(find.byType(BecomeDriverScreen), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('becomeDriverSubmitButton')),
          )
          .onPressed,
      isNotNull,
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

  // AUTH-5 follow-up (2026-08-31): real document upload via
  // DocumentImagePicker/DocumentUploadRepository, replacing the old
  // hand-typed licenseUrlField/truckPhotoUrlField text fields.
  testWidgets(
      'AUTH-5 follow-up: picking a document uploads it immediately, shows a '
      'thumbnail + uploaded status, and the real download URL is what gets '
      'sent to registerDriver', (tester) async {
    final jobs = fastFakeJobs();
    final drivers = _CapturingDriversRepository(
      jobs: jobs,
      actionDelay: const Duration(milliseconds: 10),
    );
    final picker = FakeDocumentImagePicker(delay: const Duration(milliseconds: 10));
    final uploads =
        FakeDocumentUploadRepository(delay: const Duration(milliseconds: 10));
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(
        jobs: jobs,
        drivers: drivers,
        documentImagePicker: picker,
        documentUploadRepository: uploads,
      ),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);
    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('becomeDriverMenuItem')));
    await tester.pumpAndSettle();

    // No thumbnail/status before anything is picked.
    expect(find.byKey(const Key('licenseThumbnail')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('licensePickButton')));
    await tester.tap(find.byKey(const Key('licensePickButton')));
    await tester.pump(const Duration(milliseconds: 10)); // picker delay
    // Thumbnail appears once picked, before the upload itself resolves.
    expect(find.byKey(const Key('licenseThumbnail')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 10)); // upload delay
    expect(find.byKey(const Key('licenseUploadedLabel')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('truckPhotoPickButton')));
    await tester.tap(find.byKey(const Key('truckPhotoPickButton')));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byKey(const Key('truckPhotoUploadedLabel')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('plateField')), 'XYZ987');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('becomeDriverSubmitButton')));
    await tester.tap(find.byKey(const Key('becomeDriverSubmitButton')));
    await tester.pump(const Duration(milliseconds: 20)); // registerDriver's actionDelay

    expect(drivers.lastLicenseUrl, 'https://fake-storage.local/fake-user-1/license.jpg');
    expect(
      drivers.lastTruckPhotoUrl,
      'https://fake-storage.local/fake-user-1/truck_photo.jpg',
    );
  });

  testWidgets(
      'AUTH-5 follow-up: a failed document upload shows an inline error but '
      "doesn't block submitting the registration without that document",
      (tester) async {
    final jobs = fastFakeJobs();
    final drivers = _CapturingDriversRepository(
      jobs: jobs,
      actionDelay: const Duration(milliseconds: 10),
    );
    final picker = FakeDocumentImagePicker(delay: const Duration(milliseconds: 10));
    final uploads = FakeDocumentUploadRepository(
      delay: const Duration(milliseconds: 10),
    )..rejectNext = true;
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(
        jobs: jobs,
        drivers: drivers,
        documentImagePicker: picker,
        documentUploadRepository: uploads,
      ),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);
    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('becomeDriverMenuItem')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('licensePickButton')));
    await tester.tap(find.byKey(const Key('licensePickButton')));
    await tester.pump(const Duration(milliseconds: 10)); // picker delay
    await tester.pump(const Duration(milliseconds: 10)); // upload delay (fails)

    expect(find.byKey(const Key('licenseUploadError')), findsOneWidget);
    // The picked thumbnail is still shown -- only the upload failed, so the
    // driver can see what they picked before deciding to retry or move on.
    expect(find.byKey(const Key('licenseThumbnail')), findsOneWidget);

    // Registration still succeeds without the license URL -- both documents
    // are optional (backend schema: `str | None`).
    await tester.enterText(find.byKey(const Key('plateField')), 'NOLIC01');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('becomeDriverSubmitButton')));
    await tester.tap(find.byKey(const Key('becomeDriverSubmitButton')));
    await tester.pump(const Duration(milliseconds: 20)); // registerDriver's actionDelay

    expect(drivers.lastLicenseUrl, isNull);
    expect(drivers.lastTruckPhotoUrl, isNull);
  });

  testWidgets(
      'AUTH-5 follow-up: cancelling the picker leaves the document unpicked',
      (tester) async {
    final picker = FakeDocumentImagePicker()..cancelNext = true;
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(documentImagePicker: picker),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);
    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('becomeDriverMenuItem')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('licensePickButton')));
    await tester.tap(find.byKey(const Key('licensePickButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('licenseThumbnail')), findsNothing);
    expect(find.byKey(const Key('licenseUploadError')), findsNothing);
    expect(find.byKey(const Key('licenseUploadedLabel')), findsNothing);
  });
}
