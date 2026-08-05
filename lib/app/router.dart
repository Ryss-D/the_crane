import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/api/drivers_repository.dart';
import '../core/api/jobs_repository.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/customer/request/matching_screen.dart';
import '../features/customer/request/request_bloc.dart';
import '../features/customer/request/request_screen.dart';
import '../features/driver/home/driver_home_cubit.dart';
import '../features/driver/home/driver_home_screen.dart';
import '../features/driver/home/offer_cubit.dart';
import '../features/driver/job/active_job_cubit.dart';
import '../features/driver/job/active_job_screen.dart';

/// Route paths.
abstract final class AppRoute {
  static const signIn = '/sign-in';
  static const customerHome = '/customer';
  static const customerMatching = '/customer/matching';
  static const driverHome = '/driver';
  static const driverJob = '/driver/job';
}

/// Auth state as seen by the router.
enum AuthStatus { unauthenticated, customer, driver }

/// Auth guard stub.
///
/// TODO(AUTH-3/AUTH-4): replace with the real Firebase auth state + synced
/// profile role. When implemented, [routerRedirect] must send
/// unauthenticated users to [AppRoute.signIn] and signed-in users to their
/// role's shell ([AppRoute.customerHome] / [AppRoute.driverHome]).
AuthStatus currentAuthStatus() => AuthStatus.unauthenticated;

/// Role-aware redirect. Permissive for now so both placeholder shells stay
/// reachable from the sign-in screen's dev role switch.
String? routerRedirect(GoRouterState state) {
  switch (currentAuthStatus()) {
    case AuthStatus.unauthenticated:
      // TODO(AUTH-3/AUTH-4): once real auth lands, force AppRoute.signIn here
      // for any protected route instead of allowing navigation through.
      return null;
    case AuthStatus.customer:
      return state.matchedLocation == AppRoute.signIn
          ? AppRoute.customerHome
          : null;
    case AuthStatus.driver:
      return state.matchedLocation == AppRoute.signIn
          ? AppRoute.driverHome
          : null;
  }
}

/// Builds the app router. Feature blocs are provided by [ShellRoute]s so
/// they live exactly as long as their flow (customer request / driver work)
/// and can read repositories from the `MultiRepositoryProvider` above the
/// router (see `main.dart`).
GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoute.signIn,
    redirect: (context, state) => routerRedirect(state),
    routes: [
      GoRoute(
        path: AppRoute.signIn,
        builder: (context, state) => const SignInScreen(),
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
              ),
            ),
            BlocProvider(
              create: (context) => ActiveJobCubit(
                jobsRepository: context.read<JobsRepository>(),
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
            ],
          ),
        ],
      ),
    ],
  );
}
