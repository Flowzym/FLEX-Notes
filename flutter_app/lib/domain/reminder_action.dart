import 'dart:convert';
import 'models.dart';

class ReminderAction {
  const ReminderAction({
    required this.target,
    required this.revision,
    required this.scheduledAt,
    this.action = 'open',
  });
  final String target, scheduledAt, action;
  final int revision;
  String encode() => jsonEncode({
    'v': 1,
    'target': target,
    'revision': revision,
    'at': scheduledAt,
    'action': action,
  });
  static ReminderAction? parse(String payload) {
    if (!payload.startsWith('{')) return null;
    try {
      final j = jsonDecode(payload) as Map;
      if (j['v'] != 1 ||
          j['target'] is! String ||
          j['revision'] is! int ||
          j['at'] is! String ||
          !{'open', 'done', 'snooze'}.contains(j['action'])) {
        return null;
      }
      final target = j['target'] as String;
      if (!RegExp(
            r'^(orga|school|return|lesson):[a-zA-Z0-9:_\-]{1,160}$',
          ).hasMatch(target) ||
          j['revision'] < 0 ||
          DateTime.tryParse(j['at']) == null) {
        return null;
      }
      return ReminderAction(
        target: target,
        revision: j['revision'],
        scheduledAt: j['at'],
        action: j['action'],
      );
    } catch (_) {
      return null;
    }
  }

  static String response(String payload, String? action) {
    final parsed = parse(payload);
    if (parsed == null) return payload;
    return ReminderAction(
      target: parsed.target,
      revision: parsed.revision,
      scheduledAt: parsed.scheduledAt,
      action: {'done', 'snooze'}.contains(action) ? action! : 'open',
    ).encode();
  }

  void validate() {
    if (parse(encode()) == null || action == 'open') {
      throw const DomainError(
        'Diese Benachrichtigungsaktion ist nicht gültig.',
      );
    }
  }
}
