import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:share_plus/share_plus.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import 'material_files.dart';

class SharedDocument {
  const SharedDocument(this.name, this.bytes, this.mime);
  final String name, mime;
  final Uint8List bytes;
}

String materialMime(String extension) => switch (extension.toLowerCase()) {
  'pdf' => 'application/pdf',
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'docx' =>
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  _ => 'application/octet-stream',
};

Future<List<SharedDocument>> prepareMaterialShare(
  Iterable<ClassroomDocument> documents,
  MaterialFiles files,
) async {
  final result = <SharedDocument>[];
  var size = 0;
  for (final d in documents) {
    final key = d.text('localKey');
    if (key.isEmpty || !await files.exists(key)) {
      throw DomainError(
        '„${d.title}“ ist nicht offline verfügbar. Bitte zuerst herunterladen.',
      );
    }
    final bytes = await files.read(key);
    size += bytes.length;
    if (bytes.isEmpty || size > 100000000 || result.length >= 50) {
      throw const DomainError(
        'Bitte bis zu 50 Dateien mit zusammen höchstens 100 MB teilen.',
      );
    }
    result.add(
      SharedDocument(
        d.text('name', '${d.title}.${d.text('extension')}'),
        bytes,
        materialMime(d.text('extension')),
      ),
    );
  }
  return result;
}

ShareParams documentShareParams(
  List<SharedDocument> documents, {
  Rect? origin,
}) {
  if (documents.isEmpty ||
      documents.length > 50 ||
      documents.fold<int>(0, (n, d) => n + d.bytes.length) > 100000000 ||
      documents.any((d) => d.bytes.isEmpty)) {
    throw const DomainError(
      'Bitte 1–50 Dateien mit zusammen höchstens 100 MB auswählen.',
    );
  }
  final used = <String>{};
  final names = <String>[];
  for (final d in documents) {
    var name = d.name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
    if (name.isEmpty) name = 'Dokument';
    if (name.length > 190) name = name.substring(name.length - 190);
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final suffix = dot > 0 ? name.substring(dot) : '';
    var count = 1;
    while (!used.add(name.toLowerCase())) {
      name = '$stem (${++count})$suffix';
    }
    names.add(name);
  }
  return ShareParams(
    title: documents.length == 1 ? names.single : '${documents.length} Dateien',
    files: [
      for (final d in documents) XFile.fromData(d.bytes, mimeType: d.mime),
    ],
    fileNameOverrides: names,
    sharePositionOrigin: origin,
  );
}

Future<ShareResult> shareDocuments(
  List<SharedDocument> documents, {
  Rect? origin,
}) => SharePlus.instance.share(documentShareParams(documents, origin: origin));
