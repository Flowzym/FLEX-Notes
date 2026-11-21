import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class QuickAccess extends ChangeNotifier {
  static const channel = MethodChannel(
    'at.flowzym.flex_notizbuch/quick_access',
  );
  static const targets = {'notes', 'calendar', 'scan', 'homework'};
  String? pending;
  bool _reading = false, _refreshAgain = false;
  Future<void> initialize() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await refresh();
    });
    await refresh();
  }

  Future<void> refresh() async {
    if (_reading) {
      _refreshAgain = true;
      return;
    }
    _reading = true;
    try {
      do {
        _refreshAgain = false;
        final target = await channel.invokeMethod<String>('take');
        if (targets.contains(target)) {
          pending = target;
          notifyListeners();
        }
      } while (_refreshAgain);
    } finally {
      _reading = false;
    }
  }

  String? consume() {
    final value = pending;
    pending = null;
    return value;
  }

  Future<bool> pinWidget() async =>
      await channel.invokeMethod<bool>('pinWidget') ?? false;
}
