import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_lock.dart';

class AppGuard extends StatefulWidget {
  const AppGuard({
    super.key,
    required this.lock,
    required this.child,
    this.onResume,
  });
  final AppLock lock;
  final Widget child;
  final VoidCallback? onResume;
  @override
  State<AppGuard> createState() => _AppGuardState();
}

class _AppGuardState extends State<AppGuard> with WidgetsBindingObserver {
  final pin = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      widget.lock.lock(background: state != AppLifecycleState.inactive);
      pin.clear();
    }
    if (state == AppLifecycleState.resumed) widget.onResume?.call();
  }

  Future<void> unlock() async {
    final value = pin.text;
    pin.clear();
    await widget.lock.unlockPin(value);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.lock,
    builder: (context, _) {
      final lock = widget.lock;
      return Stack(
        children: [
          ExcludeFocus(
            excluding: lock.locked,
            child: Offstage(offstage: lock.locked, child: widget.child),
          ),
          if (lock.locked)
            Positioned.fill(
              child: Scaffold(
                body: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.lock_outline, size: 48),
                            const SizedBox(height: 20),
                            Text(
                              'FLEX entsperren',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 24),
                            if (lock.ready) ...[
                              TextField(
                                key: const ValueKey('unlock-pin'),
                                controller: pin,
                                obscureText: true,
                                enableSuggestions: false,
                                autocorrect: false,
                                enabled: !lock.working,
                                keyboardType: TextInputType.number,
                                maxLength: 12,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'App-PIN',
                                  counterText: '',
                                ),
                                onSubmitted: (_) => unlock(),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: lock.working ? null : unlock,
                                child: const Text('Entsperren'),
                              ),
                              if (lock.biometrics)
                                OutlinedButton.icon(
                                  onPressed: lock.working
                                      ? null
                                      : lock.unlockBiometric,
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('Biometrisch entsperren'),
                                ),
                            ] else
                              FilledButton(
                                onPressed: lock.load,
                                child: const Text('Erneut versuchen'),
                              ),
                            if (lock.error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(
                                  lock.error!,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

final _lockObservers = Expando<NavigatorObserver>();
NavigatorObserver navigationLock(AppLock lock) =>
    _lockObservers[lock] ??= _LockNavigatorObserver(lock);

class _LockPopEntry extends PopEntry<Object?> {
  _LockPopEntry(AppLock lock) : canPopNotifier = ValueNotifier(!lock.locked) {
    lock.addListener(() => canPopNotifier.value = !lock.locked);
  }
  @override
  final ValueNotifier<bool> canPopNotifier;
}

class _LockNavigatorObserver extends NavigatorObserver {
  _LockNavigatorObserver(AppLock lock) : entry = _LockPopEntry(lock);
  final _LockPopEntry entry;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalRoute<dynamic>) route.registerPopEntry(entry);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalRoute<dynamic>) route.unregisterPopEntry(entry);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalRoute<dynamic>) route.unregisterPopEntry(entry);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is ModalRoute<dynamic>) oldRoute.unregisterPopEntry(entry);
    if (newRoute is ModalRoute<dynamic>) newRoute.registerPopEntry(entry);
  }
}
