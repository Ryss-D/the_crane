import 'dart:async';

import 'push_token_gateway.dart';

/// Dev/test double: a fixed token, no real FCM plumbing.
class FakePushTokenGateway implements PushTokenGateway {
  FakePushTokenGateway({this.token = 'fake-fcm-token'});

  final String? token;
  final _refreshController = StreamController<String>.broadcast();

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _refreshController.stream;

  /// Test hook: simulate the OS rotating the token.
  void emitRefresh(String newToken) => _refreshController.add(newToken);

  void dispose() => _refreshController.close();
}
