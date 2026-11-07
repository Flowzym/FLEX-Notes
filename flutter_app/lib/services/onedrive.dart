import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/models.dart';
import 'secret_store.dart';

class OneDriveAuthorization {
  const OneDriveAuthorization(
    this.code,
    this.userCode,
    this.url,
    this.interval,
    this.expires,
  );
  final String code, userCode, url;
  final int interval;
  final DateTime expires;
}

/// Public-client device flow: no client secret is embedded in the application.
/// Graph credentials stay in device secure storage, outside notebook backups.
class OneDriveClient extends ChangeNotifier {
  OneDriveClient({
    SecretStore? store,
    http.Client? client,
    String? clientId,
    DateTime Function()? now,
  }) : store = store ?? DeviceSecretStore(),
       client = client ?? http.Client(),
       clientId =
           clientId ?? const String.fromEnvironment('FLEX_ONEDRIVE_CLIENT_ID'),
       now = now ?? DateTime.now;
  final SecretStore store;
  final http.Client client;
  final String clientId;
  final DateTime Function() now;
  static const _key = 'flex.onedrive.tokens.v1';
  static int _sessionEpoch = 0;
  static Future<void> _writes = Future.value();
  int _epoch = _sessionEpoch, _flow = 0;
  bool _disposed = false;
  String? _activeCode;
  Json? _tokens;
  Future<String>? _refreshing;
  bool get configured => RegExp(
    r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
  ).hasMatch(clientId);
  bool get connected => _tokens != null && _epoch == _sessionEpoch;
  void cancelAuthorization() {
    _flow++;
    _activeCode = null;
  }

  Future<void> load() async {
    final epoch = _sessionEpoch;
    await _writes.catchError((Object _) {});
    final raw = await store.read(_key);
    if (epoch != _sessionEpoch || _disposed) return;
    _tokens = raw == null ? null : Json.from(jsonDecode(raw) as Map);
    if (_tokens?['clientId'] != clientId) _tokens = null;
    _epoch = _sessionEpoch;
    if (!_disposed) notifyListeners();
  }

  Future<void> disconnect() async {
    _sessionEpoch++;
    cancelAuthorization();
    final operation = _writes
        .catchError((Object _) {})
        .then((_) => store.delete(_key));
    _writes = operation;
    await operation;
    _tokens = null;
    if (!_disposed) notifyListeners();
  }

