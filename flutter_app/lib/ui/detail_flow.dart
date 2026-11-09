import 'package:flutter/material.dart';

/// A single adaptive surface owns a sequence of details. Child details replace
/// its body instead of piling a second blurred dialog on top of the first.
Future<T?> showFlexDetail<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) {
  final flow = DetailFlowScope.maybeOf(context);
  if (flow != null) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        builder: (ctx) =>
            DetailFlowScope(depth: flow.depth + 1, child: builder(ctx)),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => _DetailFlow<T>(builder: builder),
  );
}

class DetailFlowScope extends InheritedWidget {
  const DetailFlowScope({super.key, required this.depth, required super.child});
  final int depth;
  static DetailFlowScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DetailFlowScope>();
  @override
  bool updateShouldNotify(DetailFlowScope oldWidget) =>
      depth != oldWidget.depth;
}

class _DetailFlow<T> extends StatefulWidget {
  const _DetailFlow({required this.builder});
  final WidgetBuilder builder;
  @override
  State<_DetailFlow<T>> createState() => _DetailFlowState<T>();
}

class _DetailFlowState<T> extends State<_DetailFlow<T>> {
  final navigator = GlobalKey<NavigatorState>();
  bool closing = false;

  Future<void> finish(T? value) async {
    if (closing) return;
    closing = true;
    // Let the nested route finish its pop before removing the host route.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent == true) {
      Navigator.of(context).pop(value);
    } else if (route != null) {
      Navigator.of(context).removeRoute(route, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 700;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Dialog(
          insetPadding: EdgeInsets.all(phone ? 0 : 20),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(phone ? 0 : 24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: NavigatorPopHandler<T>(
              onPopWithResult: (_) => navigator.currentState?.maybePop(),
              child: Navigator(
                key: navigator,
                onGenerateInitialRoutes: (_, _) {
                  final first = MaterialPageRoute<T>(
                    builder: (ctx) =>
                        DetailFlowScope(depth: 0, child: widget.builder(ctx)),
                  );
                  first.popped.then(finish);
                  // A base route lets existing editor Navigator.pop calls return
                  // their result without ever popping the last navigator page.
                  return [
                    MaterialPageRoute<void>(
                      builder: (_) => const SizedBox.expand(),
                    ),
                    first,
                  ];
                },
                onGenerateRoute: (_) => null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
