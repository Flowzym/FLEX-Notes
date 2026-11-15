import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/services/onedrive.dart';
import 'package:flex_notizbuch/services/onedrive_native.dart';
import 'package:flex_notizbuch/services/secret_store.dart';
import 'package:flex_notizbuch/ui/onedrive_setup.dart';

class _Secrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

const _account = OneDriveAccount('account-1', 'test@example.invalid');

class _Native implements NativeOneDriveAuth {
  OneDriveAccount? account;
  Future<OneDriveAccount?> Function()? login;
  Future<OneDriveAccount?> Function()? restore;
  Future<String> Function(bool)? acquire;
  final refreshes = <bool>[];
  int signOuts = 0;
  @override
  Future<OneDriveAccount?> currentAccount() async =>
      restore != null ? await restore!() : account;
  @override
  Future<OneDriveAccount?> signIn() async =>
      login != null ? await login!() : account;
  @override
  Future<void> signOut() async {
    signOuts++;
    account = null;
  }

  @override
  Future<String> token(String accountId, {bool forceRefresh = false}) async {
    expect(accountId, _account.id);
    refreshes.add(forceRefresh);
    return acquire != null ? await acquire!(forceRefresh) : 'access';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'registration, redirect and least-privilege native configuration agree',
    () {
      final config =
          jsonDecode(
                File(
                  'packages/flex_device/android/src/main/res/raw/flex_msal_config.json',
                ).readAsStringSync(),
              )
              as Map;
      expect(config['client_id'], oneDriveRegisteredClientId);
      final redirect = Uri.parse(config['redirect_uri'] as String);
      expect(redirect.scheme, 'msauth');
      expect(redirect.host, 'at.flowzym.flex_notizbuch');
      expect(
        Uri.decodeComponent(redirect.path),
        '/O/s4RU8YApv43yNF9HMVr8OKo80=',
      );
      expect(config['account_mode'], 'SINGLE');
      expect(config['broker_redirect_uri_registered'], false);
      expect(config['logging']['pii_enabled'], false);
      expect(config['logging']['logcat_enabled'], false);
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        manifest,
        contains('android:path="/O/s4RU8YApv43yNF9HMVr8OKo80="'),
      );
      // The .dev application must not intercept the production app's callback.
      expect(manifest, contains('android:host="\${applicationId}"'));
    },
  );

  test(
    'native migration removes only legacy credentials and restores SDK account',
    () async {
      final store = _Secrets()
        ..values.addAll({
          'flex.onedrive.tokens.v1': '{"refresh":"legacy"}',
          OneDriveClient.configurationKey: 'old-public-id',
          'unrelated-secret': 'keep',
        });
      final native = _Native()..account = _account;
      final drive = OneDriveClient(store: store, nativeAuth: native);
      addTearDown(drive.dispose);
      await drive.load();
      expect(drive.clientId, oneDriveRegisteredClientId);
      expect(drive.connected, true);
      expect(drive.accountName, _account.username);
      expect(
        store.values.keys,
        unorderedEquals([OneDriveClient.configurationKey, 'unrelated-secret']),
      );
      expect(store.values['unrelated-secret'], 'keep');
      await drive.disconnect();
      expect(native.signOuts, 1);
      expect(drive.connected, false);
      expect(drive.hasAccount, false);
    },
  );

  test('cancelled native login is not reported as connected', () async {
    final drive = OneDriveClient(store: _Secrets(), nativeAuth: _Native());
    addTearDown(drive.dispose);
    expect(await drive.signInNative(), false);
    expect(drive.connected, false);
    await expectLater(drive.begin(), throwsA(isA<DomainError>()));
  });

  test(
    'native login stores no access or refresh tokens in Dart secret store',
    () async {
      final store = _Secrets();
      final drive = OneDriveClient(
        store: store,
        nativeAuth: _Native()..account = _account,
      );
      addTearDown(drive.dispose);
      expect(await drive.signInNative(), true);
      expect(drive.connected, true);
      expect(store.values, isEmpty);
    },
  );

  test(
    'a late startup account lookup cannot overwrite a completed login',
    () async {
      final reply = Completer<OneDriveAccount?>();
      final native = _Native()
        ..account = _account
        ..restore = () => reply.future;
      final drive = OneDriveClient(store: _Secrets(), nativeAuth: native);
      addTearDown(drive.dispose);
      final pending = drive.load();
      await Future<void>.delayed(Duration.zero);
      await drive.signInNative();
      reply.complete(null);
      await pending;
      expect(drive.connected, true);
    },
  );

  test('disconnect invalidates a pending login response', () async {
    final reply = Completer<OneDriveAccount?>();
    final drive = OneDriveClient(
      store: _Secrets(),
      nativeAuth: _Native()..login = () => reply.future,
    );
    addTearDown(drive.dispose);
    final pending = drive.signInNative();
    final assertion = expectLater(pending, throwsA(isA<DomainError>()));
    await drive.disconnect();
    reply.complete(_account);
    await assertion;
    expect(drive.connected, false);
  });

  test(
    '401 forces an SDK refresh once and Graph never uses device-code token endpoint',
    () async {
      final native = _Native()..account = _account;
      var calls = 0;
      final drive = OneDriveClient(
        store: _Secrets(),
        nativeAuth: native,
        client: MockClient((r) async {
          expect(r.url.host, 'graph.microsoft.com');
          expect(r.headers['Authorization'], 'Bearer access');
          calls++;
          return http.Response(
            calls == 1 ? '{}' : '{"id":"drive"}',
            calls == 1 ? 401 : 200,
          );
        }),
      );
      addTearDown(drive.dispose);
      await drive.load();
      expect((await drive.graph('/me/drive'))['id'], 'drive');
      expect(native.refreshes, [false, true]);
    },
  );

  test(
    'revoked consent prompts re-login without silently opening Microsoft',
    () async {
      final native = _Native()
        ..account = _account
        ..acquire = (_) async => throw const OneDriveSignInRequired();
      final drive = OneDriveClient(
        store: _Secrets(),
        nativeAuth: native,
        client: MockClient(
          (r) async => throw StateError('No Graph call expected'),
        ),
      );
      addTearDown(drive.dispose);
      await drive.load();
      await expectLater(
        drive.graph('/me/drive'),
        throwsA(isA<OneDriveSignInRequired>()),
      );
      expect(drive.connected, false);
      expect(drive.hasAccount, true); // Trennen remains available.
    },
  );

  test(
    'logout during native refresh prevents a late token reaching Graph',
    () async {
      final reply = Completer<String>(), started = Completer<void>();
      final native = _Native()
        ..account = _account
        ..acquire = (_) {
          started.complete();
          return reply.future;
        };
      final drive = OneDriveClient(
        store: _Secrets(),
        nativeAuth: native,
        client: MockClient(
          (r) async => throw StateError('Stale token must not be sent'),
        ),
      );
      addTearDown(drive.dispose);
      await drive.load();
      final pending = drive.graph('/me/drive');
      final assertion = expectLater(pending, throwsA(isA<DomainError>()));
      await started.future;
      await drive.disconnect();
      reply.complete('stale-token');
      await assertion;
    },
  );

  test('logout also discards an already running Graph response', () async {
    final reply = Completer<http.Response>(), started = Completer<void>();
    final drive = OneDriveClient(
      store: _Secrets(),
      nativeAuth: _Native()..account = _account,
      client: MockClient((r) {
        started.complete();
        return reply.future;
      }),
    );
    addTearDown(drive.dispose);
    await drive.load();
    final pending = drive.graph('/me/drive');
    final assertion = expectLater(pending, throwsA(isA<DomainError>()));
    await started.future;
    await drive.disconnect();
    reply.complete(http.Response('{"id":"old-account-drive"}', 200));
    await assertion;
  });

  test(
    'channel passes account binding and force-refresh, sanitizes raw MSAL errors',
    () async {
      const channel = MethodChannel('at.flowzym.flex_notizbuch/device');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'msalToken') return 'access';
        if (call.method == 'msalAccount') {
          return {'id': 'account', 'username': 'test'};
        }
        throw PlatformException(
          code: 'msal_unavailable',
          message: 'SECRET server response',
          details: 'TOKEN',
        );
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const bridge = MsalOneDriveAuth();
      expect((await bridge.currentAccount())?.id, 'account');
      expect(await bridge.token('account', forceRefresh: true), 'access');
      expect(calls.last.arguments, {
        'accountId': 'account',
        'forceRefresh': true,
      });
      await expectLater(
        bridge.signIn(),
        throwsA(
          isA<DomainError>().having(
            (e) => e.toString(),
            'sanitized message',
            isNot(contains('SECRET')),
          ),
        ),
      );
    },
  );

  testWidgets(
    'Android connects without a code dialog and shows a retry after failure',
    (tester) async {
      final reply = Completer<OneDriveAccount?>();
      final native = _Native()..login = () => reply.future;
      final drive = OneDriveClient(store: _Secrets(), nativeAuth: native);
      addTearDown(drive.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => connectNativeOneDrive(context, drive),
                child: const Text('Verbinden'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Verbinden'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Microsoft-Anmeldung wird geöffnet …'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      reply.completeError(const DomainError('Keine Verbindung'));
      await tester.pumpAndSettle();
      expect(find.text('Keine Verbindung'), findsOneWidget);
      native.login = () async => _account;
      await tester.tap(find.text('Erneut anmelden'));
      await tester.pumpAndSettle();
      expect(drive.connected, true);
      expect(find.text('OneDrive verbinden'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
