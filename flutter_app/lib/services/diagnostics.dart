import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import 'material_files.dart';

enum DiagnosticArea {
  startup,
  interface,
  storage,
  backup,
  scanner,
  reminders,
  sharing,
}

/// An allowlist, not a redactor: no exception messages, record values, device
/// identifiers, URLs or filesystem paths ever enter the log.
class DiagnosticLog extends ChangeNotifier {
  DiagnosticLog({DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  static const key = 'flex-local-diagnostics-v1';
  static const capacity = 100;
  static const retention = Duration(days: 14);
  MaterialFiles? _files;
  final List<Json> _events = [];
  Future<void> _writes = Future.value();
  List<Json> get events => _events.map(Json.from).toList(growable: false);

  static final _frame = RegExp(
    r'package:flex_notizbuch/[a-zA-Z0-9_/.-]+\.dart:\d+:\d+',
  );
  static const _types = {
    'validation',
    'platform',
    'format',
    'state',
    'unexpected',
  };

  Future<void> initialize(MaterialFiles files) async {
    _files = files;
    try {
      if (await files.exists(key)) {
        final bytes = await files.read(key);
        if (bytes.length <= 65536) {
          final data = jsonDecode(utf8.decode(bytes));
          if (data is List) {
            for (final value in data.take(capacity)) {
              if (value is! Map ||
                  !DiagnosticArea.values.any((a) => a.name == value['area']) ||
                  !_types.contains(value['type'])) {
                continue;
              }
              final stamp = DateTime.tryParse(
                value['time'] is String ? value['time'] as String : '',
              );
              if (stamp == null) continue;
              _events.add({
                'time': stamp.toUtc().toIso8601String(),
                'area': value['area'],
                'type': value['type'],
                'frames': [
                  for (final frame
                      in (value['frames'] is List
                              ? value['frames'] as List
                              : [])
                          .take(4))
                    if (frame is String && _frame.stringMatch(frame) == frame)
                      frame,
                ],
              });
            }
          }
        }
      }
      _rotate();
      await _persist();
    } catch (_) {
      /* Diagnostics must never prevent opening the notebook. */
    }
  }

  void _rotate() {
    final cutoff = clock().toUtc().subtract(retention);
    _events.removeWhere(
      (e) => DateTime.parse(e['time'] as String).isBefore(cutoff),
    );
    if (_events.length > capacity) {
      _events.removeRange(0, _events.length - capacity);
    }
  }

  Future<void> capture(
    Object error,
    StackTrace stack, {
    DiagnosticArea area = DiagnosticArea.interface,
  }) {
    _events.add({
      'time': clock().toUtc().toIso8601String(),
      'area': area.name,
      'type': error is DomainError
          ? 'validation'
          : error is FormatException
          ? 'format'
          : error is StateError
          ? 'state'
          : 'unexpected',
      'frames': _frame
          .allMatches(stack.toString())
          .take(4)
          .map((m) => m.group(0)!)
          .toList(),
    });
    _rotate();
    notifyListeners();
    return _persist();
  }

  Future<void> _persist() {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(_events)));
    _writes = _writes.then((_) async {
      try {
        await _files?.write(key, bytes);
      } catch (_) {
        /* Keep the in-memory report. */
      }
    });
    return _writes;
  }

  Future<void> clear() async {
    _events.clear();
    notifyListeners();
    await _persist();
  }

  String report() {
    _rotate();
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'FLEX-Diagnostic-1',
      'appVersion': '0.30.0+80',
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'createdAtUtc': clock().toUtc().toIso8601String(),
      'events': events,
    });
  }
}

final diagnostics = DiagnosticLog();
