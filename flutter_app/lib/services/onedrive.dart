import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/models.dart';
import 'secret_store.dart';
import 'onedrive_native.dart';

class OneDriveResponseError extends DomainError {
  const OneDriveResponseError(this.status, super.message);
  final int status;
}

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

/// Android uses MSAL's private cache; web uses public-client device flow.
/// Neither authentication path includes credentials in notebook backups.
class OneDriveClient extends ChangeNotifier {
  OneDriveClient({
    this.appFolderAccess = false,
    SecretStore? store,
    http.Client? client,
    String? clientId,
    NativeOneDriveAuth? nativeAuth,
    bool? useNativeAuthentication,
    DateTime Function()? now,
  }) : store = store ?? DeviceSecretStore(),
       client = client ?? http.Client(),
       _clientId =
           clientId ??
           const String.fromEnvironment(
             'FLEX_ONEDRIVE_CLIENT_ID',
             defaultValue: oneDriveRegisteredClientId,
           ),
       _native =
           (useNativeAuthentication ??
               (nativeAuth != null ||
                   !kIsWeb && defaultTargetPlatform == TargetPlatform.android))
           ? nativeAuth ?? MsalOneDriveAuth(appFolderAccess: appFolderAccess)
           : null,
       now = now ?? DateTime.now;
  final bool appFolderAccess;
  String get scopes => appFolderAccess || _tokens?['appFolder'] == true
      ? 'offline_access Files.Read Files.ReadWrite.AppFolder'
      : 'offline_access Files.Read';
  final SecretStore store;
  final http.Client client;
  final NativeOneDriveAuth? _native;
  OneDriveAccount? _account;
  bool _nativeReady = false;
  bool get nativeAuthentication => _native != null;
  String? get accountName => _account?.username;
  bool get hasAccount => _account != null || connected;
  String _clientId;
  String get clientId =>
      _native != null ? oneDriveRegisteredClientId : _clientId;
  static const configurationKey = 'flex.onedrive.client.v1';
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
  bool get connected =>
      (_native != null ? _nativeReady && _account != null : _tokens != null) &&
      _epoch == _sessionEpoch;
  void cancelAuthorization() {
    _flow++;
    _activeCode = null;
  }

  Future<void> load() async {
    final epoch = _sessionEpoch, flow = _flow;
    await _writes.catchError((Object _) {});
    if (_native != null) {
      // A device-code refresh token cannot be imported into MSAL. Only the old
      // credential is removed; linked materials and local data stay untouched.
      _clientId = oneDriveRegisteredClientId;
      await store.delete(_key);
      final account = await _native.currentAccount();
      if (epoch != _sessionEpoch || flow != _flow || _disposed) return;
      _account = account;
      _nativeReady = account != null;
      _epoch = epoch;
      notifyListeners();
      return;
    }
    final configuredId = await store.read(configurationKey);
    if (configuredId != null) _clientId = configuredId;
    final raw = await store.read(_key);
    if (epoch != _sessionEpoch || flow != _flow || _disposed) return;
    _tokens = raw == null ? null : Json.from(jsonDecode(raw) as Map);
    if (_tokens?['clientId'] != clientId) _tokens = null;
    _epoch = _sessionEpoch;
    if (!_disposed) notifyListeners();
  }

