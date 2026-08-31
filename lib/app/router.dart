import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/api/drivers_repository.dart';
import '../core/api/fleet_repository.dart';
import '../core/api/jobs_repository.dart';
import '../core/api/places_repository.dart';
import '../core/api/vehicles_repository.dart';
import '../core/location/location_source.dart';
import '../core/models/app_user.dart';
import '../core/notifications/notification_permission_requester.dart';
import '../core/storage/active_job_store.dart';
import '../core/ws/crane_socket.dart';
import '../features/auth/auth_cubit.dart';
import '../features/auth/auth_state.dart';
import '../features/auth/complete_profile_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/customer/request/matching_screen.dart';
import '../features/customer/request/request_bloc.dart';
import '../features/customer/request/request_screen.dart';
import '../features/customer/settings/become_driver_screen.dart';
import '../features/customer/settings/become_fleet_owner_screen.dart';
import '../features/customer/settings/saved_vehicles_cubit.dart';
import '../features/customer/settings/saved_vehicles_screen.dart';
import '../features/customer/settings/settings_screen.dart';
import '../features/driver/earnings/driver_balance_cubit.dart';
import '../features/driver/earnings/earnings_screen.dart';
import '../features/driver/earnings/services_period_cubit.dart';
import '../features/driver/earnings/services_period_screen.dart';
import '../features/driver/home/driver_home_cubit.dart';
import '../features/driver/home/driver_home_screen.dart';
import '../features/driver/home/offer_cubit.dart';
import '../features/driver/job/active_job_cubit.dart';
import '../features/driver/job/active_job_screen.dart';
import '../features/fleet/add_truck/add_truck_screen.dart';
import '../features/fleet/balance/fleet_balance_cubit.dart';
import '../features/fleet/balance/fleet_balance_screen.dart';
import '../features/fleet/home/fleet_cubit.dart';
import '../features/fleet/home/fleet_home_screen.dart';
import '../features/fleet/invite_driver/invite_driver_screen.dart';
import '../features/fleet/truck_detail/fleet_truck_detail_screen.dart';
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
  static const customerSettings = '/customer/settings';
  static const customerBecomeDriver = '/customer/settings/become-driver';
  static const customerBecomeFleetOwner =
      '/customer/settings/become-fleet-owner';
  static const customerVehicles = '/customer/settings/vehicles';
  static const driverHome = '/driver';
  static const driverJob = '/driver/job';
  static const driverHistory = '/driver/history';
  static const driverEarnings = '/driver/earnings';
  static const driverServicesPeriod = '/driver/earnings/services';
  static const fleetHome = '/fleet';
  static const fleetAddTruck = '/fleet/add-truck';
  static const fleetInviteDriver = '/fleet/invite-driver';
  static const fleetBalance = '/fleet/balance';

  /// FLT-3: truck detail is a path-parameterized route (`trucks/:truckId`)
  /// rather than a fixed constant — this builds the concrete path for a
  /// given truck to navigate to.
  static String fleetTruckDetail(String truckId) => '/fleet/trucks/$truckId';
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
      final home = switch (authState.user?.role) {
        UserRole.driver => AppRoute.driverHome,
        UserRole.fleetOwner => AppRoute.fleetHome,
        _ => AppRoute.customerHome,
      };
      if (_authRoutes.contains(loc)) return home;
      // AUTH-5/FLT-1: becoming a driver or a fleet owner flips the role
      // while the app is still sitting inside the customer shell (e.g. on
      // the become-driver/become-fleet-owner screen itself) — bounce out
      // of whichever shell no longer matches the current role once
      // `AuthCubit.refreshUser` picks that up. A customer can never be
      // inside `/driver/...` or `/fleet/...` in the first place, so this
      // is one-directional in practice, but is written symmetrically over
      // all three shells.
      final inWrongShell = !loc.startsWith(home) &&
          (loc.startsWith(AppRoute.customerHome) ||
              loc.startsWith(AppRoute.driverHome) ||
              loc.startsWith(AppRoute.fleetHome));
      return inWrongShell ? home : null;
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
          create: (context) => RequestBloc(
            jobsRepository: context.read<JobsRepository>(),
            placesRepository: context.read<PlacesRepository>(),
            activeJobStore: context.read<ActiveJobStore>(),
            socket: context.read<CraneSocket?>(),
          ),
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
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'become-driver',
                    builder: (context, state) => const BecomeDriverScreen(),
                  ),
                  GoRoute(
                    path: 'become-fleet-owner',
                    builder: (context, state) =>
                        const BecomeFleetOwnerScreen(),
                  ),
                  GoRoute(
                    path: 'vehicles',
                    builder: (context, state) => BlocProvider(
                      create: (context) => SavedVehiclesCubit(
                        vehiclesRepository: context.read<VehiclesRepository>(),
                      )..load(),
                      child: const SavedVehiclesScreen(),
                    ),
                  ),
                ],
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
                notificationPermissionRequester:
                    context.read<NotificationPermissionRequester?>(),
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
              GoRoute(
                path: 'earnings',
                builder: (context, state) => BlocProvider(
                  create: (context) => DriverBalanceCubit(
                    driversRepository: context.read<DriversRepository>(),
                  )..load(),
                  child: const EarningsScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'services',
                    builder: (context, state) => BlocProvider(
                      create: (context) => ServicesPeriodCubit(
                        jobsRepository: context.read<JobsRepository>(),
                      )..load(),
                      child: const ServicesPeriodScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => BlocProvider(
          create: (context) => FleetCubit(
            fleetRepository: context.read<FleetRepository>(),
          )..load(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: AppRoute.fleetHome,
            builder: (context, state) => const FleetHomeScreen(),
            routes: [
              GoRoute(
                path: 'trucks/:truckId',
                builder: (context, state) => FleetTruckDetailScreen(
                  truckId: state.pathParameters['truckId']!,
                ),
              ),
              GoRoute(
                path: 'add-truck',
                builder: (context, state) => const AddTruckScreen(),
              ),
              GoRoute(
                path: 'invite-driver',
                builder: (context, state) => const InviteDriverScreen(),
              ),
              GoRoute(
                path: 'balance',
                builder: (context, state) => BlocProvider(
                  create: (context) => FleetBalanceCubit(
                    fleetRepository: context.read<FleetRepository>(),
                  )..load(),
                  child: const FleetBalanceScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
