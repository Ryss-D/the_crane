import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/di.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/api/directions_repository.dart';
import 'core/api/drivers_repository.dart';
import 'core/api/fleet_repository.dart';
import 'core/api/jobs_repository.dart';
import 'core/api/places_repository.dart';
import 'core/api/vehicles_repository.dart';
import 'core/location/location_source.dart';
import 'core/notifications/notification_permission_requester.dart';
import 'core/notifications/push_notifications.dart';
import 'core/storage/active_job_store.dart';
import 'core/ws/crane_socket.dart';
import 'features/auth/auth_cubit.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No `options:` — Android/iOS read their config from the native
  // google-services.json / GoogleService-Info.plist dropped in by FND-1.
  // (Only web/desktop targets need an explicit FirebaseOptions object; this
  // app doesn't ship on those.)
  await Firebase.initializeApp();
  // TRK-3: MUST be registered before `runApp` per Firebase's own
  // requirement — `firebaseMessagingBackgroundHandler` is a top-level
  // function (see `core/notifications/push_notifications.dart`) that runs
  // in its own background isolate on Android when a data message arrives
  // while the app is backgrounded or killed, and shows a local notification
  // there since a bare data message (no `notification` block, which is
  // what the backend sends) is otherwise delivered with no UI at all.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotifications.instance.init();
  final prefs = await SharedPreferences.getInstance();
  final dependencies = AppDependencies.fromEnv(
    activeJobStore: SharedPreferencesActiveJobStore(prefs),
  );
  // Settle auth state (already-signed-in check + profile sync) before the
  // first frame, so the router's very first redirect doesn't flash the
  // sign-in screen for a returning user.
  await dependencies.authCubit.bootstrap();
  runApp(TheCraneApp(dependencies: dependencies));
}

class TheCraneApp extends StatefulWidget {
  const TheCraneApp({super.key, required this.dependencies});

  /// Composition root; tests inject fakes with short delays here.
  final AppDependencies dependencies;

  @override
  State<TheCraneApp> createState() => _TheCraneAppState();
}

class _TheCraneAppState extends State<TheCraneApp> with WidgetsBindingObserver {
  late final GoRouter _router = createRouter(widget.dependencies.authCubit);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // TRK-3: tapping a notification `PushNotifications` showed (foreground
    // or backgrounded-but-not-killed — see its `init`'s
    // `onDidReceiveNotificationResponse`) lands here on the driver home
    // screen. A full deep-link straight to the job the push was about is
    // out of scope; the existing offer/job machinery
    // (OfferCubit/ActiveJobCubit) picks things up itself once the socket
    // reconnects, via the resumed-lifecycle handling below. For a
    // killed-app cold start via tap, this callback never fires at all (the
    // app wasn't running to register it) — but the router's own
    // authenticated-driver redirect (`routerRedirect` in `app/router.dart`)
    // already lands there anyway, with no extra wiring needed.
    PushNotifications.instance.onNotificationTap =
        () => _router.go(AppRoute.driverHome);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// DRV-2: coming back from the background is the case that most likely
  /// left the socket's own reconnect backoff stale (mobile OSes tend to
  /// suspend networking while backgrounded) — nudge it to check right away
  /// rather than waiting out whatever backoff it's mid-wait on. A no-op
  /// under `Env.useFakeBackend` (`socket` is null there).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.dependencies.socket?.reconnectNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<JobsRepository>.value(
          value: widget.dependencies.jobsRepository,
        ),
        RepositoryProvider<DriversRepository>.value(
          value: widget.dependencies.driversRepository,
        ),
        RepositoryProvider<VehiclesRepository>.value(
          value: widget.dependencies.vehiclesRepository,
        ),
        RepositoryProvider<FleetRepository>.value(
          value: widget.dependencies.fleetRepository,
        ),
        RepositoryProvider<ActiveJobStore>.value(
          value: widget.dependencies.activeJobStore,
        ),
        RepositoryProvider<PlacesRepository>.value(
          value: widget.dependencies.placesRepository,
        ),
        RepositoryProvider<DirectionsRepository>.value(
          value: widget.dependencies.directionsRepository,
        ),
        // Null under `Env.useFakeBackend` (see `AppDependencies.fromEnv`);
        // `ActiveJobCubit` treats a null socket as "no location push".
        RepositoryProvider<CraneSocket?>.value(
          value: widget.dependencies.socket,
        ),
        // Null under `Env.useFakeBackend`; `DriverHomeCubit`/`ActiveJobCubit`
        // treat a null source as "no real GPS" (TRK-5).
        RepositoryProvider<LocationSource?>.value(
          value: widget.dependencies.locationSource,
        ),
        // Null under `Env.useFakeBackend` — same reasoning as `socket`/
        // `locationSource` above: nothing there needs a real device
        // permission prompt. `DriverHomeCubit` treats a null requester as
        // "don't ask" (TRK-3).
        RepositoryProvider<NotificationPermissionRequester?>.value(
          value: widget.dependencies.notificationPermissionRequester,
        ),
      ],
      child: BlocProvider<AuthCubit>.value(
        value: widget.dependencies.authCubit,
        child: MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          routerConfig: _router,
        ),
      ),
    );
  }
}
