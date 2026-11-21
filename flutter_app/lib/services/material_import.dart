import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import '../domain/classroom.dart';
import '../domain/material_workspace.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import 'material_files.dart';
import 'material_index.dart';

Future<List<ClassroomDocument>> importLocalMaterials(
  List<XFile> selected,
  NotebookRepository repository,
  MaterialFiles files, {
  String? pupilId,
}) async {
  if (selected.length > 25) {
    throw const DomainError('Bitte höchstens 25 Dateien auswählen.');
  }
  final documents = <ClassroomDocument>[], keys = <String>[];
  var total = 0;
  try {
    for (final file in selected) {
      final length = await file.length();
      if (length > 20000000) {
        throw DomainError('${file.name} überschreitet 20 MB.');
      }
      if (total + length > 100000000) {
        throw const DomainError('Die Auswahl überschreitet 100 MB.');
      }
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in file.openRead()) {
        if (buffer.length + chunk.length > 20000000) {
          throw DomainError('${file.name} überschreitet 20 MB.');
        }
        total += chunk.length;
        if (total > 100000000) {
          throw const DomainError('Die Auswahl überschreitet 100 MB.');
        }
        buffer.add(chunk);
      }
      final data = buffer.takeBytes(), ext = cloudExtension(file.name);
      validateMaterialBytes(data, ext);
      final key = newId();
      documents.add(
        ClassroomDocument.create(ClassroomKind.material, file.name, {
          if (pupilId != null) 'pupilIds': [pupilId],
          'localKey': key,
          'name': file.name,
          'extension': ext,
          'size': data.length,
          'sourceModifiedAt': utcNow(),
          ...suggestMaterialMetadata(file.name),
        }),
      );
      keys.add(key);
      await files.write(key, data);
    }
    if (documents.isNotEmpty) {
      await repository.saveClassroomDocuments(documents);
    }
  } catch (_) {
    await Future.wait(keys.map(files.remove));
    rethrow;
  }
  return documents;
}
