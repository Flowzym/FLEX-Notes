import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/services/quick_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('launcher targets are validated and consumed once', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? pending = 'scan';
    messenger.setMockMethodCallHandler(QuickAccess.channel, (call) async {
      if (call.method == 'take') {
        final value = pending;
        pending = null;
        return value;
      }
      return false;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(QuickAccess.channel, null),
    );
    final access = QuickAccess();
    await access.initialize();
    expect(access.consume(), 'scan');
    expect(access.consume(), isNull);
    pending = 'delete:pupil';
    await access.refresh();
    expect(access.pending, isNull);
    pending = 'homework';
    await access.refresh();
    expect(access.consume(), 'homework');
    expect(await access.pinWidget(), false);
    expect(QuickAccess.channel.name, 'at.flowzym.flex_notizbuch/quick_access');
  });
}
