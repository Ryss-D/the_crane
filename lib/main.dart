import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'app/di.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/api/drivers_repository.dart';
import 'core/api/fleet_repository.dart';
import 'core/api/jobs_repository.dart';
import 'core/api/vehicles_repository.dart';
import 'core/location/location_source.dart';
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
  final dependencies = AppDependencies.fromEnv();
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
