import 'detail_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/models.dart';
import 'surfaces.dart';
import 'common.dart';
part 'flex_date_picker.dart';

/// Desktop hosts supply their own window frame around the same editor fields.
class FlexDialogPresentation extends ThemeExtension<FlexDialogPresentation> {
  const FlexDialogPresentation(this.frame);
  final Widget Function(BuildContext, FlexModal, bool embedded) frame;
  @override
  FlexDialogPresentation copyWith() => this;
  @override
  FlexDialogPresentation lerp(
    ThemeExtension<FlexDialogPresentation>? other,
    double t,
  ) => t < .5 ? this : other as FlexDialogPresentation? ?? this;
}

/// The narrow form keeps its reading order. On a desktop the related people,
/// documents and timing controls can sit beside the editor.
class EntryFormSections extends StatelessWidget {
  const EntryFormSections({
    super.key,
    required this.primary,
    required this.details,
  });
  final List<Widget> primary, details;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      Widget column(List<Widget> items) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      );
      if (Theme.of(context).extension<FlexDialogPresentation>() == null ||
          box.maxWidth < 780 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.4) {
        return column([...primary, ...details]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: column(primary)),
          const SizedBox(width: 24),
          Expanded(
            flex: 4,
            child: Material(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerLow.withValues(alpha: .60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: column(details),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Shared shell for entry editors, secondary dialogs and confirmations.
class FlexModal extends StatelessWidget {
  const FlexModal({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.headerActions = const [],
    this.onClose,
    this.closeLabel = 'Schließen',
    this.scrollable = true,
    this.embedded = false,
    this.maxWidth = 640,
    this.headerContent,
    this.footerContent,
  });
  final Widget title, content;
  final String closeLabel;
  final Widget? headerContent, footerContent;
  final List<Widget> actions, headerActions;
  final VoidCallback? onClose;
  final bool scrollable, embedded;
  final double maxWidth;
  @override
  Widget build(BuildContext context) {
    final presentation = Theme.of(context).extension<FlexDialogPresentation>();
    if (presentation != null) {
      return presentation.frame(
        context,
        this,
        embedded || DetailFlowScope.maybeOf(context) != null,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final mobile = MediaQuery.sizeOf(context).width <= 700;
    final surfaces = Theme.of(context).extension<FlexSurfaces>();
    final footerColor = surfaces?.palette.backdrop ?? scheme.surface;
    final footerForeground = scheme.onSurface;
    final baseTheme = Theme.of(context);
    final dialog = Dialog(
      insetPadding: EdgeInsets.all(mobile ? 10 : 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlexDesign.modalRadius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Theme(
        data: baseTheme,
        child: ConstrainedBox(
          key: const ValueKey('flex-modal-frame'),
          constraints: BoxConstraints(
            maxWidth: DetailFlowScope.maybeOf(context) == null
                ? maxWidth
                : double.infinity,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 440;
              final header = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mobile &&
                      DetailFlowScope.maybeOf(context) != null &&
                      !compact)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        'FLEX.',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: .5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Container(
                    key: const ValueKey('modal-header'),
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 16 : 24,
                      4,
                      mobile ? 12 : 18,
                      4,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: IconTheme.merge(
                        data: IconThemeData(color: scheme.primary),
                        child: headerContent != null
                            ? DefaultTextStyle.merge(
                                style: TextStyle(color: scheme.onSurface),
                                child: headerContent!,
                              )
                            : Row(
                                children: [
                                  if ((DetailFlowScope.maybeOf(
                                            context,
                                          )?.depth ??
                                          0) >
                                      0)
                                    IconButton(
                                      tooltip: 'Zurück',
                                      onPressed: onClose,
                                      icon: const Icon(Icons.arrow_back),
                                    ),
                                  Expanded(
                                    child: DefaultTextStyle(
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge!
                                          .copyWith(color: scheme.onSurface),
                                      child: title,
                                    ),
                                  ),
                                  ...headerActions,
                                  if (onClose != null &&
                                      (DetailFlowScope.maybeOf(
                                                context,
                                              )?.depth ??
                                              0) ==
                                          0)
                                    IconButton(
                                      tooltip: closeLabel,
                                      onPressed: onClose,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              );
              final footer = Container(
                key: const ValueKey('modal-footer'),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: footerColor,
                  border: Border(
                    top: BorderSide(color: scheme.outlineVariant, width: .8),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 16 : 24,
                  vertical: compact
                      ? 8
                      : mobile
                      ? 7
                      : 8,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          alignment: Alignment.center,
                          foregroundBuilder: centeredButtonLabel,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              FlexDesign.buttonRadius,
                            ),
                          ),
                          backgroundColor: scheme.surface,
                          foregroundColor: footerForeground,
                          side: BorderSide(color: scheme.outlineVariant),
                          textStyle: const TextStyle(
                            fontFamily: 'FlexSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      outlinedButtonTheme: OutlinedButtonThemeData(
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.center,
                          foregroundBuilder: centeredButtonLabel,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              FlexDesign.buttonRadius,
                            ),
                          ),
                          backgroundColor: scheme.surface,
                          foregroundColor: footerForeground,
                          side: BorderSide(color: scheme.outlineVariant),
                          textStyle: const TextStyle(
                            fontFamily: 'FlexSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: footerForeground,
                        fontSize: 11,
                        height: 1.3,
                      ),
                      child:
                          footerContent ??
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: actions,
                          ),
                    ),
                  ),
                ),
              );
              final body = Padding(
                padding: EdgeInsets.fromLTRB(
                  mobile ? 16 : 24,
                  6,
                  mobile ? 16 : 24,
                  compact ? 10 : 16,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: SizedBox(width: double.infinity, child: content),
                  ),
                ),
              );
              // With large type or a keyboard the complete dialog must scroll;
              // fixed header/footer otherwise consume the available height.
              final layout = _ModalSections(
                expandBody:
                    embedded || DetailFlowScope.maybeOf(context) != null,
                scrollAll:
                    constraints.maxHeight < 520 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.5,
                scrollBody: scrollable,
                header: header,
                body: body,
                footer: actions.isNotEmpty || footerContent != null
                    ? footer
                    : null,
              );
              final surface = Material(
                key: const ValueKey('modal-surface'),
                type: MaterialType.transparency,
                child: layout,
              );
              return FlexBackground(child: surface);
            },
          ),
        ),
      ),
    );
    if (embedded || DetailFlowScope.maybeOf(context) != null) {
      return dialog.child!;
    }
    return dialog;
  }
}

/// The IME changes the available height while an input is focused. Reparent
/// the existing sections when switching scroll layouts, keeping EditableText,
/// its FocusNode and its platform input connection alive throughout animation.
class _ModalSections extends StatefulWidget {
  const _ModalSections({
    required this.scrollAll,
    required this.expandBody,
    required this.scrollBody,
    required this.header,
    required this.body,
    required this.footer,
  });
  final bool scrollAll, scrollBody, expandBody;
  final Widget header, body;
  final Widget? footer;

  @override
  State<_ModalSections> createState() => _ModalSectionsState();
}

class _ModalSectionsState extends State<_ModalSections> {
  final _headerKey = GlobalKey();
  final _bodyKey = GlobalKey();
  final _footerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final header = KeyedSubtree(key: _headerKey, child: widget.header);
    final body = KeyedSubtree(key: _bodyKey, child: widget.body);
    final footer = widget.footer == null
        ? null
        : KeyedSubtree(key: _footerKey, child: widget.footer!);
    if (widget.scrollAll) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [header, body, ?footer],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        Flexible(
          fit: widget.expandBody ? FlexFit.tight : FlexFit.loose,
          child: widget.scrollBody ? SingleChildScrollView(child: body) : body,
        ),
        ?footer,
      ],
    );
  }
}

Future<bool> confirmFlex(
  BuildContext context,
  String title,
  String message, {
  String accept = 'Bestätigen',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => FlexModal(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accept),
          ),
        ],
      ),
    ) ??
    false;

Future<(String, String)?> pickFlexDate(
  BuildContext context, {
  required String date,
  String time = '',
  bool allowTime = true,
  bool requireTime = false,
  bool allowDateClear = true,
  String? title,
}) async {
  return showDialog<(String, String)>(
    context: context,
    builder: (_) => _FlexDatePicker(
      date: date,
      time: time,
      allowTime: allowTime,
      requireTime: requireTime,
      allowDateClear: allowDateClear,
      title: title ?? (allowTime ? 'Datum & Uhrzeit' : 'Datum wählen'),
    ),
  );
}
