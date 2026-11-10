import 'package:flutter/material.dart';
import 'action_heading.dart';

/// Keeps the query when focus leaves; the compact button still shows the filter.
class CollapsibleSearch extends StatefulWidget {
  const CollapsibleSearch({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.label,
    required this.fieldKey,
    this.buttonKey,
    this.iconOnly = false,
    this.leading,
    this.actions = const [],
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String label;
  final Key fieldKey;
  final Key? buttonKey;
  final bool iconOnly;
  final Widget? leading;
  final List<Widget> actions;
  @override
  State<CollapsibleSearch> createState() => _CollapsibleSearchState();
}

class _CollapsibleSearchState extends State<CollapsibleSearch> {
  final focus = FocusNode();
  bool expanded = false;
  @override
  void initState() {
    super.initState();
    focus.addListener(focusChanged);
  }

  void focusChanged() {
    if (!focus.hasFocus && expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !focus.hasFocus) setState(() => expanded = false);
      });
    }
  }

  void open() {
    setState(() => expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && expanded) focus.requestFocus();
    });
  }

  void close() {
    focus.unfocus();
    setState(() => expanded = false);
  }

  void clear() {
    widget.controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  void dispose() {
    focus.removeListener(focusChanged);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.iconOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionHeading(
            leading: widget.leading ?? const SizedBox(),
            actions: [
              if (!expanded && widget.controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'Suchtext leeren',
                  onPressed: clear,
                  icon: const Icon(Icons.close, size: 20),
                ),
              IconButton.outlined(
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                key: widget.buttonKey,
                tooltip: widget.controller.text.isEmpty
                    ? widget.label
                    : '${widget.label}: ${widget.controller.text}',
                onPressed: expanded ? close : open,
                icon: Badge(
                  isLabelVisible: widget.controller.text.isNotEmpty,
                  child: const Icon(Icons.search),
                ),
              ),
              ...widget.actions,
            ],
          ),
          if (expanded) searchField(),
        ],
      );
    }
    if (!expanded) {
      return Row(
        children: [
          Flexible(
            child: Tooltip(
              message: widget.label,
              child: TextButton.icon(
                key: widget.buttonKey,
                onPressed: open,
                icon: const Icon(Icons.search, size: 20),
                label: Text(
                  widget.controller.text.isEmpty
                      ? widget.label
                      : 'Suche: ${widget.controller.text}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Suchtext leeren',
              onPressed: clear,
              icon: const Icon(Icons.close, size: 20),
            ),
        ],
      );
    }
    return searchField();
  }

  Widget searchField() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: TextField(
          key: widget.fieldKey,
          controller: widget.controller,
          focusNode: focus,
          textInputAction: TextInputAction.search,
          onTapOutside: (_) => close(),
          onSubmitted: (_) => close(),
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Suchtext leeren',
              onPressed: clear,
              icon: const Icon(Icons.close, size: 20),
            ),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Suche schließen',
        onPressed: close,
        icon: const Icon(Icons.keyboard_arrow_up),
      ),
    ],
  );
}