  Future<void> configure(String value) async {
    final id = value.trim();
    if (_native != null && id != oneDriveRegisteredClientId) {
      throw const DomainError(
        'Die Android-Anmeldung verwendet die in FLEX hinterlegte Microsoft-Registrierung.',
      );
    }
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const DomainError(
        'Bitte die Anwendungs-/Client-ID aus der Appregistrierung einfügen.',
      );
    }
    if (id == clientId) return;
    await disconnect();
    await store.write(configurationKey, id);
    _clientId = id;
    await load();
  }

  Future<void> disconnect() async {
    _sessionEpoch++;
    cancelAuthorization();
    _nativeReady = false;
    _tokens = null;
    if (!_disposed) notifyListeners();
    // The native queue finishes pending authentication/cache writes first.
    if (_native != null) {
      await _native.signOut();
      _account = null;
    }
    final operation = _writes
        .catchError((Object _) {})
        .then((_) => store.delete(_key));
    _writes = operation;
    await operation;
    _tokens = null;
    if (!_disposed) notifyListeners();
  }

  Future<bool> signInNative() async {
    final auth = _native;
    if (auth == null) {
      throw const DomainError('Native Anmeldung nicht verfügbar.');
    }
    final epoch = _sessionEpoch, flow = ++_flow;
    final account = await auth.signIn();
    if (epoch != _sessionEpoch || flow != _flow || _disposed) {
      throw const DomainError('Anmeldung abgebrochen.');
    }
    if (account == null) return false;
    _account = account;
    _nativeReady = true;
    _epoch = epoch;
    notifyListeners();
    return true;
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
    if (_native != null) {
      throw const DomainError(
        'Bitte die native Microsoft-Anmeldung verwenden.',
      );
    }
    final flow = ++_flow;
    if (!configured) {
      throw const DomainError(
        'Bitte die Microsoft-Client-ID in der OneDrive-Einrichtung hinterlegen.',
      );
    }
    final response = await _post('devicecode', {
      'client_id': clientId,
      'scope': scopes,
    });
    if (flow != _flow || _disposed) {
      throw const DomainError('Anmeldung abgebrochen.');
    }
    if (response['device_code'] is! String ||
        response['user_code'] is! String) {
      throw DomainError(oneDriveAuthorizationError(response));
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
      throw DomainError(oneDriveAuthorizationError(response));
    }
    await _save(response, epoch: epoch, flow: flow);
    return true;
  }

  Future<void> _save(Json response, {required int epoch, int? flow}) async {
    final next = {
      'clientId': clientId,
      'access': response['access_token'],
      'appFolder':
          (response['scope'] as String?)?.toLowerCase().contains(
            'files.readwrite.appfolder',
          ) ??
          (appFolderAccess || _tokens?['appFolder'] == true),
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
    if (_native != null) {
      final epoch = _sessionEpoch;
      final accountId = _account!.id;
      try {
        final token = await _native.token(accountId, forceRefresh: force);
        if (epoch != _sessionEpoch || _disposed || _account?.id != accountId) {
          throw const DomainError('Die OneDrive-Verbindung wurde beendet.');
        }
        return token;
      } on OneDriveSignInRequired {
        if (epoch == _sessionEpoch && !_disposed && _account?.id == accountId) {
          _nativeReady = false;
          notifyListeners();
        }
        rethrow;
      }
    }
    if (appFolderAccess && _tokens?['appFolder'] != true) {
      throw const OneDriveSignInRequired();
    }
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
        if (epoch == _sessionEpoch && !_disposed) await disconnect();
        throw const OneDriveSignInRequired();
      }
      final response = await _post('token', {
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': _tokens!['refresh'] as String,
        'scope': scopes,
      });
      if (response['access_token'] is! String) {
        if ({
          'invalid_grant',
          'interaction_required',
          'login_required',
          'consent_required',
        }.contains(response['error'])) {
          if (epoch == _sessionEpoch && !_disposed) await disconnect();
          throw const OneDriveSignInRequired();
        }
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

  Future<Json> graph(String path, {bool retried = false}) =>
      _graphRequest('GET', path, retried: retried);

  Future<Json> createFolder(String drive, String parent, String name) =>
      _graphRequest(
        'POST',
        '${itemPath(drive, parent)}/children',
        body: utf8.encode(
          jsonEncode({
            'name': name,
            'folder': {},
            '@microsoft.graph.conflictBehavior': 'fail',
          }),
        ),
        contentType: 'application/json',
      );

  Future<void> verifyAppFolder(
    String driveId,
    String folderId,
    String expectedRoot,
  ) async {
    final app = await graph('/me/drive/special/approot');
    final root = app['id'];
    if (root == null ||
        root != expectedRoot ||
        (app['parentReference'] as Map?)?['driveId'] != driveId) {
      throw const DomainError('Konto oder FLEX-App-Ordner hat sich geändert.');
    }
    var ancestor = folderId;
    final visited = <String>{};
    while (ancestor != root) {
      if (ancestor.isEmpty || !visited.add(ancestor) || visited.length > 128) {
        throw const DomainError(
          'Der Zielordner liegt außerhalb des FLEX-App-Ordners.',
        );
      }
      final node = await item(driveId, ancestor);
      ancestor = (node['parentReference'] as Map?)?['id'] as String? ?? '';
    }
  }

  String childPath(String drive, String parent, String name) =>
      '${itemPath(drive, parent)}:/${Uri.encodeComponent(name)}';

  Future<Json> uploadNew(
    String drive,
    String parent,
    String name,
    Uint8List bytes,
  ) => _graphRequest(
    'PUT',
    '${childPath(drive, parent, name)}:/content?%40microsoft.graph.conflictBehavior=fail',
    body: bytes,
    contentType: 'application/octet-stream',
  );

  Future<Json> replaceVersion(
    String driveId,
    String itemId,
    String etag,
    Uint8List bytes,
  ) {
    if (etag.isEmpty) {
      throw const DomainError('Die Version des Planstands fehlt.');
    }
    return _graphRequest(
      'PUT',
      '${itemPath(driveId, itemId)}/content',
      body: bytes,
      contentType: 'application/json',
      ifMatch: etag,
    );
  }

  Future<Json> _graphRequest(
    String method,
    String path, {
    List<int>? body,
    String? contentType,
    String? ifMatch,
    bool retried = false,
  }) async {
    if (method != 'GET' && !appFolderAccess) {
      throw const DomainError('Bitte die Ablage im FLEX-Ordner aktivieren.');
    }
    final epoch = _sessionEpoch, accountId = _account?.id;
    final uri = path.startsWith('https://')
        ? Uri.parse(path)
        : Uri.parse('https://graph.microsoft.com/v1.0$path');
    if (uri.scheme != 'https' ||
        uri.host != 'graph.microsoft.com' ||
        !uri.path.startsWith('/v1.0/') ||
        uri.userInfo.isNotEmpty) {
      throw const DomainError('Ungültiger OneDrive-Verweis.');
    }
    final request = http.Request(method, uri)..followRedirects = false;
    request.headers['Authorization'] = 'Bearer ${await _token(force: retried)}';
    if (ifMatch != null) request.headers['If-Match'] = ifMatch;
    if (body != null) request.bodyBytes = body;
    if (contentType != null) request.headers['Content-Type'] = contentType;
    final response = await client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 40));
    if (epoch != _sessionEpoch || _disposed || _account?.id != accountId) {
      throw const DomainError('Die OneDrive-Verbindung wurde beendet.');
    }
    if (response.statusCode == 401 && !retried) {
      return _graphRequest(
        method,
        path,
        body: body,
        contentType: contentType,
        ifMatch: ifMatch,
        retried: true,
      );
    }
    if (response.statusCode == 404) {
      throw const OneDriveResponseError(
        404,
        'Die OneDrive-Datei wurde verschoben, gelöscht oder ist nicht mehr freigegeben.',
      );
    }
    if (response.statusCode == 401) {
      if (_native == null) await disconnect();
      _nativeReady = false;
      if (!_disposed) notifyListeners();
      throw const OneDriveSignInRequired();
    }
    if (response.statusCode == 409 || response.statusCode == 412) {
      throw OneDriveResponseError(
        response.statusCode,
        'Im Zielordner existiert bereits eine gleichnamige Datei.',
      );
    }
    if (response.statusCode == 403 && appFolderAccess) {
      throw const OneDriveResponseError(
        403,
        'Kein Zugriff auf den FLEX-App-Ordner. Microsoft-Anmeldung und die Berechtigung Files.ReadWrite.AppFolder prüfen.',
      );
    }
    if (response.statusCode == 403) {
      throw const DomainError(
        'Microsoft erlaubt diesen Dateizugriff nicht. Bitte das angemeldete Konto, die Freigabe der Datei und die delegierte Berechtigung Files.Read in Entra prüfen.',
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

String oneDriveAuthorizationError(Json response) {
  final codes = response['error_codes'] is List
      ? response['error_codes'] as List
      : const [];
  if (codes.contains(7000218) || response['error'] == 'unauthorized_client') {
    return 'Die Microsoft-Appregistrierung erlaubt diese Anmeldung noch nicht. Bitte dort öffentliche Clientflows aktivieren. Ein Client-Geheimnis ist nicht erforderlich.';
  }
  if (codes.contains(50194) || codes.contains(50020)) {
    return 'Die Appregistrierung unterstützt dieses Konto noch nicht. Bitte persönliche Microsoft-Konten und Konten anderer Organisationen zulassen.';
  }
  if (codes.contains(700016) || response['error'] == 'invalid_client') {
    return 'Microsoft findet die FLEX-Appregistrierung nicht. Bitte die Anwendungs-/Client-ID in der Einrichtung prüfen.';
  }
  if (response['error'] == 'expired_token') {
    return 'Der Anmeldecode ist abgelaufen. Bitte erneut verbinden.';
  }
  return 'Microsoft-Anmeldung wurde abgebrochen oder ist nicht erlaubt. Bitte Kontoberechtigungen und Einrichtung prüfen.';
}