  Future<Json> _post(String endpoint, Map<String, String> body) async {
    final response = await client
        .post(
          Uri.https(
            'login.microsoftonline.com',
            '/common/oauth2/v2.0/$endpoint',
          ),
          body: body,
        )
        .timeout(const Duration(seconds: 30));
    if (response.bodyBytes.length > 1000000) {
      throw const DomainError('Ungültige Microsoft-Antwort.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const DomainError('Microsoft hat keine gültige Antwort geliefert.');
    }
    return Json.from(decoded);
  }

  Future<OneDriveAuthorization> begin() async {
    final flow = ++_flow;
    if (!configured) {
      throw const DomainError(
        'Die OneDrive-Anmeldung ist für diese App-Ausgabe noch nicht eingerichtet. Dateien und OneDrive-Links können bereits hinzugefügt werden.',
      );
    }
    final response = await _post('devicecode', {
      'client_id': clientId,
      'scope': 'offline_access Files.Read',
    });
    if (flow != _flow || _disposed) {
      throw const DomainError('Anmeldung abgebrochen.');
    }
    if (response['device_code'] is! String ||
        response['user_code'] is! String) {
      throw const DomainError(
        'Microsoft-Anmeldung konnte nicht gestartet werden.',
      );
    }
    final uri = Uri.tryParse(response['verification_uri'] as String? ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        !{
          'microsoft.com',
          'www.microsoft.com',
          'login.microsoftonline.com',
          'login.live.com',
        }.contains(uri.host)) {
      throw const DomainError('Ungültige Microsoft-Anmeldeseite.');
    }
    _activeCode = response['device_code'] as String;
    return OneDriveAuthorization(
      response['device_code'] as String,
      response['user_code'] as String,
      uri.toString(),
      (response['interval'] as int? ?? 5).clamp(5, 60),
      now().add(
        Duration(
          seconds: (response['expires_in'] as int? ?? 900).clamp(60, 1800),
        ),
      ),
    );
  }

  Future<bool> poll(OneDriveAuthorization auth) async {
    final flow = _flow, epoch = _sessionEpoch;
    if (auth.code != _activeCode || _disposed) {
      throw const DomainError('Anmeldung abgebrochen.');
    }
    if (!now().isBefore(auth.expires)) {
      throw const DomainError(
        'Der Anmeldecode ist abgelaufen. Bitte erneut verbinden.',
      );
    }
    final response = await _post('token', {
      'client_id': clientId,
      'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      'device_code': auth.code,
    });
    if (flow != _flow || epoch != _sessionEpoch || _disposed) {
      throw const DomainError('Anmeldung abgebrochen.');
    }
    if (response['error'] == 'authorization_pending') return false;
    if (response['error'] == 'slow_down') {
      await Future<void>.delayed(const Duration(seconds: 5));
      return false;
    }
    if (response['access_token'] is! String) {
      throw const DomainError(
        'Microsoft-Anmeldung wurde abgebrochen oder ist nicht erlaubt.',
      );
    }
    await _save(response, epoch: epoch, flow: flow);
    return true;
  }

  Future<void> _save(Json response, {required int epoch, int? flow}) async {
    final next = {
      'clientId': clientId,
      'access': response['access_token'],
      'refresh': response['refresh_token'] ?? _tokens?['refresh'],
      'expires': now()
          .add(
            Duration(
              seconds: (response['expires_in'] as int? ?? 3600).clamp(
                60,
                86400,
              ),
            ),
          )
          .toUtc()
          .toIso8601String(),
    };
    final operation = _writes.catchError((Object _) {}).then((_) async {
      if (epoch != _sessionEpoch ||
          flow != null && flow != _flow ||
          _disposed) {
        throw const DomainError('Die OneDrive-Verbindung wurde beendet.');
      }
      await store.write(_key, jsonEncode(next));
      _tokens = next;
      _epoch = epoch;
      if (!_disposed) notifyListeners();
    });
    _writes = operation;
    await operation;
  }

  Future<String> _token({bool force = false}) async {
    if (!connected) throw const DomainError('Bitte OneDrive verbinden.');
    if (!force &&
        DateTime.parse(
          _tokens!['expires'] as String,
        ).isAfter(now().add(const Duration(minutes: 2)))) {
      return _tokens!['access'] as String;
    }
    if (_refreshing != null) return _refreshing!;
    final pending = () async {
      final epoch = _sessionEpoch;
      if (_tokens?['refresh'] is! String) {
        throw const DomainError('Bitte erneut bei OneDrive anmelden.');
      }
      final response = await _post('token', {
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': _tokens!['refresh'] as String,
        'scope': 'offline_access Files.Read',
      });
      if (response['access_token'] is! String) {
        throw const DomainError(
          'Die OneDrive-Anmeldung ist abgelaufen. Bitte erneut verbinden.',
        );
      }
      await _save(response, epoch: epoch);
      return _tokens!['access'] as String;
    }();
    _refreshing = pending;
    try {
      return await pending;
    } finally {
      _refreshing = null;
    }
  }

  Future<Json> graph(String path, {bool retried = false}) async {
    final uri = path.startsWith('https://')
        ? Uri.parse(path)
        : Uri.parse('https://graph.microsoft.com/v1.0$path');
    if (uri.scheme != 'https' ||
        uri.host != 'graph.microsoft.com' ||
        !uri.path.startsWith('/v1.0/') ||
        uri.userInfo.isNotEmpty) {
      throw const DomainError('Ungültiger OneDrive-Verweis.');
    }
    final response = await client
        .get(
          uri,
          headers: {'Authorization': 'Bearer ${await _token(force: retried)}'},
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 401 && !retried) {
      return graph(path, retried: true);
    }
    if (response.statusCode == 404) {
      throw const DomainError(
        'Die OneDrive-Datei wurde verschoben, gelöscht oder ist nicht mehr freigegeben.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DomainError(
        'OneDrive ist derzeit nicht erreichbar. Bitte Verbindung und Freigabe prüfen.',
      );
    }
    if (response.bodyBytes.length > 5000000) {
      throw const DomainError('Die OneDrive-Antwort ist zu groß.');
    }
    return Json.from(jsonDecode(response.body) as Map);
  }

  String itemPath(String drive, String id) =>
      '/drives/${Uri.encodeComponent(drive)}/items/${Uri.encodeComponent(id)}';
  Future<Json> item(String drive, String id) => graph(itemPath(drive, id));
  Future<Uint8List?> thumbnail(String drive, String id) async {
    final data = await graph('${itemPath(drive, id)}/thumbnails');
    final sets = data['value'] as List? ?? [];
    if (sets.isEmpty) return null;
    final first = sets.first as Map;
    final image = (first['medium'] ?? first['small']) as Map?;
    if (image?['url'] is! String) return null;
    return download({
      '@microsoft.graph.downloadUrl': image!['url'],
    }, maxBytes: 2000000);
  }

  Future<List<Json>> children({String? drive, String? folder}) async {
    var path = drive == null
        ? '/me/drive/root/children'
        : '${itemPath(drive, folder!)}/children';
    final result = <Json>[];
    final visited = <String>{};
    while (true) {
      if (!visited.add(path) || visited.length > 50) {
        throw const DomainError(
          'Der OneDrive-Ordner ist zu groß. Bitte einen Unterordner wählen.',
        );
      }
      final page = await graph(path);
      result.addAll((page['value'] as List).map((v) => Json.from(v as Map)));
      if (result.length > 5000) {
        throw const DomainError(
          'Bitte einen kleineren OneDrive-Ordner wählen.',
        );
      }
      final next = page['@odata.nextLink'] as String?;
      if (next == null) break;
      path = next;
    }
    return result;
  }

  Future<Uint8List> download(Json item, {int maxBytes = 20000000}) async {
    if ((item['size'] as int? ?? 0) > maxBytes) {
      throw const DomainError('Die Datei überschreitet 20 MB.');
    }
    final uri = Uri.tryParse(
      item['@microsoft.graph.downloadUrl'] as String? ?? '',
    );
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const DomainError('Die Datei kann nicht heruntergeladen werden.');
    }
    // This preauthenticated URL is intentionally requested without Graph's bearer token.
    final response = await client
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 ||
        response.contentLength != null && response.contentLength! > maxBytes) {
      throw const DomainError(
        'Die Datei konnte nicht geladen werden oder ist zu groß.',
      );
    }
    final bytes = BytesBuilder();
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const DomainError('Die Datei überschreitet 20 MB.');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  @override
  void dispose() {
    _disposed = true;
    cancelAuthorization();
    client.close();
    super.dispose();
  }
}
