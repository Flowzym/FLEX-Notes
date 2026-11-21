import 'dart:typed_data';

bool get windowsAcquisitionAvailable => false;
Future<List<Uint8List>?> acquireWindowsPage(int limit) =>
    throw UnsupportedError('Windows-Bilderfassung');
Future<({Future<String> result, void Function() stop, void Function() cancel})>
startWindowsSpeech(String language) =>
    throw UnsupportedError('Windows-Spracherkennung');
