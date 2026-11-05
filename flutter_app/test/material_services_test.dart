import 'dart:async';
import 'package:archive/archive.dart' show Archive, ArchiveFile, ZipEncoder;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/services/material_files.dart';
import 'package:flex_notizbuch/services/onedrive.dart';
import 'package:flex_notizbuch/services/secret_store.dart';

class MaterialSecrets implements SecretStore {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

const clientId = '12345678-1234-4321-1234-123456789012';
const tokenKey = 'flex.onedrive.tokens.v1';
http.Response jsonResponse(Object value, [int code = 200]) => http.Response(
  jsonEncode(value),
  code,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('DOCX requires a Word package and rejects macro-bearing archives', () {
    Uint8List zip(List<String> names) {
      final archive = Archive();
      for (final name in names) {
        archive.add(ArchiveFile(name, 4, utf8.encode('test')));
      }
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }

    expect(
      () => validateMaterialBytes(zip(['random.txt']), 'docx'),
      throwsA(isA<DomainError>()),
    );
    validateMaterialBytes(
      zip(['[Content_Types].xml', 'word/document.xml']),
      'docx',
    );
    expect(
      () => validateMaterialBytes(
        zip([
          '[Content_Types].xml',
          'word/document.xml',
          'word/vbaProject.bin',
        ]),
        'docx',
      ),
      throwsA(isA<DomainError>()),
    );
  });
  test(
    'material bundle encrypts documents and bytes and detects wrong password or tampering',
    () async {
      final bytes = Uint8List.fromList(ascii.encode('%PDF-1.4\nexample'));
      final doc = ClassroomDocument.create(ClassroomKind.material, 'Plan.pdf', {
        'extension': 'pdf',
        'localKey': 'safe-key',
      });
      final encoded = await MaterialBundle.encode(
        [doc],
        {'safe-key': bytes},
        'ein-sehr-langes-passwort',
      );
      expect(
        utf8.decode(encoded, allowMalformed: true),
        isNot(contains('Plan.pdf')),
      );
      final decoded = await MaterialBundle.decode(
        encoded,
        'ein-sehr-langes-passwort',
      );
      expect(decoded.documents.single.id, doc.id);
      expect(decoded.files['safe-key'], bytes);
      await expectLater(
        MaterialBundle.decode(encoded, 'anderes-passwort'),
        throwsA(isA<DomainError>()),
      );
      final damaged = Uint8List.fromList(encoded);
      damaged[damaged.length - 20] ^= 1;
      await expectLater(
        MaterialBundle.decode(damaged, 'ein-sehr-langes-passwort'),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test(
    'material files reject executable masquerading as PDF and empty documents',
    () {
      expect(
        () => validateMaterialBytes(
          Uint8List.fromList([0x4d, 0x5a, 1, 2, 3]),
          'pdf',
        ),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => validateMaterialBytes(Uint8List(0), 'docx'),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test(
    'material bundle rejects a missing file and invalid local identifiers',
    () async {
      final d = ClassroomDocument.create(ClassroomKind.material, 'Material', {
        'localKey': 'missing',
        'extension': 'pdf',
      });
      final bundle = await MaterialBundle.encode(
        [d],
        {},
        'ein-sehr-langes-passwort',
      );
      await expectLater(
        MaterialBundle.decode(bundle, 'ein-sehr-langes-passwort'),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => ClassroomDocument.create(ClassroomKind.material, 'Material', {
          'localKey': '../escape',
          'extension': 'pdf',
        }),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test(
    'unregistered OneDrive build cannot pretend to connect or send requests',
    () async {
      var called = false;
      final drive = OneDriveClient(
        store: MaterialSecrets(),
        clientId: '',
        client: MockClient((r) async {
          called = true;
          return jsonResponse({});
        }),
      );
      addTearDown(drive.dispose);
      expect(drive.configured, isFalse);
      await expectLater(drive.begin(), throwsA(isA<DomainError>()));
      expect(called, isFalse);
    },
  );
  test(
    'device flow persists token only after authorization; no client secret is sent',
    () async {
      final store = MaterialSecrets();
      var polls = 0;
      final drive = OneDriveClient(
        store: store,
        clientId: clientId,
        client: MockClient((r) async {
          expect(r.bodyFields.containsKey('client_secret'), isFalse);
          if (r.url.path.endsWith('devicecode')) {
            return jsonResponse({
              'device_code': 'device',
              'user_code': 'CODE',
              'verification_uri': 'https://microsoft.com/devicelogin',
              'expires_in': 900,
              'interval': 5,
            });
          }
          polls++;
          return polls == 1
              ? jsonResponse({'error': 'authorization_pending'}, 400)
              : jsonResponse({
                  'access_token': 'access',
                  'refresh_token': 'refresh',
                  'expires_in': 3600,
                });
        }),
      );
      addTearDown(drive.dispose);
      final auth = await drive.begin();
      expect(await drive.poll(auth), isFalse);
      expect(store.values, isEmpty);
      expect(await drive.poll(auth), isTrue);
      expect(drive.connected, isTrue);
      expect(store.values.containsKey(tokenKey), isTrue);
      await drive.disconnect();
      expect(drive.connected, isFalse);
      expect(store.values, isEmpty);
    },
  );
  test('cancelled login does not save a late successful response', () async {
    final store = MaterialSecrets(), response = Completer<http.Response>();
    final drive = OneDriveClient(
      store: store,
      clientId: clientId,
      client: MockClient(
        (r) async => r.url.path.endsWith('devicecode')
            ? jsonResponse({
                'device_code': 'device',
                'user_code': 'CODE',
                'verification_uri': 'https://microsoft.com/devicelogin',
                'expires_in': 900,
              })
            : response.future,
      ),
    );
    addTearDown(drive.dispose);
    final auth = await drive.begin();
    final pending = drive.poll(auth);
    drive.cancelAuthorization();
    final assertion = expectLater(pending, throwsA(isA<DomainError>()));
    response.complete(
      jsonResponse({'access_token': 'access', 'refresh_token': 'refresh'}),
    );
    await assertion;
    expect(store.values, isEmpty);
    expect(drive.connected, isFalse);
  });
  test(
    'refresh is serialized and a disconnect invalidates the pending response',
    () async {
      final store = MaterialSecrets();
      store.values[tokenKey] = jsonEncode({
        'clientId': clientId,
        'access': 'old',
        'refresh': 'old-refresh',
        'expires': '2020-01-01T00:00:00Z',
      });
      final started = Completer<void>(), reply = Completer<http.Response>();
      var refreshes = 0;
      final drive = OneDriveClient(
        store: store,
        clientId: clientId,
        client: MockClient((r) async {
          refreshes++;
          if (!started.isCompleted) started.complete();
          return reply.future;
        }),
      );
      addTearDown(drive.dispose);
      await drive.load();
      final pending = drive.graph('/me/drive');
      await started.future;
      await drive.disconnect();
      final assertion = expectLater(pending, throwsA(isA<DomainError>()));
      reply.complete(
        jsonResponse({'access_token': 'late', 'refresh_token': 'late-refresh'}),
      );
      await assertion;
      expect(refreshes, 1);
      expect(store.values, isEmpty);
      expect(drive.connected, isFalse);
    },
  );
  test(
    'Graph follows only Microsoft pagination and keeps bearer token off file download requests',
    () async {
      final store = MaterialSecrets();
      store.values[tokenKey] = jsonEncode({
        'clientId': clientId,
        'access': 'access',
        'refresh': 'refresh',
        'expires': '2099-01-01T00:00:00Z',
      });
      final requests = <http.Request>[];
      final drive = OneDriveClient(
        store: store,
        clientId: clientId,
        client: MockClient((r) async {
          requests.add(r);
          if (r.url.host == 'files.example.org') {
            expect(r.headers.containsKey('Authorization'), isFalse);
            expect(r.headers.containsKey('authorization'), isFalse);
            return http.Response('%PDF-1.4', 200);
          }
          expect(
            r.headers['Authorization'] ?? r.headers['authorization'],
            'Bearer access',
          );
          return jsonResponse({
            'value': <Json>[],
            '@odata.nextLink': 'https://evil.example/steal',
          });
        }),
      );
      addTearDown(drive.dispose);
      await drive.load();
      await expectLater(drive.children(), throwsA(isA<DomainError>()));
      expect(requests.length, 1);
      expect(
        await drive.download({
          'size': 8,
          '@microsoft.graph.downloadUrl': 'https://files.example.org/file',
        }),
        ascii.encode('%PDF-1.4'),
      );
      expect(requests.length, 2);
    },
  );
  test('failed secure storage does not report a connected account', () async {
    final store = MaterialSecrets()..fail = true;
    final drive = OneDriveClient(
      store: store,
      clientId: clientId,
      client: MockClient(
        (r) async => r.url.path.endsWith('devicecode')
            ? jsonResponse({
                'device_code': 'device',
                'user_code': 'CODE',
                'verification_uri': 'https://microsoft.com/devicelogin',
                'expires_in': 900,
              })
            : jsonResponse({
                'access_token': 'access',
                'refresh_token': 'refresh',
              }),
      ),
    );
    addTearDown(drive.dispose);
    final auth = await drive.begin();
    await expectLater(drive.poll(auth), throwsStateError);
    expect(drive.connected, isFalse);
    expect(store.values, isEmpty);
  });
}
