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
}
