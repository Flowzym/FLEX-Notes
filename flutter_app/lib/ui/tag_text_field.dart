import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Selected tags and free text share one input border. Removing a tag returns
/// focus to the free text; Backspace on empty text first focuses the last tag.
class TagTextField extends StatefulWidget {
  const TagTextField({
    super.key,
    required this.fieldKey,
    required this.value,
    required this.hint,
    required this.tags,
    required this.onChanged,
    this.minLines = 3,
    this.maxLength = 12000,
    this.semanticLabel,
  });
  final Key fieldKey;
  final String value, hint;
  final String? semanticLabel;
  final List<({String id, String label, VoidCallback remove})> tags;
  final ValueChanged<String> onChanged;
  final int minLines, maxLength;
  @override
  State<TagTextField> createState() => _TagTextFieldState();
}

class _TagTextFieldState extends State<TagTextField> {
  late final controller = TextEditingController(text: widget.value);
  final focus = FocusNode();
  final tagFocus = <String, FocusNode>{};
  @override
  void didUpdateWidget(covariant TagTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.value) controller.text = widget.value;
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    for (final node in tagFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            focus.hasFocus &&
            controller.text.isEmpty &&
            widget.tags.isNotEmpty) {
          tagFocus[widget.tags.last.id]?.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: focus,
        builder: (context, _) => DecoratedBox(
          key: ValueKey('tag-frame-${widget.fieldKey}'),
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focus.hasFocus ? scheme.primary : scheme.outline,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in widget.tags)
                        InputChip(
                          key: ValueKey('selected-${tag.id}'),
                          focusNode: tagFocus.putIfAbsent(
                            tag.id,
                            () => FocusNode(),
                          ),
                          label: Text(tag.label, softWrap: true),
                          deleteButtonTooltipMessage: '${tag.label} entfernen',
                          onDeleted: () {
                            tag.remove();
                            focus.requestFocus();
                          },
                        ),
                    ],
                  ),
                Semantics(
                  label: widget.semanticLabel,
                  child: TextFormField(
                    key: widget.fieldKey,
                    controller: controller,
                    focusNode: focus,
                    minLines: widget.minLines,
                    maxLines: 8,
                    maxLength: widget.maxLength,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: widget.onChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
