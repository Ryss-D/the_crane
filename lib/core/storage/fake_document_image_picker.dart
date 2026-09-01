import 'dart:convert';
import 'dart:io';

import 'document_image_picker.dart';

/// In-memory stand-in for [DocumentImagePicker] -- no real platform channel
/// or device chooser UI. Writes a tiny, real, valid image to a temp file so
/// `Image.file` can actually decode a thumbnail in widget tests, the same
/// way a real pick would.
class FakeDocumentImagePicker implements DocumentImagePicker {
  FakeDocumentImagePicker({this.delay = Duration.zero});

  final Duration delay;

  /// Test hook: when true, the *next* [pickImage] call returns `null` (user
  /// backed out of the chooser) instead of a file, then resets to false.
  bool cancelNext = false;

  /// Test hook: when set, the *next* [pickImage] call throws this instead of
  /// returning a file, then resets to null -- lets a widget test exercise
  /// the "picker itself failed" path distinctly from an upload failure.
  Object? throwNext;

  int _seq = 0;

  @override
  Future<File?> pickImage() async {
    await Future<void>.delayed(delay);
    final error = throwNext;
    if (error != null) {
      throwNext = null;
      throw error;
    }
    if (cancelNext) {
      cancelNext = false;
      return null;
    }
    final file = File(
      '${Directory.systemTemp.path}/fake_document_picker_${++_seq}.png',
    );
    // Sync write deliberately: widget tests run inside a FakeAsync zone
    // (see the FLT-4 invite tests further down this file's own comments for
    // the same gotcha) where real dart:io *async* I/O never completes
    // without `tester.runAsync` -- a sync write sidesteps that entirely.
    file.writeAsBytesSync(_tinyPng, flush: true);
    return file;
  }
}

/// A minimal, valid 1x1 transparent PNG -- real enough for `Image.file` to
/// decode, without shipping a binary test-golden asset.
final List<int> _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);
