import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/sign_in_screen.dart';
import '../features/customer/customer_home_screen.dart';
import '../features/driver/driver_home_screen.dart';

part 'router.g.dart';

/// Route paths.
abstract final class AppRoute {
  static const signIn = '/sign-in';
  static const customerHome = '/customer';
  static const driverHome = '/driver';
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

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: AppRoute.signIn,
    redirect: (context, state) => routerRedirect(state),
    routes: [
      GoRoute(
        path: AppRoute.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoute.customerHome,
        builder: (context, state) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: AppRoute.driverHome,
        builder: (context, state) => const DriverHomeScreen(),
      ),
    ],
  );
}
