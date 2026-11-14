import 'dart:async';
import 'package:flex_device/flex_device.dart';
import 'package:flutter/foundation.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import 'material_files.dart';
import 'material_storage.dart';
import 'scan_images.dart';

abstract interface class IncomingSharePort {
  Future<Json> pending();
  Future<void> discard(List<String> ids);
  Future<void> clearError();
}

class DeviceIncomingSharePort implements IncomingSharePort {
  const DeviceIncomingSharePort();
  @override
  Future<Json> pending() async => Json.from(
    (await FlexDevice.channel.invokeMapMethod<String, dynamic>(
      'pendingShares',
    ))!,
  );
  @override
  Future<void> discard(List<String> ids) =>
      FlexDevice.channel.invokeMethod('discardShares', {'ids': ids});
  @override
  Future<void> clearError() =>
      FlexDevice.channel.invokeMethod('clearShareError');
}

class SharedDocument {
  SharedDocument.fromJson(Json value)
    : id = value['id'] as String,
      key = value['key'] as String,
      name = value['name'] as String,
      kind = value['kind'] as String,
      size = value['size'] as int {
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) ||
        key != 'incoming_$id' ||
        name.isEmpty ||
        name.length > 150 ||
        !{'pdf', 'docx', 'image'}.contains(kind) ||
        size < 1 ||
        size > 20000000) {
      throw const DomainError('Ungültige geteilte Datei.');
    }
  }
  final String id, key, name, kind;
  final int size;
  String get extension => kind == 'image' ? 'jpg' : kind;
  ClassroomDocument preview() => ClassroomDocument.create(
    ClassroomKind.material,
    name,
    {'localKey': key, 'extension': extension},
    id: id,
  );
}

class IncomingShares extends ChangeNotifier {
  IncomingShares({
    this.port = const DeviceIncomingSharePort(),
    this.files = const LocalMaterialFiles(),
  });
  final IncomingSharePort port;
  final MaterialFiles files;
  List<SharedDocument> items = [];
  String? error;
  Future<void>? _refreshing;
  bool busy = false, presenting = false;
  void listen() {
    FlexDevice.channel.setMethodCallHandler((call) async {
      if (call.method == 'incomingSharesChanged') await refresh();
    });
  }

  Future<void> refresh() =>
      _refreshing ??= _load().whenComplete(() => _refreshing = null);
  Future<void> _load() async {
    try {
      final value = await port.pending();
      final loaded = (value['items'] as List)
          .map((v) => SharedDocument.fromJson(Json.from(v as Map)))
          .toList();
      if (loaded.length > 20 ||
          loaded.fold<int>(0, (sum, d) => sum + d.size) > 100000000 ||
          loaded.map((d) => d.id).toSet().length != loaded.length) {
        throw const FormatException();
      }
      items = loaded;
      error = (value['error'] as String?)?.isNotEmpty == true
          ? value['error'] as String
          : null;
    } catch (_) {
      error =
          'Der Dateieingang konnte nicht geöffnet werden. Bitte erneut versuchen.';
    }
    notifyListeners();
  }

  Future<void> discard(List<String> ids) async {
    await port.discard(ids);
    await refresh();
  }

  Future<void> clearError() async {
    await port.clearError();
    await refresh();
  }

  MaterialFiles get previewFiles => _IncomingFiles(this);
  Future<Uint8List> read(SharedDocument item) async {
    final raw = await files.read(item.key);
    if (raw.length != item.size) {
      throw const DomainError(
        'Die geteilte Datei hat sich verändert. Bitte erneut teilen.',
      );
    }
    if (item.kind == 'image') {
      return (await compute(normalizeScan, raw))['bytes'] as Uint8List;
    }
    validateMaterialBytes(raw, item.extension);
    return raw;
  }

