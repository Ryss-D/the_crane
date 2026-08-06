import '../models/app_user.dart';
import 'auth_repository.dart';

/// Dev/test double: no backend. [role] defaults to `customer` (matching real
/// signups — everyone starts as a customer; AUTH-5 is the only way to become
/// a driver). Tests that need to reach the driver shell construct this with
/// `role: UserRole.driver` and drive the real phone+OTP flow — no debug-only
/// UI bypass needed, so the router's real redirect logic stays exercised.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.delay = const Duration(milliseconds: 150),
    this.role = UserRole.customer,
  });

  final Duration delay;
  final UserRole role;
  AppUser? _user;

  /// FLT-4: the signed-in fake user's verified phone — `FakeDriversRepository
  /// .registerDriver` reads this to check an invite's phone against the
  /// caller's own, mirroring the real backend's `claims.get("phone_number")`
  /// check. Null before [sync] has run.
  String? get currentPhone => _user?.phone;

  @override
  Future<AppUser> sync({String? name}) async {
    await Future<void>.delayed(delay);
    _user ??= AppUser(
      id: 'fake-user-1',
      firebaseUid: 'fake-firebase-uid',
      role: role,
      name: name,
      phone: '+573000000000',
    );
    return _user!;
  }

  @override
  Future<AppUser> updateProfile({required String name}) async {
    await Future<void>.delayed(delay);
    final current = _user;
    if (current == null) {
      throw StateError('sync must be called before updateProfile');
    }
    _user = current.copyWith(name: name);
    return _user!;
  }

  String? lastFcmToken;

  @override
  Future<void> updateFcmToken(String? token) async {
    await Future<void>.delayed(delay);
    lastFcmToken = token;
  }

  /// Dev/test-only: mirrors the real backend's role flip in
  /// `POST /v1/drivers/me/register` (AUTH-5) — `FakeDriversRepository`
  /// shares this instance and calls it right after a successful
  /// `registerDriver`, so a subsequent `AuthCubit.refreshUser()` re-sync
  /// (i.e. another call to [sync]) observes the new role, same as the real
  /// backend does on its next `/auth/sync`.
  void debugPromoteToDriver() {
    final current = _user;
    if (current != null) _user = current.copyWith(role: UserRole.driver);
  }

  /// Dev/test-only: mirrors the real backend's role flip in
  /// `POST /v1/fleets/me` (FLT-1) — `FakeFleetRepository` shares this
  /// instance and calls it right after a successful `createFleet`, same
  /// pattern as [debugPromoteToDriver] above.
  void debugPromoteToFleetOwner() {
    final current = _user;
    if (current != null) _user = current.copyWith(role: UserRole.fleetOwner);
  }
}
