import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// AUTH-5 follow-up (2026-08-31) — abstracts `image_picker`'s gallery/camera
/// chooser so `BecomeDriverScreen` doesn't depend on the plugin directly,
/// the same seam `LocationSource` (`lib/core/location/location_source.dart`)
/// already uses for GPS: a real, plugin-backed implementation for the app
/// and a trivially fake-able one for tests, rather than reaching for
/// `image_picker_platform_interface`'s own (heavier) test-fake convention.
///
/// Implementations: [ImagePickerDocumentPicker] (real) and
/// `FakeDocumentImagePicker` (returns a real-but-generated temp image file,
/// no platform channel/IO device chooser). The composition root in
/// `lib/app/di.dart` picks one from `Env.useFakeBackend`.
abstract interface class DocumentImagePicker {
  /// Opens the gallery chooser and returns the picked file, or `null` if the
  /// user cancelled without picking anything.
  Future<File?> pickImage();
}

/// `image_picker`-backed implementation.
class ImagePickerDocumentPicker implements DocumentImagePicker {
  ImagePickerDocumentPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<File?> pickImage() async {
    // Gallery, not camera: a driver uploading an existing photo of their
    // license/truck is the common case, and it works in a simulator/desktop
    // dev build with no camera hardware. imageQuality/maxWidth keep the
    // upload small without a separate compression step.
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    return picked == null ? null : File(picked.path);
  }
}
