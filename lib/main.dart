import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'app/di.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/api/drivers_repository.dart';
import 'core/api/jobs_repository.dart';
import 'core/ws/crane_socket.dart';
import 'l10n/app_localizations.dart';

void main() {
  // TODO(FND-1): initialize Firebase here (WidgetsFlutterBinding +
  // Firebase.initializeApp with per-flavor options) once the Firebase
  // project is wired.
  runApp(TheCraneApp(dependencies: AppDependencies.fromEnv()));
}

class TheCraneApp extends StatefulWidget {
  const TheCraneApp({super.key, required this.dependencies});

  /// Composition root; tests inject fakes with short delays here.
  final AppDependencies dependencies;

  @override
  State<TheCraneApp> createState() => _TheCraneAppState();
}

class _TheCraneAppState extends State<TheCraneApp> {
  late final GoRouter _router = createRouter();

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
        // Null under `Env.useFakeBackend` (see `AppDependencies.fromEnv`);
        // `ActiveJobCubit` treats a null socket as "no location push".
        RepositoryProvider<CraneSocket?>.value(
          value: widget.dependencies.socket,
        ),
      ],
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        routerConfig: _router,
      ),
    );
  }
}
