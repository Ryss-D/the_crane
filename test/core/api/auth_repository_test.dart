import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:the_crane/core/api/auth_repository.dart';
import 'package:the_crane/core/models/app_user.dart';

class MockDio extends Mock implements Dio {}

/// `POST /v1/auth/sync` / `PATCH /v1/me` response shape, per
/// `backend/app/schemas/user.py::UserRead`. `created_at` is included to
/// match the real backend exactly even though [AppUser] doesn't model it
/// (json_serializable silently ignores unknown keys, so this is safe).
Map<String, dynamic> _userJson({
  String id = 'user-1',
  String firebaseUid = 'fb-1',
  String role = 'customer',
  String? name,
  String? phone,
  String? email,
  String? fcmToken,
}) => {
  'id': id,
  'firebase_uid': firebaseUid,
  'role': role,
  'name': name,
  'phone': phone,
  'email': email,
  'fcm_token': fcmToken,
  'created_at': '2026-01-01T00:00:00Z',
};

Response<Map<String, dynamic>> _okResponse(
  Map<String, dynamic> data, {
  int statusCode = 200,
  String path = '/x',
}) => Response(
  requestOptions: RequestOptions(path: path),
  statusCode: statusCode,
  data: data,
);

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  late MockDio dio;
  late ApiAuthRepository repo;

  setUp(() {
    dio = MockDio();
    repo = ApiAuthRepository(dio);
  });

  group('ApiAuthRepository.sync', () {
    test('posts to /v1/auth/sync and parses the returned user', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(_userJson(name: 'Sofía', phone: '+57300')),
      );

      final user = await repo.sync(name: 'Sofía');

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/v1/auth/sync');
      expect(captured[1], {'name': 'Sofía'});
      expect(user.id, 'user-1');
      expect(user.name, 'Sofía');
      expect(user.role, UserRole.customer);
    });

    test('omits name from the body entirely when not passed', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _okResponse(_userJson()));

      await repo.sync();

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured.single, isEmpty);
    });

    test('propagates a DioException without wrapping it', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/auth/sync'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/auth/sync'),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => repo.sync(),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });
  });

  group('ApiAuthRepository.updateProfile', () {
    test('patches /v1/me with the name and parses the response', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _okResponse(_userJson(name: 'Sofía Test')));

      final user = await repo.updateProfile(name: 'Sofía Test');

      final captured = verify(
        () => dio.patch<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/v1/me');
      expect(captured[1], {'name': 'Sofía Test'});
      expect(user.name, 'Sofía Test');
    });

    test('propagates a 422 DioException', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/me'),
            statusCode: 422,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => repo.updateProfile(name: ''),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ApiAuthRepository.updateFcmToken', () {
    test('sends the token on the fcm_token field', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _okResponse(_userJson(fcmToken: 'tok-1')));

      await repo.updateFcmToken('tok-1');

      final captured = verify(
        () => dio.patch<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/v1/me');
      expect(captured[1], {'fcm_token': 'tok-1'});
    });

    test('sends an explicit null to clear the token on sign-out', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _okResponse(_userJson()));

      await repo.updateFcmToken(null);

      final captured = verify(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      // Unlike sync's optional `name`, updateFcmToken always sends the key
      // -- explicit null is how the backend is told to clear it, not
      // omission (see PATCH /v1/me's exclude_unset convention).
      expect(captured.single, {'fcm_token': null});
    });
  });
}
