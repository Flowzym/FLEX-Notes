import 'package:flutter/services.dart';

class OrgaLine {
  const OrgaLine(
    this.type,
    this.indent,
    this.text,
    this.prefixLength, {
    this.number = 1,
  });
  final String type, indent, text;
  final int prefixLength, number;
  static OrgaLine parse(String value) {
    var m = RegExp(r'^(\s*)[-*] \[[ xX]\]\s?(.*)$').firstMatch(value);
    if (m != null) {
      return OrgaLine('check', m[1]!, m[2]!, value.length - m[2]!.length);
    }
    m = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$').firstMatch(value);
    if (m != null) {
      return OrgaLine(
        'number',
        m[1]!,
        m[3]!,
        value.length - m[3]!.length,
        number: int.tryParse(m[2]!) ?? 1,
      );
    }
    m = RegExp(r'^(\s*)[-*•]\s+(.*)$').firstMatch(value);
    if (m != null) {
      return OrgaLine('bullet', m[1]!, m[2]!, value.length - m[2]!.length);
    }
    return OrgaLine('text', '', value, 0);
  }
}

String _prefix(String type, int number, String indent) =>
    '$indent${type == 'number'
        ? '$number. '
        : type == 'check'
        ? '- [ ] '
        : '• '}';
String _renumberTail(String text, int position) {
  final lines = text.split('\n'),
      index = text.substring(0, position).split('\n').length - 1;
  final first = OrgaLine.parse(lines[index]);
  if (first.type != 'number') return text;
  var number = first.number;
  for (var i = index + 1; i < lines.length; i++) {
    final item = OrgaLine.parse(lines[i]);
    if (item.type != 'number') break;
    lines[i] = '${_prefix('number', ++number, item.indent)}${item.text}';
  }
  return lines.join('\n');
}

TextEditingValue styleOrgaLines(TextEditingValue value, String type) {
  final text = value.text;
  final selection = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: text.length);
  final start = selection.start, end = selection.end;
  final from = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final selectionEnd = end > start && text[end - 1] == '\n' ? end - 1 : end;
  final next = text.indexOf('\n', selectionEnd),
      to = next < 0 ? text.length : next;
  final lines = text.substring(from, to).split('\n'),
      parsed = lines.map(OrgaLine.parse).toList();
  final remove = parsed.every((line) => line.type == type);
  final before = OrgaLine.parse(
    text.substring(0, from > 0 ? from - 1 : 0).split('\n').last,
  );
  var number = before.type == 'number' ? before.number + 1 : 1;
  final changed = [
    for (final line in parsed)
      '${remove ? line.indent : _prefix(type, number++, line.indent)}${line.text}',
  ];
  final block = changed.join('\n'),
      delta = changed.first.length - lines.first.length;
  var result = text.replaceRange(from, to, block);
  if (type == 'number' && !remove) {
    result = _renumberTail(result, from + block.length);
  }
  final caret = (start + delta).clamp(from, from + changed.first.length);
  return TextEditingValue(
    text: result,
    selection: start == end
        ? TextSelection.collapsed(offset: caret)
        : TextSelection(baseOffset: from, extentOffset: from + block.length),
  );
}

TextEditingValue? continueOrgaLine(TextEditingValue value) {
  if (!value.selection.isValid || !value.composing.isCollapsed) return null;
  final text = value.text,
      start = value.selection.start,
      end = value.selection.end;
  final from = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final next = text.indexOf('\n', start), to = next < 0 ? text.length : next;
  final line = OrgaLine.parse(text.substring(from, to));
  if (line.type == 'text' || start < from + line.prefixLength) return null;
  if (line.text.trim().isEmpty) {
    return TextEditingValue(
      text: text.replaceRange(from, to, ''),
      selection: TextSelection.collapsed(offset: from),
    );
  }
  final prefix = _prefix(line.type, line.number + 1, line.indent);
  var result = text.replaceRange(start, end, '\n$prefix');
  final caret = start + 1 + prefix.length;
  if (line.type == 'number') result = _renumberTail(result, caret);
  return TextEditingValue(
    text: result,
    selection: TextSelection.collapsed(offset: caret),
  );
}

String meaningfulOrgaText(String text) => text
    .split('\n')
    .where((line) => OrgaLine.parse(line).text.trim().isNotEmpty)
    .join('\n');

/// IME keyboards insert a newline through editing values; physical Enter goes
/// through the same function in the editor. Pasting multiline text is untouched.
class OrgaListFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        !oldValue.selection.isValid ||
        !newValue.composing.isCollapsed ||
        !oldValue.composing.isCollapsed) {
      return newValue;
    }
    final selection = oldValue.selection;
    if (newValue.text ==
        oldValue.text.replaceRange(selection.start, selection.end, '\n')) {
      final continued = continueOrgaLine(oldValue);
      if (continued != null && continued.text.length <= 12000) return continued;
    }
    return newValue;
  }
}
