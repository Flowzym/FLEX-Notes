import 'package:flex_device/flex_device.dart';

Future<void> backupMutex(Future<void> Function() action) async {
  const device = FlexDevice();
  final token = await device.acquireBackupLock();
  try {
    await action();
  } finally {
    await device.releaseBackupLock(token);
  }
}
