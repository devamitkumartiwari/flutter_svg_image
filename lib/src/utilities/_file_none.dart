import 'dart:typed_data';
import 'dart:async';

/// Fake File for Web
abstract class File {
  /// Get the path of the file.
  String get path;

  /// Reads the entire file contents as a list of bytes asynchronously.
  ///
  /// Returns a `Future<Uint8List>` that completes with the list of bytes that
  /// represents the contents of the file.
  FutureOr<Uint8List> readAsBytes();
}
