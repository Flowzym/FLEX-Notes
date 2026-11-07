import 'surfaces.dart';
import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../domain/school.dart';

/// One task editor for individual and group homework. Local values also cover
/// Enter submitted before the parent rebuilds after the last keystroke.
class HomeworkTaskEditor extends StatefulWidget {
  const HomeworkTaskEditor({
    super.key,
    required this.tasks,
    required this.onChanged,
    this.attachmentBuilder,
    this.attachmentActionsBuilder,
  });
  final List<HomeworkTask> tasks;
  final ValueChanged<List<HomeworkTask>> onChanged;
  final Widget Function(HomeworkTask)? attachmentBuilder;
  final Widget Function(HomeworkTask)? attachmentActionsBuilder;
  @override
  State<HomeworkTaskEditor> createState() => _HomeworkTaskEditorState();
}

class _HomeworkTaskEditorState extends State<HomeworkTaskEditor> {
  late List<HomeworkTask> tasks = widget.tasks;
  final taskFocus = <String, FocusNode>{};
  @override
  void didUpdateWidget(covariant HomeworkTaskEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    tasks = widget.tasks;
  }

  @override
  void dispose() {
    for (final node in taskFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void change(List<HomeworkTask> next) {
    setState(() => tasks = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final parents = tasks.where((task) => task.parentId == null).toList();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Aufgaben'),
        const SizedBox(height: 8),
        Container(
          key: const ValueKey('homework-task-list'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor,
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(
              Theme.of(
                    context,
                  ).extension<FlexSurfaces>()?.appearance?.fieldRadius ??
                  14,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final task in tasks)
                Padding(
                  key: ValueKey('homework-row-${task.id}'),
                  padding: EdgeInsets.only(
                    left: task.parentId == null ? 0 : 18,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: task == tasks.last
                            ? BorderSide.none
                            : BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                        left: task.parentId == null
                            ? BorderSide.none
                            : BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final inline =
                            constraints.maxWidth >= 440 &&
                            MediaQuery.textScalerOf(context).scale(1) < 1.4;
                        final field = Row(
                          children: [
                            SizedBox(
                              width: 20,
                              child: task.parentId == null
                                  ? Text(
                                      '${parents.indexOf(task) + 1}.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : Icon(
                                      Icons.subdirectory_arrow_right,
                                      size: 16,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Semantics(
                                label: task.parentId == null
                                    ? 'Aufgabe'
                                    : 'Teilaufgabe',
                                child: TextFormField(
                                  key: ValueKey('task-${task.id}'),
                                  focusNode: taskFocus.putIfAbsent(
                                    task.id,
                                    () => FocusNode(),
                                  ),
                                  initialValue: task.text,
                                  maxLength: 1000,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    hintText: task.parentId == null
                                        ? 'Aufgabe …'
                                        : 'Teilaufgabe …',
                                    counterText: '',
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 2,
                                    ),
                                    isDense: true,
                                  ),
                                  onChanged: (v) => change(
                                    tasks
                                        .map(
                                          (t) => t.id == task.id
                                              ? t.copyWith(text: v)
                                              : t,
                                        )
                                        .toList(),
                                  ),
                                  onFieldSubmitted: (_) => addTask(after: task),
                                ),
                              ),
                            ),
                          ],
                        );
                        final actions = Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            if (widget.attachmentActionsBuilder != null)
                              widget.attachmentActionsBuilder!(task),
                            IconButton(
                              key: ValueKey('task-next-${task.id}'),
                              tooltip: 'Weitere Aufgabenzeile',
                              onPressed: () => addTask(after: task),
                              icon: const Icon(Icons.keyboard_return),
                            ),
                            IconButton(
                              key: ValueKey('task-child-${task.id}'),
                              tooltip: 'Teilaufgabe hinzufügen',
                              onPressed: () => addTask(
                                parent: task.parentId ?? task.id,
                                after: task,
                              ),
                              icon: const Icon(Icons.subdirectory_arrow_right),
                            ),
                            IconButton(
                              key: ValueKey('task-remove-${task.id}'),
                              tooltip: 'Aufgabe entfernen',
                              onPressed: () => change(
                                tasks
                                    .where((t) => t.id != task.id)
                                    .map(
                                      (t) => t.copyWith(
                                        clearParent: t.parentId == task.id,
                                      ),
                                    )
                                    .toList(),
                              ),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        );
                        final tools = IconButtonTheme(
                          data: IconButtonThemeData(
                            style: IconButton.styleFrom(
                              minimumSize: const Size(36, 36),
                              maximumSize: const Size(40, 40),
                              padding: const EdgeInsets.all(7),
                              iconSize: 18,
                            ),
                          ),
                          child: actions,
                        );
                        final row = inline
                            ? Row(
                                children: [
                                  Expanded(child: field),
                                  tools,
                                ],
                              )
                            : Column(
                                children: [
                                  field,
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: tools,
                                  ),
                                ],
                              );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            row,
                            if (widget.attachmentBuilder != null)
                              widget.attachmentBuilder!(task),
                          ],
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: addTask,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Aufgabe hinzufügen'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  void addTask({String? parent, HomeworkTask? after}) {
    final next = [...tasks], id = newId();
    var index = after == null
        ? next.length
        : next.indexWhere((task) => task.id == after.id) + 1;
    if (after != null && parent == null) {
      while (index < next.length && next[index].parentId == after.id) {
        index++;
      }
    }
    next.insert(
      index,
      HomeworkTask(id: id, text: '', parentId: parent ?? after?.parentId),
    );
    change(next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) taskFocus[id]?.requestFocus();
    });
  }
}