  /// Stable document IDs make retry after a saved batch / failed acknowledgement
  /// idempotent. Byte writes are rolled back only before the DB transaction wins.
  Future<void> accept(
    NotebookRepository repository,
    Set<String> selected, {
    Map<String, String> names = const {},
    List<String> pupils = const [],
    List<String> lessons = const [],
    String category = 'other',
    String? date,
  }) async {
    if (busy) return;
    busy = true;
    notifyListeners();
    final created = <String>[];
    var committed = false;
    try {
      final documents = await repository.classroomDocuments();
      final chosen = items.where((d) => selected.contains(d.id)).toList();
      if (chosen.isEmpty || chosen.length != selected.length) {
        throw const DomainError('Bitte Dateien auswählen.');
      }
      final additions = <ClassroomDocument>[];
      for (final item in chosen) {
        final existing = documents.where((d) => d.id == item.id).firstOrNull;
        if (existing != null) {
          if (existing.kind != ClassroomKind.material) {
            throw const StaleRevision();
          }
          continue;
        }
        final bytes = await read(item);
        var key = 'received_${item.id}';
        if (await files.exists(key) &&
            !listEquals(await files.read(key), bytes)) {
          key = newId();
        }
        final title = (names[item.id] ?? item.name).trim();
        if (title.isEmpty || title.length > 150) {
          throw const DomainError(
            'Bitte einen Dateinamen bis 150 Zeichen eingeben.',
          );
        }
        final doc = ClassroomDocument.create(ClassroomKind.material, title, {
          'localKey': key,
          'name':
              '${title.replaceAll(RegExp(r'\.(pdf|docx|jpe?g|png|webp)$', caseSensitive: false), '').replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')}.${item.extension}',
          'extension': item.extension,
          'size': bytes.length,
          'documentType': category,
          'pupilIds': pupils,
          if (date != null)
            'pupilDates': [
              for (final pupil in pupils) {'pupilId': pupil, 'date': date},
            ],
          'sourcePath': 'Android – Geteilte Dateien',
          'sourceModifiedAt': utcNow(),
        }, id: item.id);
        // An interrupted pre-commit write is owned by this stable incoming ID.
        if (!await files.exists(key)) {
          created.add(key);
          await files.write(key, bytes);
          if (!listEquals(await files.read(key), bytes)) {
            throw const DomainError(
              'Die Datei konnte nicht vollständig gespeichert werden.',
            );
          }
        }
        additions.add(doc);
      }
      for (final id in lessons) {
        final lesson = documents
            .where(
              (d) => d.id == id && !d.deleted && d.kind == ClassroomKind.lesson,
            )
            .firstOrNull;
        if (lesson == null) {
          throw const DomainError(
            'Der gewählte Unterricht ist nicht mehr verfügbar.',
          );
        }
        additions.add(
          lesson.patch({
            'materialIds': {
              ...lesson.strings('materialIds'),
              ...selected.where(
                (id) => !documents.any((d) => d.id == id && d.deleted),
              ),
            }.toList(),
          }),
        );
      }
      if (additions.isNotEmpty) {
        await repository.saveClassroomDocuments(additions);
      }
      committed = true;
      await port.discard(chosen.map((d) => d.id).toList());
      await refresh();
    } catch (_) {
      if (!committed) {
        for (final key in created) {
          try {
            await files.remove(key);
          } catch (_) {}
        }
      }
      if (committed) {
        throw const DomainError(
          'Die Dateien sind gespeichert. Der Eingang konnte noch nicht bereinigt werden. Erneutes Übernehmen erzeugt keine Duplikate.',
        );
      }
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class _IncomingFiles implements MaterialFiles {
  _IncomingFiles(this.incoming);
  final IncomingShares incoming;
  // Thumbnail requests may arrive together. Decode one full image at a time.
  static Future<void> _queue = Future.value();
  @override
  Future<Uint8List> read(String key) {
    final result = _queue.then(
      (_) => incoming.read(incoming.items.firstWhere((d) => d.key == key)),
    );
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<bool> exists(String key) => incoming.files.exists(key);
  @override
  Future<void> write(String key, Uint8List bytes) =>
      throw UnsupportedError('Read-only incoming files');
  @override
  Future<void> remove(String key) =>
      throw UnsupportedError('Read-only incoming files');
}
