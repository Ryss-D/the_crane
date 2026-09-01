import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// AUTH-5 follow-up (2026-08-31) — uploads a driver's license/truck-photo
/// image to Firebase Storage (the same Firebase project `FND-1` already
/// wired for Auth/Messaging — see `Firebase.initializeApp()` in
/// `lib/main.dart`) and returns its public download URL. That URL is what
/// actually gets sent as `DriversRepository.registerDriver`'s
/// `licenseUrl`/`truckPhotoUrl` — the backend only ever sees an opaque
/// string either way (`backend/app/schemas/driver.py`'s `license_url`/
/// `truck_photo_url` are plain `str | None`), so this repository is the
/// entire scope of "real" document upload; no backend changes are needed.
///
/// Implementations: [FirebaseDocumentUploadRepository] (real) and
/// `FakeDocumentUploadRepository` (deterministic fake URL, no network/IO).
/// The composition root in `lib/app/di.dart` picks one from
/// `Env.useFakeBackend`, same convention as every other repository here.
abstract interface class DocumentUploadRepository {
  /// Uploads [file] to `driver-documents/{driverUserId}/{kind}<ext>` and
  /// returns its download URL.
  ///
  /// [kind] distinguishes the two documents this screen collects --
  /// `license` and `truck_photo` -- and is kept as a plain string rather
  /// than an enum since this repository otherwise has no reason to depend
  /// on driver-domain types.
  Future<String> uploadDriverDocument({
    required String driverUserId,
    required String kind,
    required File file,
  });
}

/// `firebase_storage`-backed implementation.
class FirebaseDocumentUploadRepository implements DocumentUploadRepository {
  FirebaseDocumentUploadRepository([FirebaseStorage? storage])
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadDriverDocument({
    required String driverUserId,
    required String kind,
    required File file,
  }) async {
    final ref = _storage.ref(
      'driver-documents/$driverUserId/$kind${_extensionOf(file.path)}',
    );
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// Defaults to `.jpg` when the picked file has no extension -- image_picker
  /// always gives one in practice, but a missing one shouldn't crash the
  /// upload over a cosmetic storage-path detail.
  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '.jpg';
    return path.substring(dot);
  }
}
