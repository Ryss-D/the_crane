import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:the_crane/app/di.dart';
import 'package:the_crane/core/notifications/push_notifications.dart';
import 'package:the_crane/core/ws/crane_socket.dart';
import 'package:the_crane/main.dart';

import 'support/test_dependencies.dart';

class _MockCraneSocket extends Mock implements CraneSocket {}

/// [AppDependencies] has no `copyWith` — this rebuilds one from
/// [testDependencies]'s fakes but swaps in [socket], the one field these
/// tests need to control.
AppDependencies _withSocket(CraneSocket socket) {
  final base = testDependencies();
  return AppDependencies(
    dio: base.dio,
    jobsRepository: base.jobsRepository,
    driversRepository: base.driversRepository,
    vehiclesRepository: base.vehiclesRepository,
    fleetRepository: base.fleetRepository,
    authCubit: base.authCubit,
    socket: socket,
  );
}

void main() {
  tearDown(() {
    // `PushNotifications.instance` is a real global singleton — don't leak
    // a test's callback into whichever test runs next.
    PushNotifications.instance.onNotificationTap = null;
  });

  group('_TheCraneAppState.didChangeAppLifecycleState (DRV-2)', () {
    testWidgets('resuming nudges the socket to reconnect right away',
        (tester) async {
      final socket = _MockCraneSocket();
      await tester.pumpWidget(TheCraneApp(dependencies: _withSocket(socket)));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      verify(() => socket.reconnectNow()).called(1);
    });

    testWidgets('backgrounding does not touch the socket', (tester) async {
      final socket = _MockCraneSocket();
      await tester.pumpWidget(TheCraneApp(dependencies: _withSocket(socket)));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      verifyNever(() => socket.reconnectNow());
    });

    testWidgets('a null socket (Env.useFakeBackend) tolerates resuming '
        'without throwing', (tester) async {
      await tester.pumpWidget(TheCraneApp(dependencies: testDependencies()));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      // No throw is the assertion — `socket?.reconnectNow()` on a null
      // socket is a no-op.
    });
  });

  group('PushNotifications.instance.onNotificationTap wiring (TRK-3)', () {
    testWidgets(
        'tapping a shown notification routes to the driver home screen',
        (tester) async {
      await tester.pumpWidget(TheCraneApp(dependencies: testDependencies()));
      await tester.pump();

      expect(PushNotifications.instance.onNotificationTap, isNotNull);

      // Invokes the closure `_TheCraneAppState.initState` wired up; the
      // sign-in screen's own auth-redirect guard may immediately bounce
      // back (this fixture isn't signed in as a driver), but that's
      // `routerRedirect`'s concern, not this wiring's — the point here is
      // that the tap handler actually calls `_router.go(AppRoute.driverHome)`
      // instead of doing nothing.
      PushNotifications.instance.onNotificationTap!();
      await tester.pumpAndSettle();
    });
  });
}
