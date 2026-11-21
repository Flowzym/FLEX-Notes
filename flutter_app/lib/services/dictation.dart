import 'dart:async';
import 'windows_input.dart';
import '../domain/models.dart' show DomainError;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef DictationEvent = ({String state, String text});

abstract interface class DictationPort {
  Stream<DictationEvent> get events;
  Future<void> start(String language);
  Future<void> stop();
  Future<void> cancel();
}

class AndroidDictationPort implements DictationPort {
  AndroidDictationPort() {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'event' || call.arguments is! Map) return;
      final args = call.arguments as Map;
      if (_active && args['state'] is String && args['text'] is String) {
        _events.add((
          state: args['state'] as String,
          text: args['text'] as String,
        ));
      }
    });
  }
  static const channel = MethodChannel('at.flowzym.flex_notizbuch/dictation');
  final _events = StreamController<DictationEvent>.broadcast(sync: true);
  bool _active = false;
  @override
  Stream<DictationEvent> get events => _events.stream;
  @override
  Future<void> start(String language) async {
    _active = true;
    try {
      await channel.invokeMethod<void>('start', {'language': language});
    } catch (_) {
      _active = false;
      rethrow;
    }
  }

  @override
  Future<void> stop() => channel.invokeMethod<void>('stop');
  @override
  Future<void> cancel() async {
    _active = false;
    await channel.invokeMethod<void>('cancel');
  }
}

class WindowsDictationPort implements DictationPort {
  final _events = StreamController<DictationEvent>.broadcast();
  int generation = 0;
  void Function()? _stop, _cancel;
  @override
  Stream<DictationEvent> get events => _events.stream;
  @override
  Future<void> start(String language) async {
    await cancel();
    final token = generation;
    final speech = await startWindowsSpeech(language);
    if (token != generation) {
      speech.cancel();
      await speech.result.catchError((_) => '');
      return;
    }
    _stop = speech.stop;
    _cancel = speech.cancel;
    _events.add((state: 'listening', text: ''));
    unawaited(
      speech.result
          .then((text) {
            if (token == generation) {
              _events.add((
                state: text.isEmpty ? 'error' : 'final',
                text: text.isEmpty
                    ? 'Kein Text erkannt. Bitte erneut diktieren.'
                    : text,
              ));
            }
          })
          .catchError((Object e) {
            if (token == generation) {
              _events.add((
                state: 'error',
                text: e is DomainError
                    ? e.message
                    : 'Windows konnte das Diktat nicht abschließen.',
              ));
            }
          })
          .whenComplete(() {
            if (token == generation) {
              _stop = null;
              _cancel = null;
            }
          }),
    );
  }

  @override
  Future<void> stop() async => _stop?.call();
  @override
  Future<void> cancel() async {
    generation++;
    _cancel?.call();
    _stop = null;
    _cancel = null;
  }
}

bool get supportsDictation =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        windowsAcquisitionAvailable);
DictationPort? _port;
DictationPort get deviceDictation => _port ??= windowsAcquisitionAvailable
    ? WindowsDictationPort()
    : AndroidDictationPort();

/// Insertion keeps the selection and all surrounding text; limits are enforced
/// before mutation, never by silently truncating a pupil's existing note.
TextEditingValue insertDictation(
  TextEditingValue value,
  String text,
  int limit,
) {
  final selection = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);
  final start = selection.start.clamp(0, value.text.length);
  final end = selection.end.clamp(start, value.text.length);
  final before = value.text.substring(0, start),
      after = value.text.substring(end);
  final insertion =
      '${before.isNotEmpty && !RegExp(r'\s$').hasMatch(before) ? ' ' : ''}${text.trim()}${after.isNotEmpty && !RegExp(r'^\s').hasMatch(after) ? ' ' : ''}';
  final next = '$before$insertion$after';
  if (next.runes.length > limit) {
    throw const FormatException(
      'Der Text ist zu lang. Bitte das Diktat kürzen.',
    );
  }
  return TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: start + insertion.length),
  );
}
