part of 'design.dart';

Widget desktopFormFrame(BuildContext context, FlexModal form, bool embedded) {
  final header = Container(
    key: const ValueKey('desktop-form-header'),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: const BoxDecoration(
      color: white,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child:
        form.headerContent ??
        Row(
          children: [
            Expanded(
              child: DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.titleLarge,
                child: form.title,
              ),
            ),
            ...form.headerActions,
            if (form.onClose != null)
              IconButton(
                tooltip: form.closeLabel,
                onPressed: form.onClose,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
  );
  final body = Padding(
    padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
    child: form.content,
  );
  final footer = form.actions.isEmpty && form.footerContent == null
      ? null
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          width: double.infinity,
          decoration: const BoxDecoration(
            color: paper,
            border: Border(top: BorderSide(color: line)),
          ),
          child:
              form.footerContent ??
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: form.actions,
              ),
        );
  final content = Material(
    color: white,
    child: LayoutBuilder(
      builder: (context, box) {
        if (box.maxHeight < 425 && form.scrollable) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, body, ?footer],
            ),
          );
        }
        return Column(
          mainAxisSize: embedded ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Flexible(
              fit: embedded ? FlexFit.tight : FlexFit.loose,
              child: form.scrollable
                  ? SingleChildScrollView(child: body)
                  : body,
            ),
            ?footer,
          ],
        );
      },
    ),
  );
  if (embedded) return content;
  return Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: form.headerContent != null ? 1000 : form.maxWidth,
        maxHeight: 850,
      ),
      child: content,
    ),
  );
}
