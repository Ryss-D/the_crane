import 'dart:async';

import 'support/crane_map_test_stub.dart';

/// Flutter's own test-runner hook: runs once before every test file in this
/// directory tree. Installs cross-cutting test seams here rather than in
/// every individual test file's `setUp`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  installCraneMapTestStub();
  await testMain();
}
