import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/api/drivers_repository.dart';
import '../core/api/jobs_repository.dart';
import '../core/location/location_source.dart';
import '../core/models/app_user.dart';
import '../core/ws/crane_socket.dart';
import '../features/auth/auth_cubit.dart';
import '../features/auth/auth_state.dart';
import '../features/auth/complete_profile_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/customer/request/matching_screen.dart';
import '../features/customer/request/request_bloc.dart';
import '../features/customer/request/request_screen.dart';
import '../features/driver/home/driver_home_cubit.dart';
import '../features/driver/home/driver_home_screen.dart';
import '../features/driver/home/offer_cubit.dart';
import '../features/driver/job/active_job_cubit.dart';
import '../features/driver/job/active_job_screen.dart';
import '../features/shared/history/history_cubit.dart';
import '../features/shared/history/history_screen.dart';

/// Route paths.
abstract final class AppRoute {
  static const signIn = '/sign-in';
  static const otp = '/otp';
  static const completeProfile = '/complete-profile';
  static const customerHome = '/customer';
  static const customerMatching = '/customer/matching';
  static const customerHistory = '/customer/history';
  static const driverHome = '/driver';
  static const driverJob = '/driver/job';
  static const driverHistory = '/driver/history';
}

const _authRoutes = {AppRoute.signIn, AppRoute.otp, AppRoute.completeProfile};

/// Role-aware redirect driven by [AuthCubit]'s current phase (AUTH-3/AUTH-4).
/// `syncing` deliberately redirects nowhere — the caller stays on whichever
/// auth screen triggered it until the sync settles into `needsProfile` or
/// `authenticated`.
String? routerRedirect(GoRouterState state, AuthCubit authCubit) {
  final authState = authCubit.state;
  final loc = state.matchedLocation;

  switch (authState.phase) {
    case AuthPhase.unauthenticated:
      return loc == AppRoute.signIn ? null : AppRoute.signIn;
    case AuthPhase.codeSent:
      return loc == AppRoute.otp ? null : AppRoute.otp;
    case AuthPhase.syncing:
      return null;
    case AuthPhase.needsProfile:
      return loc == AppRoute.completeProfile ? null : AppRoute.completeProfile;
    case AuthPhase.authenticated:
      final home = authState.user?.role == UserRole.driver
          ? AppRoute.driverHome
          : AppRoute.customerHome;
      return _authRoutes.contains(loc) ? home : null;
  }
}

/// Bridges [AuthCubit]'s stream to go_router's `refreshListenable` — every
/// emitted state re-runs [routerRedirect].
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(AuthCubit authCubit) {
    _sub = authCubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

/// Builds the app router. Feature blocs are provided by [ShellRoute]s so
/// they live exactly as long as their flow (customer request / driver work)
/// and can read repositories from the `MultiRepositoryProvider` above the
/// router (see `main.dart`). [authCubit] must already be bootstrapped
/// (`AuthCubit.bootstrap()`) before this is called, so the very first
/// redirect evaluation sees a settled phase, not a flash of the sign-in
/// screen for an already-signed-in user.
GoRouter createRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: AppRoute.signIn,
    refreshListenable: _AuthRefreshListenable(authCubit),
    redirect: (context, state) => routerRedirect(state, authCubit),
    routes: [
      GoRoute(
        path: AppRoute.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoute.otp,
        builder: (context, state) => const OtpScreen(),
      ),
      GoRoute(
        path: AppRoute.completeProfile,
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => BlocProvider(
          create: (context) =>
              RequestBloc(jobsRepository: context.read<JobsRepository>()),
          child: child,
        ),
        routes: [
          GoRoute(
            path: AppRoute.customerHome,
            builder: (context, state) => const RequestScreen(),
            routes: [
              GoRoute(
                path: 'matching',
                builder: (context, state) => const MatchingScreen(),
              ),
              GoRoute(
                path: 'history',
                builder: (context, state) => BlocProvider(
                  create: (context) => HistoryCubit(
                    jobsRepository: context.read<JobsRepository>(),
                    role: JobHistoryRole.customer,
                  )..load(),
                  child: const HistoryScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => DriverHomeCubit(
                driversRepository: context.read<DriversRepository>(),
                locationSource: context.read<LocationSource?>(),
              ),
            ),
            BlocProvider(
              create: (context) => ActiveJobCubit(
                jobsRepository: context.read<JobsRepository>(),
                socket: context.read<CraneSocket?>(),
                locationSource: context.read<LocationSource?>(),
              ),
            ),
            BlocProvider(
              create: (context) => OfferCubit(
                driversRepository: context.read<DriversRepository>(),
                jobsRepository: context.read<JobsRepository>(),
              ),
            ),
          ],
          child: child,
        ),
        routes: [
          GoRoute(
            path: AppRoute.driverHome,
            builder: (context, state) => const DriverHomeScreen(),
            routes: [
              GoRoute(
                path: 'job',
                builder: (context, state) => const ActiveJobScreen(),
              ),
              GoRoute(
                path: 'history',
                builder: (context, state) => BlocProvider(
                  create: (context) => HistoryCubit(
                    jobsRepository: context.read<JobsRepository>(),
                    role: JobHistoryRole.driver,
                  )..load(),
                  child: const HistoryScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
