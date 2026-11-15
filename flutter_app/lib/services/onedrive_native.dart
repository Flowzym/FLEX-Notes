import 'package:flutter/services.dart';
import '../domain/models.dart';

// Public application registration, never a client secret.
const oneDriveRegisteredClientId = '299f0cd6-a732-425b-8318-e7d7364dd2e3';

class OneDriveAccount {
  const OneDriveAccount(this.id, this.username);
  final String id, username;
}

class OneDriveSignInRequired extends DomainError {
  const OneDriveSignInRequired()
    : super('Bitte erneut bei Microsoft anmelden, um OneDrive zu öffnen.');
}

abstract interface class NativeOneDriveAuth {
  Future<OneDriveAccount?> currentAccount();
  Future<OneDriveAccount?> signIn();
  Future<String> token(String accountId, {bool forceRefresh = false});
  Future<void> signOut();
}

class MsalOneDriveAuth implements NativeOneDriveAuth {
  const MsalOneDriveAuth();
  static const _channel = MethodChannel('at.flowzym.flex_notizbuch/device');

  Future<T?> _invoke<T>(String method, [Map<String, Object>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      // Do not forward Microsoft's raw error descriptions or tokens to the UI,
      // diagnostic reports or notebook backups.
      if (e.code == 'msal_interaction_required' ||
          e.code == 'msal_account_changed') {
        throw const OneDriveSignInRequired();
      }
      throw DomainError(switch (e.code) {
        'msal_configuration' =>
          'Die Microsoft-Registrierung passt nicht zu dieser Installation. Bitte die signierte FLEX-Version verwenden und die Android-Registrierung prüfen.',
        'msal_network' =>
          'Microsoft ist nicht erreichbar. Bitte die Internetverbindung prüfen und erneut versuchen.',
        'msal_denied' =>
          'Der OneDrive-Zugriff wurde nicht erlaubt. Bitte beim Anmelden den Lesezugriff auf Dateien bestätigen.',
        'msal_cancelled' || 'msal_no_activity' =>
          'Anmeldung abgebrochen. Bitte FLEX öffnen und erneut verbinden.',
        _ =>
          'Microsoft-Anmeldung fehlgeschlagen. Bitte erneut versuchen und bei Bedarf die Appregistrierung prüfen.',
      });
    } on MissingPluginException {
      throw const DomainError(
        'Diese Installation unterstützt die Microsoft-Anmeldung noch nicht. Bitte FLEX aktualisieren.',
      );
    }
  }

  Future<OneDriveAccount?> _account(String method) async {
    final value = await _invoke<Map>(method);
    if (value == null) return null;
    final id = value['id'];
    if (id is! String || id.isEmpty) {
      throw const DomainError('Microsoft hat kein gültiges Konto geliefert.');
    }
    return OneDriveAccount(id, value['username'] as String? ?? '');
  }

  @override
  Future<OneDriveAccount?> currentAccount() => _account('msalAccount');
  @override
  Future<OneDriveAccount?> signIn() => _account('msalSignIn');
  @override
  Future<String> token(String accountId, {bool forceRefresh = false}) async {
    final value = await _invoke<String>('msalToken', {
      'accountId': accountId,
      'forceRefresh': forceRefresh,
    });
    if (value == null || value.isEmpty) throw const OneDriveSignInRequired();
    return value;
  }

  @override
  Future<void> signOut() => _invoke<void>('msalSignOut');
}
