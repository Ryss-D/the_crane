import 'dart:io';

import 'document_upload_repository.dart';

/// In-memory stand-in for [DocumentUploadRepository] -- no real network/IO,
/// just a deterministic URL derived from the inputs, mirroring every other
/// fake repository's shape in this codebase.
class FakeDocumentUploadRepository implements DocumentUploadRepository {
  FakeDocumentUploadRepository({
    this.delay = const Duration(milliseconds: 20),
  });

  final Duration delay;

  /// Test hook: when true, the *next* [uploadDriverDocument] call throws
  /// instead of succeeding, then resets to false -- lets a widget test
  /// exercise `BecomeDriverScreen`'s inline upload-failure/retry path
  /// without a real Storage bucket.
  bool rejectNext = false;

  @override
  Future<String> uploadDriverDocument({
    required String driverUserId,
    required String kind,
    required File file,
  }) async {
    await Future<void>.delayed(delay);
    if (rejectNext) {
      rejectNext = false;
      throw StateError('upload failed');
    }
    return 'https://fake-storage.local/$driverUserId/$kind.jpg';
  }
}
