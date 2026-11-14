import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Blob parts live in the browser, not a second complete Dart byte buffer.
/// Browsers may still buffer downloads; this is not a constant-memory promise.
Future<bool> saveBackupStream(String name, Stream<List<int>> stream) async {
  final parts = <JSAny>[];
  await for (final chunk in stream) {
    parts.add((chunk is Uint8List ? chunk : Uint8List.fromList(chunk)).toJS);
  }
  final blob = web.Blob(
    parts.toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(link);
  link.click();
  link.remove();
  // Give the browser time to claim the generated download.
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => web.URL.revokeObjectURL(url),
  );
  return true;
}
